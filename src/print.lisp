;;;; print.lisp --- module -> QBE IL text  (mirrors printfn/printref)
;;;;
;;;; Output is byte-compatible with `qbe -dP` (the after-parsing dump), which
;;;; is the M0 diff oracle.  Note printfn prints the *internal* form:
;;;; `function $name() {`, no linkage, params already lowered to par ins, etc.

(in-package #:qbe)

(defparameter *ret-types*
  '(:retw :retl :rets :retd :retsb :retub :retsh :retuh :retc :ret0))

(defun fmt-c-float (x)
  "C printf %f / %lf: fixed notation, 6 fractional digits."
  (format nil "~,6F" x))

(defun print-con (c stream)
  (ecase (con-kind c)
    (:bits
     (case (con-flt c)
       (1 (format stream "s_~a" (fmt-c-float (con-value c))))
       (2 (format stream "d_~a" (fmt-c-float (con-value c))))
       (t (format stream "~d" (con-value c)))))
    (:addr
     (when (member :ext (con-symtype c)) (write-string "extern " stream))
     (when (member :thr (con-symtype c)) (write-string "thread " stream))
     (format stream "$~a" (con-symname c))
     (unless (zerop (con-off c)) (format stream "~@d" (con-off c))))
    (:undef (write-string "UNDEF" stream))))

(defun print-ref (r stream)
  (cond
    ((null r)         (write-string "R" stream))
    ((tmp-p r)        (format stream "%~a" (tmp-name r)))
    ((con-p r)        (print-con r stream))
    ((typep r 'typ)   (format stream ":~a" (typ-name r)))
    ((integerp r)     (format stream "~d" r))
    ((reg-p r)        (format stream "R~d" (reg-id r)))
    ((call-ref-p r)   (format stream "~4,'0x" (call-ref-val r)))
    ((slot-ref-p r)   (format stream "S~d" (slot-ref-n r)))
    (t (error "qbe: cannot print ref ~s" r))))

(defun print-phi (p stream)
  (write-char #\Tab stream)
  (print-ref (phi-to p) stream)
  (format stream " =~c phi " (class-char (phi-cls p)))
  (loop for rest on (phi-args p)
        for (blk . ref) = (car rest) do
          (format stream "@~a " (blk-name blk))
          (print-ref ref stream)
          (when (cdr rest) (write-string ", " stream)))
  (write-char #\Newline stream))

(defun print-ins (i stream)
  (write-char #\Tab stream)
  (let ((to (ins-to i)))
    (unless (null to)
      (print-ref to stream)
      (format stream " =~c " (class-char (ins-cls i))))
    (write-string (op-name (ins-op i)) stream)
    (when (and (null to) (classchar-op-p (ins-op i)))
      (write-char (class-char (ins-cls i)) stream))
    (unless (null (ins-arg0 i))
      (write-char #\Space stream)
      (print-ref (ins-arg0 i) stream))
    (unless (null (ins-arg1 i))
      (write-string ", " stream)
      (print-ref (ins-arg1 i) stream))
    (write-char #\Newline stream)))

(defun print-jmp (b fn stream)
  (let ((jt (blk-jmp-type b)) (arg (blk-jmp-arg b)))
    (cond
      ((member jt *ret-types*)
       (format stream "~c~a" #\Tab (string-downcase (symbol-name jt)))
       (unless (and (eq jt :ret0) (null arg))
         (write-char #\Space stream)
         (print-ref arg stream))
       (when (eq jt :retc)
         (format stream ", :~a" (typ-name (fn-rettyp fn))))
       (write-char #\Newline stream))
      ((eq jt :hlt) (format stream "~chlt~%" #\Tab))
      ((eq jt :jmp)
       (unless (eq (blk-s1 b) (blk-link b))
         (format stream "~cjmp @~a~%" #\Tab (blk-name (blk-s1 b)))))
      ((eq jt :jnz)
       (format stream "~cjnz " #\Tab)
       (print-ref arg stream)
       (format stream ", @~a, @~a~%" (blk-name (blk-s1 b)) (blk-name (blk-s2 b))))
      (t (error "qbe: cannot print jmp ~s" jt)))))

(defun print-fn (fn &optional (stream *standard-output*))
  (format stream "function $~a() {~%" (fn-name fn))
  (dolist (b (fn-blocks fn))
    (format stream "@~a~%" (blk-name b))
    (dolist (p (blk-phis b)) (print-phi p stream))
    (dolist (i (blk-ins b)) (print-ins i stream))
    (print-jmp b fn stream))
  (format stream "}~%"))

(defun print-fn-to-string (fn)
  (with-output-to-string (s) (print-fn fn s)))
