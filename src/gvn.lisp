;;;; gvn.lisp --- global value numbering (M2/C3), mirrors gvn.c
;;;;
;;;; INCREMENTAL: this first slice implements `normins` (the canonicalization
;;;; QBE applies to every instruction: 32-bit constant truncation for narrow
;;;; arg classes + commutative operand ordering) and the gvn driver skeleton.
;;;; copy propagation (copyref), constant folding (foldref), CSE (gvndup),
;;;; phi dedup (dedupphi), jnz simplification (dedupjmp), and narrowpars are
;;;; added in later slices.  Oracle: `qbe -dG` "> After GVN:".

(in-package #:qbe)

;;; class code + KWIDE (all.h: Kx=-1 Kw=0 Kl=1 Ks=2 Kd=3; parse.c Ke=-2 Km=Kl)
(defun cls-code (k) (ecase k (:w 0) (:l 1) (:s 2) (:d 3) (:x -1) (:e -2) (:m 1)))
(defun kwide (k) (= 1 (logand (cls-code k) 1)))

(defun isconbits (r)
  "Integer value of R if it is an integer bits constant, else NIL."
  (and (con-p r) (eq (con-kind r) :bits) (null (con-flt r)) (con-value r)))

(defun getcon (v fn)
  "Intern the integer constant V (mirrors getcon(): dedup by value)."
  (let* ((v (norm-i64 v)) (key (list :bits v)))
    (or (gethash key (fn-cons fn))
        (let ((c (make-con :kind :bits :value v :idx (fn-ncon fn))))
          (incf (fn-ncon fn))
          (setf (gethash key (fn-cons fn)) c)))))

;;; rcmp: order refs by (type, val); RTmp(0) sorts before RCon(1), so the
;;; canonical commutative form keeps a temp in arg[0] and a constant in arg[1].
(defun ref-rank (r) (cond ((tmp-p r) 0) ((con-p r) 1) (t 2)))
(defun ref-val (r) (cond ((tmp-p r) (tmp-id r)) ((con-p r) (or (con-idx r) 0)) (t 0)))
(defun rcmp (a b)
  (if (/= (ref-rank a) (ref-rank b))
      (- (ref-rank a) (ref-rank b))
      (- (ref-val a) (ref-val b))))

(defun ins-arg (i n) (if (zerop n) (ins-arg0 i) (ins-arg1 i)))
(defun (setf ins-arg) (v i n) (if (zerop n) (setf (ins-arg0 i) v) (setf (ins-arg1 i) v)))

(defun normins (fn i)
  "Canonicalize instruction I in place (gvn.c normins)."
  ;; truncate constant bits to 32 for narrow (non-KWIDE) argument classes
  (dotimes (n 2)
    (let ((arg (ins-arg i n)))
      (when (and arg (not (kwide (argcls (ins-op i) (ins-cls i) n))))
        (let ((v (isconbits arg)))
          (when (and v (/= (logand v #xffffffff) v))
            (setf (ins-arg i n) (getcon (logand v #xffffffff) fn)))))))
  ;; order commutative operands: arg[0] <= arg[1]
  (when (and (op-commutes (ins-op i)) (ins-arg0 i) (ins-arg1 i)
             (> (rcmp (ins-arg0 i) (ins-arg1 i)) 0))
    (rotatef (ins-arg0 i) (ins-arg1 i))))

;;; ------------------------------------------------------- use rewriting
(defvar *con01* #(nil nil) "getcon 0 / 1 for the current fn (copyref identities).")

(defun add-use (tm type b payload)
  (incf (tmp-nuse tm))
  (push (make-use-rec type (blk-id b) payload) (tmp-use tm)))

(defun replaceuse (fn u r1 r2)
  "Rewrite one use U of R1 to R2 (gvn.c replaceuse)."
  (let ((b (aref (fn-rpo fn) (use-rec-bid u)))
        (t2 (when (tmp-p r2) r2)))
    (ecase (use-rec-type u)
      (:phi (let ((p (use-rec-payload u)))
              (setf (phi-args p)
                    (mapcar (lambda (pair) (if (eq (cdr pair) r1) (cons (car pair) r2) pair))
                            (phi-args p)))
              (when t2 (add-use t2 :phi b p))))
      (:ins (let ((i (use-rec-payload u)))
              (when (eq (ins-arg0 i) r1) (setf (ins-arg0 i) r2))
              (when (eq (ins-arg1 i) r1) (setf (ins-arg1 i) r2))
              (when t2 (add-use t2 :ins b i))))
      (:jmp (when (eq (blk-jmp-arg b) r1) (setf (blk-jmp-arg b) r2))
            (when t2 (add-use t2 :jmp b nil))))))

(defun replaceuses (fn r1 r2)
  (let ((t1 (aref (fn-tmp fn) (tmp-id r1))))
    (dolist (u (tmp-use t1)) (replaceuse fn u r1 r2))
    (setf (tmp-nuse t1) 0 (tmp-use t1) nil)))

(defun killins (fn i r)
  (replaceuses fn (ins-to i) r)
  (setf (ins-op i) :nop (ins-cls i) :w (ins-to i) nil (ins-arg0 i) nil (ins-arg1 i) nil))

;;; ----------------------------------------------------------- copyref
;;; copy.c copyref, core cases (width-analysis/zeroval/and-mask deferred).

(defun copyref (fn i)
  (let ((op (ins-op i)) (a0 (ins-arg0 i)) (a1 (ins-arg1 i)))
    (declare (ignore fn))
    (cond
      ((eq op :copy) a0)
      ;; op identity value: x+0, x*1, x|0, ...  (integer only; skip cmp-id which
      ;; needs width analysis)
      ((and (op-hasid op) (= (cls-base (ins-cls i)) 0)
            (eq a1 (aref *con01* (op-idval op)))
            (not (op-cmpeqwl op)))
       a0)
      ;; idempotent with identical args: x&x, x|x
      ((and (op-idemp op) (eq a0 a1)) a0)
      ;; integer cmp with identical args -> eqval
      ((and (or (op-cmpeqwl op) (op-cmplgtewl op)) (eq a0 a1))
       (aref *con01* (op-eqval op)))
      ;; extsw/extuw producing a w result is a copy
      ((and (eq (ins-cls i) :w) (member op '(:extsw :extuw))) a0)
      (t nil))))

;;; --------------------------------------------------------- gvndup (CSE)
(defvar *gvntbl* nil "equal-hash: value-key -> defining ins (CSE table).")

(defun ref-key (r)
  (cond ((tmp-p r) (cons :t (tmp-id r)))
        ((con-p r) (cons :c (con-idx r)))
        ((null r) nil)
        (t (cons :o r))))

(defun ins-key (i)
  (list (ins-op i) (ins-cls i) (ref-key (ins-arg0 i)) (ref-key (ins-arg1 i))))

(defun gvndup (i insert)
  "Return an existing equivalent ins, or NIL (inserting I when INSERT)."
  (let* ((k (ins-key i)) (found (gethash k *gvntbl*)))
    (or found (progn (when insert (setf (gethash k *gvntbl*) i)) nil))))

;;; --------------------------------------------------------- dedup driver

(defun dedupins (fn b i)
  (declare (ignore b))
  (normins fn i)
  (when (or (eq (ins-op i) :nop) (op-pinned (ins-op i)))
    (return-from dedupins))
  (let ((r (copyref fn i)))
    (when r (killins fn i r) (return-from dedupins)))
  ;; foldref (constant folding) deferred to a later slice
  (let ((i1 (gvndup i t)))
    (when i1 (killins fn i i1) (return-from dedupins))))

;;; ---------------------------------------------------------- dedupphi
;;; copy.c phicopyref, core: identical args, or same as an earlier phi.

(defun phi-eq (pa pb)
  "Do phis PA and PB have identical (blk->arg) mappings?"
  (and (= (length (phi-args pa)) (length (phi-args pb)))
       (every (lambda (pair)
                (let ((other (assoc (car pair) (phi-args pb) :test #'eq)))
                  (and other (eq (cdr pair) (cdr other)))))
              (phi-args pa))))

(defun phicopyref (b p)
  ;; identical args (ignoring self-references to p->to)
  (let ((r nil) (all t))
    (dolist (pair (phi-args p))
      (let ((a (cdr pair)))
        (unless (eq a (phi-to p))
          (cond ((null r) (setf r a))
                ((not (eq a r)) (setf all nil) (return))))))
    (when all (return-from phicopyref (or r (phi-to p)))))
  ;; same as a previous phi in this block
  (dolist (p1 (blk-phis b))
    (when (eq p1 p) (return))
    (when (phi-eq p1 p) (return-from phicopyref (phi-to p1))))
  nil)

(defun dedupphi (fn b)
  (setf (blk-phis b)
        (remove nil
                (mapcar (lambda (p)
                          (let ((r (phicopyref b p)))
                            (if r (progn (replaceuses fn (phi-to p) r) nil) p)))
                        (blk-phis b)))))

(defun gvn (fn)
  "Global value numbering (C3): copy-prop + CSE + phi-dedup + canonicalization.
Requires fill-cfg.  (foldref, dedupjmp, narrowpars, dead-block move: later.)"
  (let ((*con01* (vector (getcon 0 fn) (getcon 1 fn)))
        (*gvntbl* (make-hash-table :test 'equal)))
    (fill-use fn)
    (loop for n below (fn-nblk fn)
          for b = (aref (fn-rpo fn) n) do
      (dedupphi fn b)
      (dolist (i (blk-ins b)) (dedupins fn b i)))
    (fill-cfg fn)))                     ; rebuildcfg (no dead-block move yet)
