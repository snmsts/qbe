;;;; rega.lisp --- M4 register allocation (rega.c), post-spill.
;;;;
;;;; Linear-scan-ish allocator over the spilled IR: assigns each temporary a
;;;; machine register (or leaves it in its spill slot), threading hints along
;;;; phi classes, and repairs phi/edge disagreements with parallel-move blocks.
;;;; Registers already live in the id space (materialize-regs); a temp id t with
;;;; t<Tmp0 IS its own register (hint.r=t).
;;;;
;;;; Oracle: `qbe -dR` "> After register allocation:" printfn dump (+ the
;;;; "Register mappings" beg/end dump and move/block stats).

(in-package #:qbe)

;;; RMap (rega.c): t/r parallel arrays (temp<->reg), w wait-list, b membership.
(defstruct (rmap (:constructor %make-rmap))
  (tt (make-array +tmp0+ :initial-element 0))
  (rr (make-array +tmp0+ :initial-element 0))
  (ww (make-array +tmp0+ :initial-element 0))
  b (n 0))
(defun make-rmap (nt) (let ((m (%make-rmap))) (setf (rmap-b m) (bs-make nt)) m))

(defun rmap-copy (ma mb)              ; rcopy: ma := mb
  (replace (rmap-tt ma) (rmap-tt mb))
  (replace (rmap-rr ma) (rmap-rr mb))
  (replace (rmap-ww ma) (rmap-ww mb))
  (bs-copy (rmap-b ma) (rmap-b mb))
  (setf (rmap-n ma) (rmap-n mb)))

;;; rega-local statics (rega.c file scope), bound per rega() call.
(defvar *ra-fn*)
(defvar *ra-tmp*)
(defvar *ra-regu*)      ; registers used (bits)
(defvar *ra-loop*)      ; current loop level
(defvar *ra-pm*)        ; parallel-move vector of (src dst cls)
(defvar *ra-npm*)
(defvar *ra-stmov*)
(defvar *ra-stblk*)

(defun ra-tmp (t*) (aref *ra-tmp* t*))

;;; ---------------------------------------------------------------- hints
(defun ra-hint (t*) (tmp-hint-r (ra-tmp (phicls t* *ra-tmp*))))
(defun (setf ra-hint) (v t*) (setf (tmp-hint-r (ra-tmp (phicls t* *ra-tmp*))) v))

(defun ra-sethint (t* r)
  (let ((p (ra-tmp (phicls t* *ra-tmp*))))
    (when (or (= (tmp-hint-r p) -1) (> (tmp-hint-w p) *ra-loop*))
      (setf (tmp-hint-r p) r (tmp-hint-w p) *ra-loop* (tmp-visit (ra-tmp t*)) -1))))

;;; --------------------------------------------------------- RMap operations
(defun ra-rfind (m t*)
  (dotimes (i (rmap-n m) -1)
    (when (= (aref (rmap-tt m) i) t*) (return (aref (rmap-rr m) i)))))

(defun ra-rref (m t*)
  (let ((r (ra-rfind m t*)))
    (if (= r -1)
        (let ((s (tmp-slot (ra-tmp t*))))
          (assert (/= s -1) () "should have spilled")
          (make-slot-ref s))
        (tid-ref r *ra-fn*))))

(defun ra-radd (m t* r)
  (assert (or (>= t* +tmp0+) (= t* r)))
  (assert (or (and (<= +gpr0+ r) (< r (+ +gpr0+ +ngpr+)))
              (and (<= +fpr0+ r) (< r (+ +fpr0+ +nfpr+)))))
  (assert (not (bs-has (rmap-b m) t*)))
  (assert (not (bs-has (rmap-b m) r)))
  (bs-set (rmap-b m) t*) (bs-set (rmap-b m) r)
  (setf (aref (rmap-tt m) (rmap-n m)) t* (aref (rmap-rr m) (rmap-n m)) r)
  (incf (rmap-n m))
  (setf *ra-regu* (logior *ra-regu* (ash 1 r)))
  (tid-ref r *ra-fn*))

(defun ra-ralloctry (m t* try)
  (cond
    ((< t* +tmp0+) (assert (bs-has (rmap-b m) t*)) (tid-ref t* *ra-fn*))
    ((bs-has (rmap-b m) t*) (tid-ref (ra-rfind m t*) *ra-fn*))
    (t
     (let ((r (tmp-visit (ra-tmp t*))))
       (when (or (= r -1) (bs-has (rmap-b m) r)) (setf r (ra-hint t*)))
       (when (or (= r -1) (bs-has (rmap-b m) r))
         (when try (return-from ra-ralloctry nil))
         (let* ((regs (logior (tmp-hint-m (ra-tmp (phicls t* *ra-tmp*)))
                              (bs-regmask (rmap-b m))))
                (r0 (if (= (cls-base (tmp-cls (ra-tmp t*))) 0) +gpr0+ +fpr0+))
                (r1 (+ r0 (if (= (cls-base (tmp-cls (ra-tmp t*))) 0) +ngpr+ +nfpr+))))
           (setf r
                 (or (loop for rr from r0 below r1
                           when (not (logbitp rr regs)) return rr)
                     (loop for rr from r0 below r1
                           when (not (bs-has (rmap-b m) rr)) return rr)
                     (error "no more regs")))))
       ;; Found:
       (ra-radd m t* r)
       (ra-sethint t* r)
       (setf (tmp-visit (ra-tmp t*)) r)
       (let ((h (ra-hint t*)))
         (when (and (/= h -1) (/= h r)) (setf (aref (rmap-ww m) h) t*)))
       (tid-ref r *ra-fn*)))))

(defun ra-ralloc (m t*) (ra-ralloctry m t* nil))

(defun ra-rfree (m t*)
  "Remove t*'s mapping; return its register (or -1 if unmapped)."
  (assert (or (>= t* +tmp0+) (not (logbitp t* +rglob+))))
  (if (not (bs-has (rmap-b m) t*))
      -1
      (let ((i 0))
        (loop until (= (aref (rmap-tt m) i) t*) do (assert (< (1+ i) (rmap-n m))) (incf i))
        (let ((r (aref (rmap-rr m) i)))
          (bs-clr (rmap-b m) t*) (bs-clr (rmap-b m) r)
          (decf (rmap-n m))
          (loop for j from i below (rmap-n m)
                do (setf (aref (rmap-tt m) j) (aref (rmap-tt m) (1+ j))
                         (aref (rmap-rr m) j) (aref (rmap-rr m) (1+ j))))
          (assert (or (>= t* +tmp0+) (= t* r)))
          r))))

(defun ra-mdump-map (m)
  "One `(name, R<reg>)` line body for user temps mapped in M (mdump)."
  (with-output-to-string (s)
    (dotimes (i (rmap-n m))
      (when (>= (aref (rmap-tt m) i) +tmp0+)
        (format s " (~a, R~d)" (tmp-name (ra-tmp (aref (rmap-tt m) i))) (aref (rmap-rr m) i))))))

;;; ------------------------------------------------------------ parallel moves
(defstruct pmove src dst cls)

(defun ra-pmadd (src dst k)
  (when (>= *ra-npm* (length *ra-pm*))
    (setf *ra-pm* (adjust-array *ra-pm* (* 2 (length *ra-pm*)))))
  (setf (aref *ra-pm* *ra-npm*) (make-pmove :src src :dst dst :cls k))
  (incf *ra-npm*))

(defun ref= (a b)
  "req: value equality of refs (slot-refs compare by slot number, not identity)."
  (cond ((and (null a) (null b)) t)
        ((and (reg-p a) (reg-p b)) (= (reg-id a) (reg-id b)))
        ((and (slot-ref-p a) (slot-ref-p b)) (= (slot-ref-n a) (slot-ref-n b)))
        (t (eq a b))))

(defun ra-pmrec (status i kbox)
  "pmgen recursion (rega.c pmrec): emit copies/swaps to realise the moves."
  (let ((pm (aref *ra-pm* i)))
    (if (ref= (pmove-src pm) (pmove-dst pm))
        (progn (setf (aref status i) :moved) -1)
        (progn
          (setf (aref kbox 0) (clsmerge2 (aref kbox 0) (pmove-cls pm)))
          (let ((j (or (loop for jj below *ra-npm*
                             when (ref= (pmove-dst (aref *ra-pm* jj)) (pmove-src pm)) return jj)
                       *ra-npm*)))
            (let ((st (if (= j *ra-npm*) :moved (aref status j)))
                  (c -1))
              (ecase st
                (:moving
                 (setf c j)
                 (emit :swap (aref kbox 0) nil (pmove-src pm) (pmove-dst pm)))
                (:tomove
                 (setf (aref status i) :moving)
                 (setf c (ra-pmrec status j kbox))
                 (cond
                   ((= c i) (setf c -1))
                   ((/= c -1)
                    (emit :swap (aref kbox 0) nil (pmove-src pm) (pmove-dst pm)))
                   (t (emit :copy (pmove-cls pm) (pmove-dst pm) (pmove-src pm) nil))))
                (:moved
                 (setf c -1)
                 (emit :copy (pmove-cls pm) (pmove-dst pm) (pmove-src pm) nil)))
              (setf (aref status i) :moved)
              c))))))

(defun clsmerge2 (a b)
  "*k |= pm.cls with Kw|Kl==Kl, Ks|Kd==Kd (rega.c pmrec asserts same KBASE)."
  (let ((rank (lambda (k) (ecase k (:w 0) (:l 1) (:s 2) (:d 3)))))
    (if (> (funcall rank b) (funcall rank a)) b a)))

(defun ra-pmgen ()
  (let ((status (make-array *ra-npm* :initial-element :tomove)))
    (dotimes (i *ra-npm*)
      (when (eq (aref status i) :tomove)
        (ra-pmrec status i (vector (pmove-cls (aref *ra-pm* i))))))))

;;; --------------------------------------------------------------- move / dopm
(defun ra-move (r to m)
  (let ((r1 (if (null to) -1 (ra-rfree m (ref-tid to)))))
    (when (bs-has (rmap-b m) r)
      (assert (/= r1 r))
      (let ((n 0))
        (loop until (= (aref (rmap-rr m) n) r) do (assert (< (1+ n) (rmap-n m))) (incf n))
        (let ((tt (aref (rmap-tt m) n)))
          (ra-rfree m tt) (bs-set (rmap-b m) r) (ra-ralloc m tt) (bs-clr (rmap-b m) r))))
    (let ((tt (if (null to) r (ref-tid to))))
      (ra-radd m tt r))))

(defun ra-regcpy (i) (and (eq (ins-op i) :copy) (reg-p (ins-arg0 i))))

(defun ra-dopm (vec k m)
  "Handle a run of register-copies ending at VEC[K] via parallel moves; returns
the run's first index (rega.c dopm)."
  (let ((m0 (%make-rmap)) (i k))
    (replace (rmap-tt m0) (rmap-tt m))
    (replace (rmap-rr m0) (rmap-rr m))
    (setf (rmap-n m0) (rmap-n m))     ; m0.b unused (rega.c neuters m0.b->t)
    (loop
      (ra-move (ref-tid (ins-arg0 (aref vec i))) (ins-to (aref vec i)) m)
      (if (and (> i 0) (ra-regcpy (aref vec (1- i)))) (decf i) (return)))
    (when (and (> i 0) (eq (ins-op (aref vec (1- i))) :call))
      (let ((def (logior (reduce (lambda (a rid) (logior a (ash 1 rid)))
                                 (sysv-retregs (call-ref-val (ins-arg1 (aref vec (1- i)))))
                                 :initial-value 0)
                         +rglob+)))
        (loop for rid across *sysv-rsave*
              when (not (logbitp rid def)) do (ra-move rid nil m))))
    (setf *ra-npm* 0)
    (dotimes (n (rmap-n m))
      (let* ((tt (aref (rmap-tt m) n)) (s (tmp-slot (ra-tmp tt))) (r1 (aref (rmap-rr m) n))
             (r (ra-rfind m0 tt)))
        (cond ((/= r -1) (ra-pmadd (tid-ref r1 *ra-fn*) (tid-ref r *ra-fn*) (tmp-cls (ra-tmp tt))))
              ((/= s -1) (ra-pmadd (tid-ref r1 *ra-fn*) (make-slot-ref s) (tmp-cls (ra-tmp tt)))))))
    (loop for ip from i to k do
      (let ((ins (aref vec ip)))
        (when (ins-to ins) (ra-rfree m (ref-tid (ins-to ins))))
        (let ((r (ref-tid (ins-arg0 ins))))
          (when (= (ra-rfind m r) -1) (ra-radd m r r)))))
    (ra-pmgen)
    i))


;;; ---------------------------------------------------- operand alloc ordering
(defun ra-prio1 (val) (/= (ra-hint val) -1))   ; prio1: hinted operands first

(defun ra-insert-operand (rs entry)
  "rega.c insert(): append ENTRY, then bubble it left while it is hinted."
  (let ((p (fill-pointer rs)))
    (vector-push-extend entry rs)
    (loop for k downfrom p above 0
          while (ra-prio1 (first entry))
          do (rotatef (aref rs k) (aref rs (1- k))))
    rs))

(defun ra-set-operand (e newref)
  (destructuring-bind (val kind obj) e
    (declare (ignore val))
    (ecase kind
      (:arg0 (setf (ins-arg0 obj) newref))
      (:arg1 (setf (ins-arg1 obj) newref))
      (:base (setf (mem-ref-base obj) newref))
      (:index (setf (mem-ref-index obj) newref)))))

(defun ra-doblk (b cur)
  "Allocate registers within block B (rega.c doblk).  Returns the new blk-ins."
  (when (tmp-p (blk-jmp-arg b))
    (setf (blk-jmp-arg b) (ra-ralloc cur (tmp-id (blk-jmp-arg b)))))
  (let ((*emitted* nil) (vec (coerce (blk-ins b) 'vector)) (i1 nil))
    (setf i1 (length vec))
    (loop while (> i1 0) do
      (decf i1)
      (let* ((orig (aref vec i1))
             (i (make-instance 'ins :op (ins-op orig) :cls (ins-cls orig)
                               :to (ins-to orig) :arg0 (ins-arg0 orig) :arg1 (ins-arg1 orig)))
             (rf -1) (skip nil))
        (push i *emitted*)                    ; emiti(*--i1); i = curi
        (block dispatch
          (case (ins-op i)
            (:call
             (let ((rs (logior (ra-idmask (sysv-argregs (call-ref-val (ins-arg1 i)))) +rglob+)))
               (loop for rid across *sysv-rsave*
                     unless (logbitp rid rs) do (ra-rfree cur rid))))
            (:copy
             (when (ra-regcpy i)
               (pop *emitted*)                ; curi++
               (let ((before (rmap-n cur)))
                 (declare (ignore before))
                 (setf i1 (ra-dopm vec i1 cur)))
               (return-from dispatch (setf skip :dopm)))
             (when (and (reg-p (ins-to i)) (tmp-p (ins-arg0 i)))
               (ra-sethint (tmp-id (ins-arg0 i)) (reg-id (ins-to i))))
             (setf rf (ra-def i cur))
             (when (eq rf :dropped) (return-from dispatch (setf skip :dropped))))
            (t
             (setf rf (ra-def i cur))
             (when (eq rf :dropped) (return-from dispatch (setf skip :dropped))))))
        (unless skip
          ;; collect + order argument operands (hinted first), then allocate
          (let ((ra (make-array 4 :fill-pointer 0 :adjustable t)))
            (dolist (spec (list (cons :arg0 (ins-arg0 i)) (cons :arg1 (ins-arg1 i))))
              (let ((a (cdr spec)))
                (cond
                  ((mem-ref-p a)
                   (when (tmp-p (mem-ref-base a)) (ra-insert-operand ra (list (tmp-id (mem-ref-base a)) :base a)))
                   (when (tmp-p (mem-ref-index a)) (ra-insert-operand ra (list (tmp-id (mem-ref-index a)) :index a))))
                  ((tmp-p a) (ra-insert-operand ra (list (tmp-id a) (car spec) i))))))
            (let ((allocd '()))
              (loop for e across ra do
                (let ((nr (ra-ralloc cur (first e))))
                  (ra-set-operand e nr)
                  (push (cons e nr) allocd)))
              ;; drop a no-op copy
              (when (and (eq (ins-op i) :copy) (ref= (ins-to i) (ins-arg0 i)))
                (pop *emitted*))
              ;; hinted-temp register-change (rega.c doblk tail)
              (when (/= rf -1)
                (let ((tt (aref (rmap-ww cur) rf)))
                  (when (and (/= tt 0) (not (bs-has (rmap-b cur) rf)) (= (ra-hint tt) rf))
                    (let ((rt (ra-rfree cur tt)))
                      (when (/= rt -1)
                        (setf (tmp-visit (ra-tmp tt)) -1)
                        (ra-ralloc cur tt)
                        (emit :copy (tmp-cls (ra-tmp tt)) (tid-ref rt *ra-fn*) (tid-ref rf *ra-fn*) nil)
                        (incf *ra-stmov*)
                        (setf (aref (rmap-ww cur) rf) 0)
                        (dolist (pair allocd)
                          (when (ref= (cdr pair) (tid-ref rt *ra-fn*))
                            (ra-set-operand (car pair) (tid-ref rf *ra-fn*)))))))))))
          )))
    *emitted*))

(defun ra-idmask (ids)
  (reduce (lambda (a id) (logior a (ash 1 id))) ids :initial-value 0))

(defun ra-def (i cur)
  "Handle i->to (rega.c doblk default/copy case).  Returns the freed register
rf (or -1 if none / kept), or :dropped if the instruction is dead and dropped."
  (let ((to (ins-to i)))
    (if (null to)
        -1
        (let ((r (ref-tid to)))
          (if (and (< r +tmp0+) (logbitp r +rglob+))
              -1                                  ; rglob def: keep
              (let ((rf (ra-rfree cur r)))
                (if (= rf -1)
                    (progn (assert (not (reg-p to))) (pop *emitted*) :dropped)
                    (progn (setf (ins-to i) (tid-ref rf *ra-fn*)) rf))))))))

;;; -------------------------------------------------------------------- rega
(defun ra-prio2> (t1 t2)
  "rega.c prio2 as strict `t1 precedes t2` for the block-end insertion sort."
  (let ((v1 (tmp-visit (ra-tmp t1))) (v2 (tmp-visit (ra-tmp t2))))
    (cond
      ((not (eq (< v1 0) (< v2 0))) (/= v1 -1))
      (t (let ((h1 (ra-hint t1)) (h2 (ra-hint t2)))
           (cond ((not (eq (< h1 0) (< h2 0))) (/= h1 -1))
                 (t (> (tmp-cost (ra-tmp t1)) (tmp-cost (ra-tmp t2))))))))))

(defun ra-insert-prio2 (rs t*)
  "rega.c: rl[j]=t; while(j-->0 && prio2(t,rl[j])>0) shift.  RS is a fill-pointer
vector; bubbles t* left while it should precede its left neighbour."
  (let ((p (fill-pointer rs)))
    (vector-push-extend t* rs)
    (loop for k downfrom p above 0
          while (ra-prio2> t* (aref rs (1- k)))
          do (rotatef (aref rs k) (aref rs (1- k))))
    rs))

(defun rega (fn)
  "Register allocation (requires rpo, phi, cost, spill).  Rewrites FN in place."
  (let* ((*ra-fn* fn) (*ra-tmp* (fn-tmp fn)) (*ra-regu* 0) (*ra-loop* most-positive-fixnum)
         (*ra-pm* (make-array 64)) (*ra-npm* 0) (*ra-stmov* 0) (*ra-stblk* 0)
         (nt (fn-ntmp fn)) (nblk (fn-nblk fn))
         (end (make-array nblk)) (beg (make-array nblk))
         (cur (make-rmap nt)))
    (dotimes (n nblk) (setf (aref end n) (make-rmap nt) (aref beg n) (make-rmap nt)))
    (dotimes (t* nt)
      (setf (tmp-hint-r (aref *ra-tmp* t*)) (if (< t* +tmp0+) t* -1)
            (tmp-hint-w (aref *ra-tmp* t*)) *ra-loop*
            (tmp-visit (aref *ra-tmp* t*)) -1))
    (let ((blk (stable-sort (copy-list (fn-blocks fn))
                            (lambda (a b) (if (= (blk-loop a) (blk-loop b))
                                              (< (blk-id a) (blk-id b))
                                              (> (blk-loop a) (blk-loop b)))))))
      (loop for i in (blk-ins (fn-start fn))
            while (and (eq (ins-op i) :copy) (reg-p (ins-arg0 i)))
            do (ra-sethint (tmp-id (ins-to i)) (reg-id (ins-arg0 i))))
      (dolist (b blk)
        (let ((n (blk-id b)))
          (setf *ra-loop* (blk-loop b) (rmap-n cur) 0)
          (bs-zero (rmap-b cur)) (fill (rmap-ww cur) 0)
          (let ((rl (make-array 8 :fill-pointer 0 :adjustable t)))
            (loop for t* from +tmp0+ below nt when (bs-has (blk-out b) t*)
                  do (ra-insert-prio2 rl t*))
            (loop for r from 0 below +tmp0+ when (bs-has (blk-out b) r)
                  do (ra-radd cur r r))
            (loop for t* across rl do (ra-ralloctry cur t* t))
            (loop for t* across rl do (ra-ralloc cur t*)))
          (rmap-copy (aref end n) cur)
          (setf (blk-ins b) (ra-doblk b cur))
          (bs-copy (blk-in b) (rmap-b cur))
          (dolist (p (blk-phis b))
            (when (tmp-p (phi-to p)) (bs-clr (blk-in b) (tmp-id (phi-to p)))))
          (rmap-copy (aref beg n) cur))))
    (ra-shared-edges fn beg end)
    (ra-edge-blocks fn beg end)
    (dolist (b (fn-blocks fn)) (setf (blk-phis b) nil))
    (setf (fn-reg fn) *ra-regu*)
    (values beg end *ra-stmov* *ra-stblk*)))

;;; phase 3: emit copies shared by multiple edges into the same block
(defun ra-shared-edges (fn beg end)
  (dolist (s (fn-blocks fn))
    (when (> (length (blk-preds s)) 1)
      (let ((m (aref beg (blk-id s)))
            (rl (make-array +tmp0+ :initial-element 0)))   ; indexed by register
        (dolist (p (blk-phis s))
          (when (tmp-p (phi-to p))
            (let ((r (ra-rfind m (tmp-id (phi-to p)))))
              (when (/= r -1)
                (loop for (pb . src) in (phi-args p) do
                  (when (tmp-p src)
                    (let ((x (ra-rfind (aref end (blk-id pb)) (tmp-id src))))
                      (unless (= x -1)
                        (setf (aref rl r) (if (or (zerop (aref rl r)) (= (aref rl r) x)) x -1))))))
                (when (zerop (aref rl r)) (setf (aref rl r) -1))))))
        (dotimes (j (rmap-n m))
          (let ((tt (aref (rmap-tt m) j)) (r (aref (rmap-rr m) j)))
            (when (and (zerop (aref rl r)) (>= tt +tmp0+))
              (dolist (pb (blk-preds s))
                (let ((x (ra-rfind (aref end (blk-id pb)) tt)))
                  (unless (= x -1)
                    (setf (aref rl r) (if (or (zerop (aref rl r)) (= (aref rl r) x)) x -1)))))
              (when (zerop (aref rl r)) (setf (aref rl r) -1)))))
        (setf *ra-npm* 0)
        (dotimes (j (rmap-n m))
          (let* ((tt (aref (rmap-tt m) j)) (r (aref (rmap-rr m) j)) (x (aref rl r)))
            (assert (or (/= x 0) (< tt +tmp0+)))
            (when (and (> x 0) (not (bs-has (rmap-b m) x)))
              (ra-pmadd (tid-ref x *ra-fn*) (tid-ref r *ra-fn*) (tmp-cls (ra-tmp tt)))
              (setf (aref (rmap-rr m) j) x)
              (bs-set (rmap-b m) x))))
        (let ((*emitted* nil))
          (ra-pmgen)
          (when *emitted*
            (incf *ra-stmov* (length *emitted*))
            (setf (blk-ins s) (append *emitted* (blk-ins s)))))))))

;;; phase 4: emit remaining edge copies in fresh blocks
(defun ra-edge-blocks (fn beg end)
  (let ((blist '()) (blocks (fn-blocks fn)))
    (dolist (b blocks)
      (dolist (slot '(:s1 :s2))
        (let ((s (if (eq slot :s1) (blk-s1 b) (blk-s2 b))))
          (when s
            (setf *ra-npm* 0)
            (dolist (p (blk-phis s))
              (let ((dst (phi-to p)))
                (when (or (not (tmp-p dst))
                          (let ((r (ra-rfind (aref beg (blk-id s)) (tmp-id dst))))
                            (when (/= r -1) (setf dst (tid-ref r *ra-fn*)) t)))
                  (let ((src (cdr (assoc b (phi-args p)))))
                    (when (tmp-p src) (setf src (ra-rref (aref end (blk-id b)) (tmp-id src))))
                    (ra-pmadd src dst (phi-cls p))))))
            (loop for t* from +tmp0+ below (fn-ntmp fn) when (bs-has (blk-in s) t*)
                  do (ra-pmadd (ra-rref (aref end (blk-id b)) t*)
                               (ra-rref (aref beg (blk-id s)) t*) (tmp-cls (ra-tmp t*))))
            (let ((*emitted* nil))
              (ra-pmgen)
              (when *emitted*
                (let ((b1 (make-instance 'blk :name (format nil "~a_~a" (blk-name b) (blk-name s)))))
                  (setf (blk-loop b1) (floor (+ (blk-loop b) (blk-loop s)) 2))
                  (push b1 blist)
                  (incf (fn-nblk fn))
                  (incf *ra-stmov* (length *emitted*)) (incf *ra-stblk*)
                  (setf (blk-ins b1) *emitted*
                        (blk-jmp-type b1) :jmp (blk-s1 b1) s)
                  (if (eq slot :s1) (setf (blk-s1 b) b1) (setf (blk-s2 b) b1)))))))))
    ;; append new blocks to the layout (QBE: b_last->link = blist, LIFO order)
    ;; and relink blk-link so the printer's fall-through elision matches.
    (setf (fn-blocks fn) (append (fn-blocks fn) blist))
    (loop for (b . rest) on (fn-blocks fn) do (setf (blk-link b) (car rest)))))
