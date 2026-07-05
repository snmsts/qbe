;;;; ssa.lisp --- SSA construction (M2 / A2+A3), mirrors ssa.c + live.c
;;;;
;;;; A2 fill-live : backward-dataflow liveness (blk in/out/gen temp-sets).
;;;; A3 fill-use  : per-temp def/use/class/phi-class info (ssa.c filluse).
;;;;    phiins     : pruned-SSA phi insertion (dominance frontier + liveness).
;;;;    renblk     : dominator-tree renaming walk; fills phi args from preds.
;;;;    ssa         : filldom -> fillfron -> filllive -> phiins -> renblk.
;;;;
;;;; Oracle: `qbe -dN`'s "> After SSA construction:" printfn dump.  The
;;;; liveness bitsets here are the pre-isel version QBE computes *inside*
;;;; ssa() (ssa.c:339) to drive pruned phi placement; the machine-specific
;;;; RCall/RMem/rglob paths in live.c are inert before isel and omitted.

(in-package #:qbe)

;;; -------------------------------------------------------------- bitsets
;;; Dense id -> membership, over simple bit-vectors.  Keyed by temp id
;;; (liveness) or block id (phiins worklist).

(declaim (inline bs-make bs-copy-new bs-copy bs-zero bs-union bs-equal
                 bs-set bs-clr bs-has))
(defun bs-make (n) (make-array n :element-type 'bit :initial-element 0))
(defun bs-copy-new (src) (copy-seq src))
(defun bs-copy (dst src) (replace dst src))          ; dst := src
(defun bs-zero (bs) (fill bs 0))
(defun bs-union (dst src) (bit-ior dst src dst))      ; dst |= src
(defun bs-equal (a b) (equal a b))
(defun bs-set (bs i) (setf (sbit bs i) 1))
(defun bs-clr (bs i) (setf (sbit bs i) 0))
(defun bs-has (bs i) (= 1 (sbit bs i)))

;;; --------------------------------------------------------------- newtmp
;;; QBE's newtmp uses a single run-global counter (`static int n`) for the
;;; "%s.%d" suffix; it is never reset between functions of one qbe run, so
;;; callers reset it once per file (see test).  Only refindex advances it.

(defvar *tmp-counter* 0)
(defvar *undef* (make-con :kind :undef) "The singleton UNDEF ref.")

(defun newtmp (prefix cls fn)
  "Append a fresh temp to FN's registry and return it (= QBE's TMP(t))."
  (let* ((id (fill-pointer (fn-tmp fn)))
         (name (when prefix (format nil "~a.~d" prefix (incf *tmp-counter*))))
         (tm (make-tmp name id)))
    (setf (tmp-cls tm) cls (tmp-nuse tm) 1 (tmp-ndef tm) 1)
    (vector-push-extend tm (fn-tmp fn))
    tm))

(defun refindex (tid fn)
  "Fresh version of temp TID, inheriting its name prefix and class."
  (let ((ot (aref (fn-tmp fn) tid)))
    (newtmp (tmp-name ot) (tmp-cls ot) fn)))

(defun phicls (tid tmps)
  "Union-find find over phi classes (ssa.c phicls), with path compression."
  (let ((p (tmp-phi (aref tmps tid))))
    (if (null p) tid
        (let ((r (phicls p tmps)))
          (setf (tmp-phi (aref tmps tid)) r)
          r))))

(defun clsmerge (k1 k)
  "Merge two operand classes.  Returns (values merged err?) (ssa.c clsmerge)."
  (cond ((eq k1 :x) (values k nil))
        ((or (and (eq k1 :w) (eq k :l)) (and (eq k1 :l) (eq k :w)))
         (values :w nil))
        (t (values k1 (not (eq k1 k))))))

;;; -------------------------------------------------------------- fill-use
;;; ssa.c filluse: def/bid/ndef/nuse/use/cls/phi per temp.  (width is only
;;; needed by spill/rega; left at :full for now.)

(defun fill-use (fn)
  (let ((tmps (fn-tmp fn)))
    (dotimes (tid (fn-ntmp fn))
      (let ((tm (aref tmps tid)))
        (setf (tmp-def tm) nil (tmp-bid tm) -1 (tmp-ndef tm) 0
              (tmp-nuse tm) 0 (tmp-cls tm) :w (tmp-phi tm) nil
              (tmp-width tm) :full (tmp-use tm) nil)))
    (flet ((adduse (tm type b payload)
             (incf (tmp-nuse tm))
             (push (make-use-rec type (blk-id b) payload) (tmp-use tm))))
      (dolist (b (fn-blocks fn))
        (dolist (p (blk-phis b))
          (let* ((to (phi-to p)) (tp (tmp-id to)))
            (setf (tmp-bid (aref tmps tp)) (blk-id b))
            (incf (tmp-ndef (aref tmps tp)))
            (setf (tmp-cls (aref tmps tp)) (phi-cls p))
            (let ((rep (phicls tp tmps)))
              (dolist (pa (phi-args p))
                (let ((ref (cdr pa)))
                  (when (tmp-p ref)
                    (adduse (aref tmps (tmp-id ref)) :phi b p)
                    (let ((tt (phicls (tmp-id ref) tmps)))
                      (unless (= tt rep)
                        (setf (tmp-phi (aref tmps tt)) rep)))))))))
        (dolist (i (blk-ins b))
          (let ((to (ins-to i)))
            (when (tmp-p to)
              (let* ((tid (tmp-id to)) (tm (aref tmps tid)))
                (setf (tmp-def tm) i (tmp-bid tm) (blk-id b))
                (incf (tmp-ndef tm))
                (setf (tmp-cls tm) (ins-cls i)))))
          (when (tmp-p (ins-arg0 i)) (adduse (aref tmps (tmp-id (ins-arg0 i))) :ins b i))
          (when (tmp-p (ins-arg1 i)) (adduse (aref tmps (tmp-id (ins-arg1 i))) :ins b i)))
        (let ((ja (blk-jmp-arg b)))
          (when (tmp-p ja) (adduse (aref tmps (tmp-id ja)) :jmp b nil)))))))

;;; ------------------------------------------------------------- fill-live
;;; live.c liveon + filllive, pre-isel subset (no RCall/RMem/rglob).

(defun live-on (v b s)
  "V := liveness entering edge B->S: S's live-in, minus S's phi defs, plus
S's phi args coming from B (also recorded in B's gen)."
  (bs-copy v (blk-in s))
  (dolist (p (blk-phis s))
    (let ((to (phi-to p))) (when (tmp-p to) (bs-clr v (tmp-id to)))))
  (dolist (p (blk-phis s))
    (dolist (pa (phi-args p))
      (when (eq (car pa) b)
        (let ((ref (cdr pa)))
          (when (tmp-p ref)
            (bs-set v (tmp-id ref))
            (bs-set (blk-gen b) (tmp-id ref))))))))

(defun fill-live (fn)
  (let ((n (fn-ntmp fn)))
    (dolist (b (fn-blocks fn))
      (setf (blk-in b) (bs-make n) (blk-out b) (bs-make n) (blk-gen b) (bs-make n)))
    (let ((v (bs-make n)) (chg t))
      (loop while chg do
        (setf chg nil)
        (loop for k from (1- (fn-nblk fn)) downto 0
              for b = (aref (fn-rpo fn) k) do
          (let ((u (bs-copy-new (blk-out b))))
            (when (blk-s1 b) (live-on v b (blk-s1 b)) (bs-union (blk-out b) v))
            (when (blk-s2 b) (live-on v b (blk-s2 b)) (bs-union (blk-out b) v))
            (unless (bs-equal (blk-out b) u) (setf chg t)))
          (bs-copy (blk-in b) (blk-out b))
          (let ((ja (blk-jmp-arg b)))
            (when (tmp-p ja)
              (bs-set (blk-gen b) (tmp-id ja))
              (bs-set (blk-in b) (tmp-id ja))))
          (dolist (i (reverse (blk-ins b)))
            (let ((to (ins-to i)))
              (when (tmp-p to)
                (bs-set (blk-gen b) (tmp-id to))
                (bs-clr (blk-in b) (tmp-id to))))
            (when (tmp-p (ins-arg0 i))
              (bs-set (blk-gen b) (tmp-id (ins-arg0 i)))
              (bs-set (blk-in b) (tmp-id (ins-arg0 i))))
            (when (tmp-p (ins-arg1 i))
              (bs-set (blk-gen b) (tmp-id (ins-arg1 i)))
              (bs-set (blk-in b) (tmp-id (ins-arg1 i))))))))))

;;; ---------------------------------------------------------------- phiins
;;; ssa.c phiins: pruned-SSA phi placement.

(defun phiins (fn)
  (let* ((tmps (fn-tmp fn))
         (nb (fn-nblk fn))
         (u (bs-make nb))
         (defs (bs-make nb))
         (blist (make-array nb))
         (nt (fn-ntmp fn)))                    ; snapshot; refindex grows ntmp
    (dotimes (tid nt)
      (setf (tmp-visit (aref tmps tid)) nil)
      (block skip
        (when (tmp-phi (aref tmps tid)) (return-from skip))   ; phi-class member
        (when (= (tmp-ndef (aref tmps tid)) 1)
          (let ((ok t) (defb (tmp-bid (aref tmps tid))))
            (dolist (use (tmp-use (aref tmps tid)))
              (unless (= (use-rec-bid use) defb) (setf ok nil)))
            (when (or ok (= defb (blk-id (fn-start fn))))
              (return-from skip))))
        (bs-zero u)
        (let ((kcls :x) (bp nb) (self (aref tmps tid)))
          ;; rename multiply-defined defs to fresh locals where not live-out;
          ;; blocks whose def *is* live-out seed the worklist.
          (dolist (b (fn-blocks fn))
            (setf (blk-visit b) 0)
            (let ((r nil))
              (dolist (i (blk-ins b))
                (when r
                  (when (eq (ins-arg0 i) self) (setf (ins-arg0 i) r))
                  (when (eq (ins-arg1 i) self) (setf (ins-arg1 i) r)))
                (when (eq (ins-to i) self)
                  (if (not (bs-has (blk-out b) tid))
                      (setf r (refindex tid fn) (ins-to i) r)
                      (progn
                        (unless (bs-has u (blk-id b))
                          (bs-set u (blk-id b))
                          (setf (aref blist (decf bp)) b))
                        (multiple-value-bind (nk err) (clsmerge kcls (ins-cls i))
                          (when err (error "qbe: invalid input (clsmerge)"))
                          (setf kcls nk))))))
              (when (and r (eq (blk-jmp-arg b) self))
                (setf (blk-jmp-arg b) r))))
          ;; iterated dominance frontier, pruned by liveness (a->in)
          (bs-copy defs u)
          (loop while (< bp nb) do
            (setf (tmp-visit self) tid)
            (let ((b (aref blist bp)))
              (incf bp)
              (bs-clr u (blk-id b))
              (dolist (a (blk-fron b))
                (let ((seen (blk-visit a)))
                  (incf (blk-visit a))
                  (when (and (= seen 0) (bs-has (blk-in a) tid))
                    (push (make-instance 'phi :to self :cls kcls :args nil)
                          (blk-phis a))
                    (unless (or (bs-has defs (blk-id a)) (bs-has u (blk-id a)))
                      (bs-set u (blk-id a))
                      (setf (aref blist (decf bp)) a))))))))))))

;;; ---------------------------------------------------------------- renblk
;;; ssa.c renblk: rename over the dominator tree, filling phi args from preds.
;;; stk[t] is a stack of (versioned-ref . defining-blk); visit maps any temp
;;; (original or versioned) back to its original id.

(defun getstk (tid b stk)
  "Reaching version of original temp TID at block B (ssa.c getstk)."
  (let ((n (aref stk tid)))
    (loop while (and n (not (dom (cdr (car n)) b))) do (setf n (cdr n)))
    (setf (aref stk tid) n)
    (if (null n) *undef* (car (car n)))))

(defun rendef (r b stk fn)
  "If R defines a renamed temp, push a fresh version and return it; else R."
  (if (and (tmp-p r) (tmp-visit (aref (fn-tmp fn) (tmp-id r))))
      (let* ((tid (tmp-id r)) (r1 (refindex tid fn)))
        (setf (tmp-visit r1) tid)
        (push (cons r1 b) (aref stk tid))
        r1)
      r))

(defun ren-use (r b stk fn)
  "Rewrite a use R to its reaching version, if its temp is being renamed."
  (if (and (tmp-p r) (tmp-visit (aref (fn-tmp fn) (tmp-id r))))
      (getstk (tmp-visit (aref (fn-tmp fn) (tmp-id r))) b stk)
      r))

(defun renblk (b stk fn)
  (dolist (p (blk-phis b))
    (setf (phi-to p) (rendef (phi-to p) b stk fn)))
  (dolist (i (blk-ins b))
    (setf (ins-arg0 i) (ren-use (ins-arg0 i) b stk fn)
          (ins-arg1 i) (ren-use (ins-arg1 i) b stk fn)
          (ins-to i)   (rendef (ins-to i) b stk fn)))
  (setf (blk-jmp-arg b) (ren-use (blk-jmp-arg b) b stk fn))
  ;; fill successor phi args (s1 then s2, distinct)
  (let ((succ (list (blk-s1 b))))
    (when (and (blk-s2 b) (not (eq (blk-s2 b) (blk-s1 b))))
      (setf succ (nconc succ (list (blk-s2 b)))))
    (dolist (s succ)
      (when s
        (dolist (p (blk-phis s))
          (let ((tv (tmp-visit (phi-to p))))     ; original id (via visit)
            (when tv
              (setf (phi-args p)
                    (nconc (phi-args p) (list (cons b (getstk tv b stk)))))))))))
  (dolist (s (blk-doms b))
    (renblk s stk fn)))

;;; ------------------------------------------------------------------- ssa
;;; Requires fill-cfg (rpo+preds) and fill-use already run.

(defun ssa (fn)
  (fill-dom fn)
  (fill-fron fn)
  (fill-live fn)
  (phiins fn)
  (let ((stk (make-array (fn-ntmp fn) :initial-element nil)))
    (renblk (fn-start fn) stk fn)))
