;;;; arm64.lisp --- naive code generator for arm64 (Apple / mach-o).
;;;;
;;;; The G1 walking skeleton: the arm64 twin of amd64.lisp.  Same "everything in
;;;; a stack slot, one instruction at a time via x9/x10 scratch" scheme -- no
;;;; register allocation, no SSA construction -- but lowering to AArch64 with
;;;; Apple assembler conventions so it links and runs natively on Apple Silicon
;;;; via `cc`.  This proves the target seam (G0) end to end before the faithful
;;;; arm64 abi/isel/emit grind (G2..G4) replaces it.
;;;;
;;;; Covers the same subset as amd64.lisp M1/B: integer classes w/l; ops
;;;;   par copy add sub mul and or xor neg
;;;;   c{eq,ne,slt,sle,sgt,sge,ult,ule,ugt,uge}{w,l}   (comparisons -> 0/1)
;;;;   load{sb,ub,sh,uh,sw,uw} load  store{b,h,w,l}  alloc{4,8,16}
;;;; terminators jmp / jnz / ret / ret0, and phi (lowered to edge copies).
;;;; Floats, calls, blit, and variadics are out of scope and error out.
;;;;
;;;; Apple conventions (arm64/emit.c, T_arm64_apple): `_`-prefixed globals,
;;;; `L`-prefixed local labels, `.balign 4`, no `.type`/`.size`, `hint #34`
;;;; (BTI) prologue, stp/ldp x29,x30 frame.

(in-package #:qbe)

;;; ------------------------------------------------------------ registers
;;; Scratch registers: x9/x10 are the AArch64 temporary (caller-save) regs, so
;;; using them as our two accumulators clobbers nothing the callee must keep.
;;; :a -> x9/w9, :c -> x10/w10.  The frame pointer is x29, sp is sp.

(defun a64-r (which cls)
  "Register name for scratch WHICH (:a/:c) at class CLS (:w -> w9, :l -> x9)."
  (let ((n (ecase which (:a 9) (:c 10))))
    (format nil "~a~d" (if (eq cls :l) "x" "w") n)))

(defun m1a-class (cls)
  (unless (member cls '(:w :l))
    (error "arm64: unsupported class ~s (integer w/l only)" cls))
  cls)

(defun alloc-align (op) (ecase op (:alloc4 4) (:alloc8 8) (:alloc16 16)))

;;; comparison op keyword -> (cond-code . operand-class), cset condition.
(defparameter *a64-cmp-info*
  (let ((h (make-hash-table :test 'eq)))
    (loop for (base . cc) in '(("ceq" . "eq")  ("cne" . "ne")
                               ("csge" . "ge") ("csgt" . "gt")
                               ("csle" . "le") ("cslt" . "lt")
                               ("cuge" . "hs") ("cugt" . "hi")
                               ("cule" . "ls") ("cult" . "lo"))
          do (dolist (cls '(:w :l))
               (setf (gethash (intern (string-upcase
                                       (concatenate 'string base
                                                    (if (eq cls :w) "w" "l")))
                                      :keyword) h)
                     (cons cc cls))))
    h))

(defparameter *a64-binop*
  '((:add . "add") (:sub . "sub") (:mul . "mul")
    (:and . "and") (:or . "orr") (:xor . "eor")))

;;; load op keyword -> (mnemonic . dest-is-wide-x?).  AArch64 loads pick width
;;; from the mnemonic (ldrb/ldrh byte/halfword; ldrsw sign-extends w->x).
(defparameter *a64-load-info*
  '((:loadsb "ldrsb" . :by-cls) (:loadub "ldrb" . nil)
    (:loadsh "ldrsh" . :by-cls) (:loaduh "ldrh" . nil)
    (:loadsw "ldrsw" . t)       (:loaduw "ldr"  . nil)
    (:load   "ldr"   . :by-cls)))

;;; store op keyword -> mnemonic (value always comes from a w/x scratch).
(defparameter *a64-store-info*
  '((:storeb . "strb") (:storeh . "strh") (:storew . "str") (:storel . "str")))

;;; ------------------------------------------------------------ frame layout
;;; Locals live below x29 (negative offsets), like amd64's %rbp frame.  The
;;; whole frame is 16-byte aligned (AArch64 sp alignment).

(defstruct a64frame slots allocs staging size)

(defun a64-layout-frame (fn)
  (let ((slots (make-hash-table :test 'eq))
        (allocs (make-hash-table :test 'eq))
        (used 0) (maxphi 0))
    (flet ((slot! (r) (when (and (tmp-p r) (not (gethash r slots)))
                        (setf (gethash r slots) (- (incf used 8))))))
      (dolist (b (fn-blocks fn))
        (setf maxphi (max maxphi (length (blk-phis b))))
        (dolist (p (blk-phis b)) (slot! (phi-to p)))
        (dolist (i (blk-ins b)) (slot! (ins-to i))))
      (let ((staging (make-array maxphi)))
        (dotimes (i maxphi) (setf (aref staging i) (- (incf used 8))))
        (dolist (b (fn-blocks fn))
          (dolist (i (blk-ins b))
            (when (member (ins-op i) '(:alloc4 :alloc8 :alloc16))
              (let* ((sz (a64-const-size (ins-arg0 i)))
                     (al (alloc-align (ins-op i))))
                (setf used (* al (ceiling (+ used sz) al)))
                (setf (gethash i allocs) (- used))))))
        (make-a64frame :slots slots :allocs allocs :staging staging
                       :size (* 16 (ceiling used 16)))))))

(defun a64-const-size (r)
  (if (and (con-p r) (eq (con-kind r) :bits)) (con-value r)
      (error "arm64: alloc size must be a constant")))

;;; ------------------------------------------------------------ operands
;;; Frame offsets can exceed the 9-bit signed range of a base+imm ldur/stur, so
;;; we always form the address as [x29, #off] and trust the assembler's ldr/str
;;; (which accepts the full scaled 12-bit unsigned range for our small frames).

(defun a64-slot-off (fr r)
  (or (gethash r (a64frame-slots fr))
      (error "arm64: undefined temp ~s" (tmp-name r))))

(defun a64-loadcon (val cls reg stream)
  "Materialize integer constant VAL into REG (arm64/emit.c loadcon, naive: mov
low 16 bits then movk the rest)."
  (let ((n (if (eq cls :l)
               (logand val #xffffffffffffffff)
               (logand val #xffffffff)))
        (width (if (eq cls :l) 64 32)))
    ;; sign-normalize small negatives so `mov #-n` is emitted when it fits
    (let ((sn (if (eq cls :l)
                  (if (>= n (ash 1 63)) (- n (ash 1 64)) n)
                  (if (>= n (ash 1 31)) (- n (ash 1 32)) n))))
      (cond
        ((<= -65536 sn 65535)
         (format stream "~amov ~a, #~d~%" #\Tab reg sn))
        (t
         (format stream "~amov ~a, #~d~%" #\Tab reg (logand n #xffff))
         (loop for sh from 16 below width by 16
               for chunk = (logand (ash n (- sh)) #xffff)
               when (plusp chunk)
                 do (format stream "~amovk ~a, #~d, lsl #~d~%" #\Tab reg chunk sh)))))))

(defun a64-load-operand (r cls which fr stream)
  "Load operand R (a temp slot or a constant) into scratch WHICH at class CLS."
  (let ((reg (a64-r which cls)))
    (cond
      ((tmp-p r)
       (format stream "~aldr ~a, [x29, #~d]~%" #\Tab reg (a64-slot-off fr r)))
      ((con-p r)
       (unless (eq (con-kind r) :bits)
         (error "arm64: non-integer-constant operand ~s" r))
       (a64-loadcon (con-value r) cls reg stream))
      (t (error "arm64: bad operand ~s" r)))))

(defun a64-store-a (to cls fr stream)
  (format stream "~astr ~a, [x29, #~d]~%" #\Tab (a64-r :a cls) (a64-slot-off fr to)))

;;; ------------------------------------------------------------ instructions

(defun a64-emit-ins (i fr param-counter stream)
  (let* ((op (ins-op i)) (cmp (gethash op *a64-cmp-info*))
         (cls (and (ins-to i) (m1a-class (ins-cls i)))))
    (cond
      ((eq op :par)
       (let ((k (car param-counter)))
         (when (>= k 8) (error "arm64: too many register params"))
         (setf (car param-counter) (1+ k))
         ;; incoming arg k is in w<k>/x<k>; spill it to its slot
         (format stream "~astr ~a~d, [x29, #~d]~%" #\Tab
                 (if (eq cls :l) "x" "w") k (a64-slot-off fr (ins-to i)))))
      ((eq op :copy)
       (a64-load-operand (ins-arg0 i) cls :a fr stream)
       (a64-store-a (ins-to i) cls fr stream))
      ((eq op :neg)
       (a64-load-operand (ins-arg0 i) cls :a fr stream)
       (format stream "~aneg ~a, ~a~%" #\Tab (a64-r :a cls) (a64-r :a cls))
       (a64-store-a (ins-to i) cls fr stream))
      ((assoc op *a64-binop*)
       (a64-load-operand (ins-arg0 i) cls :a fr stream)
       (a64-load-operand (ins-arg1 i) cls :c fr stream)
       (format stream "~a~a ~a, ~a, ~a~%" #\Tab (cdr (assoc op *a64-binop*))
               (a64-r :a cls) (a64-r :a cls) (a64-r :c cls))
       (a64-store-a (ins-to i) cls fr stream))
      (cmp
       (destructuring-bind (cc . ocls) cmp
         (a64-load-operand (ins-arg0 i) ocls :a fr stream)
         (a64-load-operand (ins-arg1 i) ocls :c fr stream)
         (format stream "~acmp ~a, ~a~%" #\Tab (a64-r :a ocls) (a64-r :c ocls))
         (format stream "~acset ~a, ~a~%" #\Tab (a64-r :a cls) cc)
         (a64-store-a (ins-to i) cls fr stream)))
      ((assoc op *a64-load-info*)
       (destructuring-bind (mn . wide) (cdr (assoc op *a64-load-info*))
         (a64-load-operand (ins-arg0 i) :l :a fr stream)   ; pointer -> x9
         ;; dest reg width: ldrsw always -> x; :by-cls follows result class;
         ;; nil (zero-extending byte/half/word) -> w (writing w zeroes the top).
         (let ((dstw (cond ((eq wide t) :l) ((eq wide :by-cls) cls) (t :w))))
           (format stream "~a~a ~a, [~a]~%" #\Tab mn (a64-r :a dstw) (a64-r :a :l)))
         (a64-store-a (ins-to i) cls fr stream)))
      ((assoc op *a64-store-info*)
       (let ((mn (cdr (assoc op *a64-store-info*)))
             (vcls (if (eq op :storel) :l :w)))
         (a64-load-operand (ins-arg1 i) :l :a fr stream)   ; pointer -> x9
         (a64-load-operand (ins-arg0 i) vcls :c fr stream) ; value  -> w10/x10
         (format stream "~a~a ~a, [~a]~%" #\Tab mn (a64-r :c vcls) (a64-r :a :l))))
      ((member op '(:alloc4 :alloc8 :alloc16))
       (format stream "~aadd ~a, x29, #~d~%" #\Tab (a64-r :a :l)
               (gethash i (a64frame-allocs fr)))
       (a64-store-a (ins-to i) :l fr stream))
      (t (error "arm64: unsupported op ~s" op)))))

;;; ------------------------------------------------------------ phi lowering

(defun a64-emit-edge (pred succ fr stream)
  "Move each phi in SUCC's PRED-argument into the phi's slot (2-phase, safe
against parallel-copy hazards -- via staging slots, same as amd64.lisp)."
  (let ((phis (blk-phis succ)) (staging (a64frame-staging fr)))
    (loop for p in phis for i from 0 do
      (let ((src (cdr (assoc pred (phi-args p)))) (cls (m1a-class (phi-cls p))))
        (a64-load-operand src cls :a fr stream)
        (format stream "~astr ~a, [x29, #~d]~%" #\Tab (a64-r :a cls) (aref staging i))))
    (loop for p in phis for i from 0 do
      (let ((cls (m1a-class (phi-cls p))))
        (format stream "~aldr ~a, [x29, #~d]~%" #\Tab (a64-r :a cls) (aref staging i))
        (a64-store-a (phi-to p) cls fr stream)))))

;;; ------------------------------------------------------------ function

(defun a64-emit-fn (fn stream &optional (fnid 0))
  (let* ((fr (a64-layout-frame fn))
         (name (concatenate 'string "_" (fn-name fn)))
         (blocks (fn-blocks fn))
         (blk-labels (let ((h (make-hash-table :test 'eq)))
                       (loop for b in blocks for k from 0
                             do (setf (gethash b h) (format nil "L~d_~d" fnid k)))
                       h))
         (pc (list 0))
         (fsize (a64frame-size fr)))
    (flet ((lbl (b) (gethash b blk-labels)))
      (format stream "~a.text~%~a.balign 4~%~a.globl ~a~%~a:~%"
              #\Tab #\Tab #\Tab name name)
      ;; prologue: BTI hint, save fp/lr, set up x29, then reserve locals
      (format stream "~ahint #34~%~astp x29, x30, [sp, #-16]!~%~amov x29, sp~%"
              #\Tab #\Tab #\Tab)
      (unless (zerop fsize)
        (format stream "~asub sp, sp, #~d~%" #\Tab fsize))
      (loop for (b . rest) on blocks
            for next = (car rest) do
        (format stream "~a:~%" (lbl b))
        (dolist (i (blk-ins b)) (a64-emit-ins i fr pc stream))
        (let ((jt (blk-jmp-type b)))
          (flet ((epilogue ()
                   (unless (zerop fsize) (format stream "~amov sp, x29~%" #\Tab))
                   (format stream "~aldp x29, x30, [sp], #16~%~aret~%" #\Tab #\Tab)))
            (case jt
              (:ret0 (epilogue))
              ((:retw :retl)
               (a64-load-operand (blk-jmp-arg b) (if (eq jt :retw) :w :l) :a fr stream)
               (let ((cls (if (eq jt :retw) :w :l)))
                 (format stream "~amov ~a0, ~a~%" #\Tab (if (eq cls :l) "x" "w")
                         (a64-r :a cls)))
               (epilogue))
              (:jmp
               (a64-emit-edge b (blk-s1 b) fr stream)
               (unless (eq (blk-s1 b) next)
                 (format stream "~ab ~a~%" #\Tab (lbl (blk-s1 b)))))
              (:jnz
               (let ((else (format nil "L~d_~de" fnid (position b blocks))))
                 (a64-load-operand (blk-jmp-arg b) :w :a fr stream)
                 (format stream "~acbz ~a, ~a~%" #\Tab (a64-r :a :w) else)
                 (a64-emit-edge b (blk-s1 b) fr stream)
                 (format stream "~ab ~a~%~a:~%" #\Tab (lbl (blk-s1 b)) else)
                 (a64-emit-edge b (blk-s2 b) fr stream)
                 (format stream "~ab ~a~%" #\Tab (lbl (blk-s2 b)))))
              (t (error "arm64: unsupported terminator ~s" jt))))))
      (format stream "/* end function ~a */~%~%" (fn-name fn)))))
