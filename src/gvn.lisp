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

(defun gvn (fn)
  "Global value numbering (C3, normins slice).  Requires fill-cfg + fill-use."
  (dolist (b (fn-blocks fn))
    (dolist (i (blk-ins b))
      (unless (eq (ins-op i) :nop)
        (normins fn i))))
  (fill-cfg fn))                        ; rebuildcfg (no dead-block move yet)
