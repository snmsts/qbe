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
(defparameter *xsel-ops*
  #(:xselieq :xseline :xselisge :xselisgt :xselisle :xselislt
    :xseliuge :xseliugt :xseliule :xseliult
    :xselfeq :xselfge :xselfgt :xselfle :xselflt :xselfne :xselfo :xselfuo))

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
    ;; a conditional-move (cmov) can't take an immediate operand
    ((and (con-p r) (find op *xsel-ops*))
     (let ((tm (newtmp "isel" k fn))) (emit :copy k tm r nil) tm))
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

;; x86 integer division: dividend in RAX, sign/zero-extended into RDX, quotient
;; back in RAX and remainder in RDX (amd64/isel.c sel Odiv/Orem case).
(defun sel-divrem (i fn)
  (let* ((op (ins-op i)) (k (ins-cls i))
         (signed (member op '(:div :rem)))
         (quo (member op '(:div :udiv)))
         (r0 (if quo (rg 1) (rg 3)))          ; result register (RAX / RDX)
         (r1 (if quo (rg 3) (rg 1)))          ; the other (clobbered) register
         (divisor (ins-arg1 i)) (dcon (con-p divisor))
         (dvr (if dcon (newtmp "isel" k fn) divisor)))
    (emit :copy k (ins-to i) r0 nil)
    (emit :copy k nil r1 nil)
    (if signed
        (progn (emit :xidiv k nil dvr nil)
               (emit :sign k (rg 3) (rg 1) nil))
        (progn (emit :xdiv k nil dvr nil)
               (emit :copy k (rg 3) (getcon 0 fn) nil)))
    (emit :copy k (rg 1) (ins-arg0 i) nil)
    (setf (ins-arg0 (car *emitted*)) (fixarg (ins-arg0 (car *emitted*)) :copy k fn))
    (when dcon (emit :copy k dvr divisor nil))))

;; variable shift amounts must be in CL (RCX) (amd64/isel.c sel Osar/Oshr/Oshl).
(defun sel-shift (i fn)
  (let ((k (ins-cls i)) (amt (ins-arg1 i)) (ic (copy-ins i)))
    (setf (ins-arg1 ic) (rg 2))               ; RCX
    (emit :copy :w nil (rg 2) nil)            ; clobber RCX
    (emiti ic)
    (emit :copy :w (rg 2) amt nil)            ; load the shift amount into RCX
    (setf (ins-arg0 ic)
          (fixarg (ins-arg0 ic) (ins-op ic) (argcls (ins-op ic) k 0) fn))))

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
      ((member op '(:div :rem :udiv :urem))
       (if (= (cls-base k) 1) (sel-emit i fn) (sel-divrem i fn)))
      ((member op '(:sar :shr :shl))
       (if (con-p (ins-arg1 i)) (sel-emit i fn) (sel-shift i fn)))
      ((iscmp op)
       (multiple-value-bind (c kc) (iscmp op)
         (when (member kc '(:s :d)) (abi-unsupported "float comparison"))
         (let* ((swap (cmpswap c (ins-arg0 i)))
                (cc (if (= swap 1) (aref *cmpop-swap* c) c)))
           (emit (aref *flag-ops* cc) k (ins-to i) nil nil)
           (selcmp (ins-arg0 i) (ins-arg1 i) kc swap fn))))
      ((member op '(:xselieq :xseline :xselisge :xselisgt :xselisle :xselislt
                    :xseliuge :xseliugt :xseliule :xseliult
                    :xselfeq :xselfge :xselfgt :xselfle :xselflt :xselfne
                    :xselfo :xselfuo))
       (sel-emit i fn))
      ((member op '(:sel0 :sel1)) (abi-unsupported "stray sel"))
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

;;; ----------------------------------------------------------------- selsel
;;; amd64/isel.c selsel: turn an ifconvert sel0/sel1 group into conditional
;;; moves (xsel<cc>), taking the condition from the flag-setter before sel0.

(defun selsel (fn b vec k)
  "Lower the sel0/sel1 group ending at VEC[k] (a sel1); return the sel0 index."
  (declare (ignore b))
  (let ((i0 k))
    (loop while (and (> i0 0) (not (eq (ins-op (aref vec i0)) :sel0))) do (decf i0))
    (let* ((sel0 (aref vec i0))
           (r (ins-arg0 sel0)) (rt r)
           (fi (flagi (coerce (subseq vec 0 i0) 'list)))
           (cr0 nil) (cr1 nil) (gencmp nil) (gencpy nil) (swap 0) (kc :w) (c +cine+))
      (cond
        ((or (null fi) (not (eq (ins-to fi) r)))
         (setf gencmp t cr0 r cr1 (getcon 0 fn)))
        ((iscmp (ins-op fi))
         (multiple-value-bind (cc k2) (iscmp (ins-op fi))
           (if (or (= cc 10) (= cc 15))       ; float eq/ne -> checked with Cine
               (when (= 1 (tmp-nuse rt)) (setf gencpy t))
               (progn
                 (setf swap (cmpswap cc (ins-arg0 fi)))
                 (setf c (if (= swap 1) (aref *cmpop-swap* cc) cc) kc k2)
                 (when (= 1 (tmp-nuse rt))
                   (setf gencmp t cr0 (ins-arg0 fi) cr1 (ins-arg1 fi))
                   (setf (ins-op fi) :nop (ins-to fi) nil
                         (ins-arg0 fi) nil (ins-arg1 fi) nil))))))
        ((and (eq (ins-op fi) :and) (= 1 (tmp-nuse rt))
              (or (tmp-p (ins-arg0 fi)) (tmp-p (ins-arg1 fi))))
         (setf (ins-op fi) :xtest (ins-to fi) nil)
         (when (con-p (ins-arg1 fi)) (rotatef (ins-arg0 fi) (ins-arg1 fi))))
        (t (when (= 1 (tmp-nuse rt)) (setf gencpy t))))
      ;; each sel1 (from k down to i0+1) becomes an xsel<c>
      (loop for j from k downto (1+ i0) do
        (setf (ins-op (aref vec j)) (aref *xsel-ops* c))
        (sel (aref vec j) fn))
      (when gencmp (selcmp cr0 cr1 kc swap fn))
      (when gencpy (emit :copy :w nil r nil))
      i0)))

;;; ---------------------------------------------------------------------- simpl
;;; simpl.c runs between abi1 and isel.  The scalar-relevant transform: an
;;; unsigned divide/remainder by a constant power of two becomes a shift/mask.
;;; (blit expansion is deferred — blit isn't in the scalar isel subset.)

(defun ispow2 (v) (and (> v 0) (zerop (logand v (1- v)))))
(defun ulog2 (v) (1- (integer-length v)))

(defun simpl (fn)
  (dolist (b (fn-blocks fn))
    (dolist (i (blk-ins b))
      (when (and (member (ins-op i) '(:udiv :urem))
                 (= 0 (cls-base (ins-cls i)))
                 (con-p (ins-arg1 i)) (eq (con-kind (ins-arg1 i)) :bits)
                 (null (con-flt (ins-arg1 i)))
                 (ispow2 (con-value (ins-arg1 i))))
        (let ((n (ulog2 (con-value (ins-arg1 i)))))
          (if (eq (ins-op i) :urem)
              (setf (ins-op i) :and (ins-arg1 i) (getcon (1- (ash 1 n)) fn))
              (setf (ins-op i) :shr (ins-arg1 i) (getcon n fn))))))))

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
      (let* ((vec (coerce (blk-ins b) 'vector)) (k (1- (length vec))))
        (loop while (>= k 0) do
          (let ((i (aref vec k)))
            (if (eq (ins-op i) :sel1)
                (setf k (1- (selsel fn b vec k)))
                (progn (sel i fn) (decf k))))))
      (setf (blk-ins b) *emitted*))))
