;;;; amd64-isel.lisp --- amd64 instruction selection (M3/B3), mirrors amd64/isel.c
;;;;
;;;; SLICE a: the scalar integer path — pass-through arithmetic/logic/conversion,
;;;; constant-amount shifts, dead-code elimination, and compare selection
;;;; (standalone compare -> xcmp + flag; compare feeding jnz -> xcmp + jf<cc>).
;;;; div/rem, variable shifts, sel (cmov), loads/stores/allocs (addressing),
;;;; and float comparisons are deferred to later slices (abi-unsupported).
;;;;
;;;; Oracle: `qbe -dI`'s "> After instruction selection:" dump.

(in-package #:qbe)

;;; ---- comparison encoding (all.h CmpI/CmpF; iscmp; cmptab swap; flag/jf order)

(defparameter *cmp-codes*
  (let ((h (make-hash-table :test 'eq))
        (iw '(:ceqw :cnew :csgew :csgtw :cslew :csltw :cugew :cugtw :culew :cultw))
        (il '(:ceql :cnel :csgel :csgtl :cslel :csltl :cugel :cugtl :culel :cultl))
        (fs '(:ceqs :cges :cgts :cles :clts :cnes :cos :cuos))
        (fd '(:ceqd :cged :cgtd :cled :cltd :cned :cod :cuod)))
    (loop for op in iw for c from 0 do (setf (gethash op h) (cons c :w)))
    (loop for op in il for c from 0 do (setf (gethash op h) (cons c :l)))
    (loop for op in fs for c from 10 do (setf (gethash op h) (cons c :s)))
    (loop for op in fd for c from 10 do (setf (gethash op h) (cons c :d)))
    h))

(defun iscmp (op)
  "If OP is a comparison return (values c k): c the combined CmpI/CmpF code
   (0..17), k the operand class; else NIL."
  (let ((e (gethash op *cmp-codes*)))
    (when e (values (car e) (cdr e)))))

(defparameter *flag-ops*
  #(:flagieq :flagine :flagisge :flagisgt :flagisle :flagislt
    :flagiuge :flagiugt :flagiule :flagiult
    :flagfeq :flagfge :flagfgt :flagfle :flagflt :flagfne :flagfo :flagfuo))
(defparameter *jf-jumps-vec*
  #(:jfieq :jfine :jfisge :jfisgt :jfisle :jfislt :jfiuge :jfiugt :jfiule :jfiult
    :jffeq :jffge :jffgt :jffle :jfflt :jffne :jffo :jffuo))

;; cmptab[c][1] — comparison code when the two operands are swapped.
(defparameter *cmpop-swap*
  #(0 1 4 5 2 3 8 9 6 7 10 13 14 11 12 15 16 17))
(defconstant +cine+ 1)      ; Cine, for "jump if nonzero"

;; amd64_op zflag/lflag (amd64/targ.c via ops.h X()) — for flagi.
(defparameter *zflag-ops*
  '(:add :sub :neg :and :or :xor :sar :shr :shl :blit0 :blit1 :xcmp :xtest
    :ceqw :cnew :csgew :csgtw :cslew :csltw :cugew :cugtw :culew :cultw
    :ceql :cnel :csgel :csgtl :cslel :csltl :cugel :cugtl :culel :cultl
    :ceqs :cges :cgts :cles :clts :cnes :cos :cuos
    :ceqd :cged :cgtd :cled :cltd :cned :cod :cuod))
(defun op-zflag (op) (and (member op *zflag-ops*) t))
(defun op-lflag (op)
  (or (isload-op op) (isstore-op op)
      (member op '(:extsb :extub :extsh :extuh :extsw :extuw :exts :truncd
                   :stosi :stoui :dtosi :dtoui :swtof :uwtof :sltof :ultof
                   :cast :copy :dbgloc :nop :addr))
      (and (>= (length (symbol-name op)) 4)
           (string= (symbol-name op) "FLAG" :end1 4))))

;;; ---------------------------------------------------------------- helpers

(defun noimm (r)
  "Is R a constant that can't be an x86 immediate (not a 32-bit signed int)?"
  (and (con-p r)
       (ecase (con-kind r)
         (:addr nil)
         (:bits (let ((v (con-value r)))
                  (or (< v #x-80000000) (> v #x7fffffff)))))))

(defun chuse (r du)
  (when (tmp-p r) (incf (tmp-nuse r) du)))

(defun emiti (i) (push i *emitted*))

;;; ------------------------------------------------------------------ fixarg

(defun fixarg (r op k fn)
  "Fix operand R (class K) of an OP instruction, emitting any load it needs, and
   return the ref to use.  Scalar cases: 64-bit immediates and address operands
   go through a temporary; everything else is unchanged."
  (cond
    ((null r) r)
    ;; a constant too large for a 32-bit immediate must live in a register
    ((and (not (eq op :copy)) (eq k :l) (noimm r))
     (let ((tm (newtmp "isel" :l fn))) (emit :copy :l tm r nil) tm))
    ;; an address operand becomes an lea/mov into a temporary
    ((and (con-p r) (eq (con-kind r) :addr)
          (not (eq op :call)) (not (isload-op op)) (not (isstore-op op)))
     (if (or (member :ext (con-symtype r)) (member :thr (con-symtype r)))
         (abi-unsupported "extern/thread-local address operand")
         (let ((tm (newtmp "isel" :l fn))) (emit :addr :l tm r nil) tm)))
    ;; floating-point constants must be loaded from memory (later slice)
    ((and (con-p r) (eq (con-kind r) :bits) (con-flt r))
     (abi-unsupported "float constant operand"))
    (t r)))

;;; ------------------------------------------------------------------ compares

(defun cmpswap (c arg0)
  "Should the two compare operands be swapped?  (amd64/isel.c cmpswap)"
  (cond ((or (= c 13) (= c 14)) 1)          ; float le / lt
        ((or (= c 11) (= c 12)) 0)          ; float ge / gt
        ((con-p arg0) 1)
        (t 0)))

(defun selcmp (a0 a1 k swap fn)
  "Emit the xcmp for a comparison of A0,A1 at class K (amd64/isel.c selcmp)."
  (when (= swap 1) (rotatef a0 a1))
  (emit :xcmp k nil a1 a0)                    ; note: xcmp reverses the operands
  (let ((icmp (car *emitted*)))
    (when (con-p a0)
      (let ((tm (newtmp "isel" k fn)))
        (setf (ins-arg1 icmp) tm)
        (emit :copy k tm a0 nil)
        (setf (ins-arg0 (car *emitted*))
              (fixarg (ins-arg0 (car *emitted*)) :copy k fn))))
    (setf (ins-arg0 icmp) (fixarg (ins-arg0 icmp) :xcmp k fn))
    (setf (ins-arg1 icmp) (fixarg (ins-arg1 icmp) :xcmp k fn))))

;;; --------------------------------------------------------------------- sel

(defparameter *sel-passthrough*
  '(:copy :add :sub :neg :mul :and :or :xor
    :stosi :dtosi :swtof :sltof :exts :truncd :cast
    :extsb :extub :extsh :extuh :extsw :extuw :call :dbgloc :salloc))

(defun sel-emit (i fn)
  (let ((ic (copy-ins i)) (op (ins-op i)) (k (ins-cls i)))
    (emiti ic)
    (setf (ins-arg0 ic) (fixarg (ins-arg0 ic) op (argcls op k 0) fn))
    (setf (ins-arg1 ic) (fixarg (ins-arg1 ic) op (argcls op k 1) fn))))

(defun sel (i fn)
  ;; dead-code elimination: an unused pure result is dropped
  (when (and (tmp-p (ins-to i))
             (not (reg-p (ins-to i)))
             (not (reg-p (ins-arg0 i))) (not (reg-p (ins-arg1 i)))
             (= 0 (tmp-nuse (ins-to i))))
    (chuse (ins-arg0 i) -1) (chuse (ins-arg1 i) -1)
    (return-from sel))
  (let ((op (ins-op i)) (k (ins-cls i)))
    (cond
      ((eq op :nop))
      ((member op *sel-passthrough*) (sel-emit i fn))
      ((member op '(:sar :shr :shl))
       (if (con-p (ins-arg1 i)) (sel-emit i fn)
           (abi-unsupported "variable shift")))
      ((iscmp op)
       (multiple-value-bind (c kc) (iscmp op)
         (when (member kc '(:s :d)) (abi-unsupported "float comparison"))
         (let* ((swap (cmpswap c (ins-arg0 i)))
                (cc (if (= swap 1) (aref *cmpop-swap* c) c)))
           (emit (aref *flag-ops* cc) k (ins-to i) nil nil)
           (selcmp (ins-arg0 i) (ins-arg1 i) kc swap fn))))
      ((member op '(:div :rem :udiv :urem)) (abi-unsupported "div/rem"))
      ((member op '(:sel0 :sel1)) (abi-unsupported "sel (cmov)"))
      ((isload-op op) (abi-unsupported "load"))
      ((isstore-op op) (abi-unsupported "store"))
      ((member op '(:alloc4 :alloc8 :alloc16)) (abi-unsupported "alloc"))
      ((member op '(:ultof :uwtof :stoui :dtoui)) (abi-unsupported "unsigned conv"))
      (t (abi-unsupported (format nil "isel op ~a" op))))))

;;; --------------------------------------------------------------------- seljmp

(defun flagi (ins)
  "Last flag-setting instruction in INS (a list, program order), skipping
   flag-transparent ops; NIL if an opaque op intervenes (amd64/isel.c flagi)."
  (dolist (i (reverse ins) nil)
    (cond ((op-zflag (ins-op i)) (return i))
          ((op-lflag (ins-op i)))
          (t (return nil)))))

(defun seljmp (b fn)
  (when (eq (blk-jmp-type b) :jnz)
    (let* ((r (blk-jmp-arg b)) (tm r))
      (setf (blk-jmp-arg b) nil)
      (cond
        ((eq (blk-s1 b) (blk-s2 b))
         (chuse r -1) (setf (blk-jmp-type b) :jmp (blk-s2 b) nil))
        (t
         (let ((fi (flagi (blk-ins b))))
           (cond
             ((or (null fi) (not (eq (ins-to fi) r)))
              (selcmp r (getcon 0 fn) :w 0 fn)
              (setf (blk-jmp-type b) (aref *jf-jumps-vec* +cine+)))
             ((multiple-value-bind (c kc) (iscmp (ins-op fi))
                (and c (/= c 10) (/= c 15)   ; not float eq/ne (see sel)
                     (progn
                       (when (member kc '(:s :d)) (abi-unsupported "float branch"))
                       (let* ((swap (cmpswap c (ins-arg0 fi)))
                              (cc (if (= swap 1) (aref *cmpop-swap* c) c)))
                         (when (= 1 (tmp-nuse tm))
                           (selcmp (ins-arg0 fi) (ins-arg1 fi) kc swap fn)
                           (setf (ins-op fi) :nop (ins-to fi) nil
                                 (ins-arg0 fi) nil (ins-arg1 fi) nil))
                         (setf (blk-jmp-type b) (aref *jf-jumps-vec* cc)))
                       t))))
             ((and (eq (ins-op fi) :and) (= 1 (tmp-nuse tm))
                   (or (tmp-p (ins-arg0 fi)) (tmp-p (ins-arg1 fi))))
              (setf (ins-op fi) :xtest (ins-to fi) nil
                    (blk-jmp-type b) (aref *jf-jumps-vec* +cine+))
              (when (con-p (ins-arg1 fi)) (rotatef (ins-arg0 fi) (ins-arg1 fi))))
             (t
              (when (= 1 (tmp-nuse tm)) (emit :copy :w nil r nil))
              (setf (blk-jmp-type b) (aref *jf-jumps-vec* +cine+))))))))))

;;; --------------------------------------------------------------------- driver

(defun amd64-isel (fn)
  "amd64 instruction selection (B3 scalar-integer slice)."
  (dolist (b (fn-blocks fn))
    (let ((*emitted* nil))
      ;; fix up phi arguments coming from this block
      (dolist (s (remove-duplicates (remove nil (list (blk-s1 b) (blk-s2 b)))))
        (dolist (p (blk-phis s))
          (let ((pair (assoc b (phi-args p) :test #'eq)))
            (when pair (setf (cdr pair) (fixarg (cdr pair) :copy (phi-cls p) fn))))))
      (seljmp b fn)
      (let ((vec (coerce (blk-ins b) 'vector)))
        (loop for k from (1- (length vec)) downto 0
              do (sel (aref vec k) fn)))
      (setf (blk-ins b) *emitted*))))
