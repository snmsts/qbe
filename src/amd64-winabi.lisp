;;;; amd64-winabi.lisp --- the Microsoft x64 ABI (QBE amd64/winabi.c).
;;;;
;;;; The SysV twin lives in amd64-abi.lisp (QBE amd64/sysv.c).  Both share the
;;;; register *model* defined there (ids, *amd64-regs*, memargs); what differs
;;;; is which registers carry arguments and how aggregates are passed:
;;;;
;;;;   SysV                                  Windows x64
;;;;   RDI RSI RDX RCX R8 R9  (6 int)        RCX RDX R8 R9        (4 int)
;;;;   XMM0..XMM7             (8 sse)        XMM0..XMM3           (4 sse)
;;;;   int and sse counted separately        ONE shared counter: the 3rd
;;;;                                         argument is R8 *or* XMM2
;;;;   aggregates classified into            anything not 1/2/4/8 bytes is
;;;;   INTEGER/SSE eightbytes                copied and passed BY POINTER
;;;;   RBX RBP R12-R15 callee-save           + RSI RDI callee-save
;;;;   red zone                              none; 32 bytes of shadow space
;;;;                                         reserved by the caller
;;;;
;;;; Ported 1:1 from amd64/winabi.c, same as the rest of the backend: the
;;;; upstream file is the oracle, and `qbe -t amd64_win` gives byte-comparable
;;;; output to diff against.

(in-package #:qbe)

;;; ------------------------------------------------------- register model
;;; amd64_winabi_rsave / amd64_winabi_rclob (winabi.c).
;;; NGPS_WIN = NGPS_SYSV - 2 and NCLR_WIN = NCLR_SYSV + 2: RSI and RDI move
;;; from caller-save to callee-save on Windows.  That single difference is why
;;; the SysV rsave vector cannot be reused.
(defconstant +ngps-win+ 7)   ; RCX RDX R8 R9 R10 R11 RAX
(defconstant +nclr-win+ 7)   ; RBX R12 R13 R14 R15 RSI RDI

(defparameter *winabi-rsave*
  (coerce (append (list +rcx+ +rdx+ +r8+ +r9+ +r10+ +r11+ +rax+)
                  (loop for i below +amd64-nfpr+ collect (+ +xmm0+ i)))
          'vector)
  "Caller-save order (amd64_winabi_rsave): gp then sse.")

(defparameter *winabi-nrsave* (vector +ngps-win+ +amd64-nfpr+)
  "{NGPS_WIN, NFPS} -- the two counts nrsave feeds.")

(defparameter *winabi-rclob*
  (vector +rbx+ +r12+ +r13+ +r14+ +r15+ +rsi+ +rdi+)
  "Callee-save (amd64_winabi_rclob).  RSI/RDI are callee-save here.")

(defparameter *winabi-rsave-mask*
  (reduce (lambda (m id) (logior m (ash 1 id))) *winabi-rsave* :initial-value 0))

;;; The four argument registers, in calling-convention order, indexed by the
;;; SHARED counter (winabi.c register_for_arg).  Index 2 is R8 for an integer
;;; and XMM2 for a float -- the position is what matters, not how many of each
;;; came before.
(defparameter *winabi-int-args* (vector +rcx+ +rdx+ +r8+ +r9+))
(defparameter *winabi-sse-args*
  (vector +xmm0+ (+ +xmm0+ 1) (+ +xmm0+ 2) (+ +xmm0+ 3)))
(defconstant +winabi-nargregs+ 4)

;;; Stack bytes the caller must reserve for the callee to spill its four
;;; register arguments into.  Present even when no arguments are passed.
(defconstant +shadow-space-size+ 32)

;;; ------------------------------------------------- RCall mask decoders
;;; Layout of a call's second argument (winabi.c, above amd64_winabi_retregs):
;;;
;;;   bit 0        rax returned
;;;   bit 1        xmm0 returned
;;;   bits 2-3     0
;;;   bits 4-7     rcx, rdx, r8, r9 passed
;;;   bits 8-11    xmm0, xmm1, xmm2, xmm3 passed
;;;   bit 12       env call (rax passed)
;;;
;;; Note this is a *bitmap* of which registers are in use, not a count as on
;;; SysV -- on Windows the used registers need not be contiguous (a call taking
;;; (int, double) uses RCX and XMM1, skipping RDX and XMM0).

(defun amd64-winabi-retregs (mask)
  "QBE amd64_winabi_retregs.  Returns (values reg-id-list ngp nfp)."
  (let ((ni (logand mask 1))
        ;; Mirrors upstream exactly: `r.val & 2`, so this is 0 or 2, not 0/1.
        (nf (logand mask 2)))
    (values (list (if (= ni 1) +rax+ +xmm0+)) ni nf)))

(defun logcount* (n) (logcount n))

(defun amd64-winabi-argregs (mask)
  "QBE amd64_winabi_argregs.  Returns (values reg-id-list ngp nfp)."
  (let ((int-passed   (logand (ash mask -4) 15))
        (float-passed (logand (ash mask -8) 15))
        (env-param    (logand (ash mask -12) 1))
        (regs '()))
    (dotimes (j +winabi-nargregs+)
      (when (logbitp j int-passed)   (push (aref *winabi-int-args* j) regs))
      (when (logbitp j float-passed) (push (aref *winabi-sse-args* j) regs)))
    (when (= env-param 1) (push +rax+ regs))
    ;; Upstream returns popcounts here with a TODO: the counts feed live.c only,
    ;; and on Windows the registers are not contiguous, so a count is already an
    ;; approximation.  Keep the same approximation to stay byte-comparable.
    (values regs (logcount int-passed) (logcount float-passed))))

;;; --------------------------------------------------- argument classification
;;; winabi.c ArgPassStyle / ArgClass / RegisterUsage / classify_arguments.
;;;
;;; This is where the Windows semantics actually live; the lowering below is
;;; plumbing.  Two rules do all the work:
;;;
;;;   1. ONE counter.  int and float arguments advance the same counter, so the
;;;      register is chosen by *position*: argument 2 is R8 or XMM2.  (SysV has
;;;      two independent counters, so f(int,double) is RDI+XMM0 there and
;;;      RCX+XMM1 here.)
;;;   2. Anything not exactly 1, 2, 4 or 8 bytes is passed BY POINTER to a
;;;      caller-made copy -- not spread over the stack.  A 5-byte struct would
;;;      "fit" in a register but is still copied.

(defstruct (warg (:constructor make-warg))
  type
  (style :invalid)   ; :register :inline-on-stack :copy-and-pointer-in-register
                     ; :copy-and-pointer-on-stack :varargs-tag :env-tag
  (align 0) (size 0) (cls :l) ref)

(defstruct (wusage (:constructor make-wusage))
  (num-regs-passed 0)
  ;; [int|float][0..3]: is that argument register actually carrying a value?
  (regs-passed (make-array '(2 4) :initial-element nil))
  (rax-returned nil) (xmm0-returned nil)
  ;; also where va_start begins for a varargs function
  (num-named-args-passed 0)
  (is-varargs-call nil)
  (has-env nil))

(defun winabi-call-arg-value (u)
  "winabi.c register_usage_to_call_arg_value: pack a RegisterUsage into RCall."
  (let ((rp (wusage-regs-passed u)))
    (flet ((bit-at (k i n) (if (aref rp k i) (ash 1 n) 0)))
      (logior (if (wusage-rax-returned u) 1 0)
              (if (wusage-xmm0-returned u) 2 0)
              (bit-at 0 0 4) (bit-at 0 1 5) (bit-at 0 2 6) (bit-at 0 3 7)
              (bit-at 1 0 8) (bit-at 1 1 9) (bit-at 1 2 10) (bit-at 1 3 11)
              (if (wusage-has-env u) (ash 1 12) 0)))))

(defun winabi-assign (u arg is-float by-copy)
  "winabi.c assign_register_or_stack."
  (if (= (wusage-num-regs-passed u) +winabi-nargregs+)
      (setf (warg-style arg)
            (if by-copy :copy-and-pointer-on-stack :inline-on-stack))
      (progn
        (setf (aref (wusage-regs-passed u) (if is-float 1 0)
                    (wusage-num-regs-passed u))
              t)
        (incf (wusage-num-regs-passed u))
        (setf (warg-style arg)
              (if by-copy :copy-and-pointer-in-register :register))))
  (incf (wusage-num-named-args-passed u))
  arg)

(defun winabi-by-copy-p (ty)
  "winabi.c type_is_by_copy.  Only 1/2/4/8 go in a register; 5 does not."
  (let ((sz (typ-size ty)))
    (or (typ-isdark ty) (not (member sz '(1 2 4 8))))))

(defun winabi-reg-for-arg (cls counter)
  "winabi.c register_for_arg: position picks the register, class picks the bank."
  (rg (if (= (cls-base cls) 0)
          (aref *winabi-int-args* counter)
          (aref *winabi-sse-args* counter))))

(defun winabi-classify (u args)
  "winabi.c classify_arguments.  ARGS is the arg/par ins list (source order).
Returns (values warg-vector env-ref)."
  (let ((acs (make-array (length args))) (env nil))
    (loop for i in args for idx from 0 do
      (let ((a (make-warg)) (op (ins-op i)))
        (setf (aref acs idx) a)
        (case op
          ((:arg :par)
           (winabi-assign u a (= 1 (cls-base (ins-cls i))) nil)
           (setf (warg-cls a) (ins-cls i) (warg-align a) 3 (warg-size a) 8))
          ((:argc :parc)
           (let* ((ty (ins-arg0 i)) (by-copy (winabi-by-copy-p ty)))
             (winabi-assign u a nil by-copy)
             (setf (warg-cls a) (if (and (not by-copy) (<= (typ-size ty) 4)) :w :l)
                   (warg-align a) 3
                   (warg-size a) (typ-size ty)
                   (warg-type a) ty)))
          (:arge (setf env (ins-arg0 i) (warg-style a) :env-tag
                       (wusage-has-env u) t))
          (:pare (setf env (ins-to i)   (warg-style a) :env-tag
                       (wusage-has-env u) t))
          (:argv (setf (wusage-is-varargs-call u) t (warg-style a) :varargs-tag))
          ;; QBE's winabi.c switch has no case for the subword pars; they would
          ;; leave the style Invalid and die further down.  Refuse here instead,
          ;; where the message can say what happened (the backend's rule is to
          ;; raise rather than miscompile).
          (t (abi-unsupported (format nil "win abi arg/par op ~a" op))))))
    (when (and (wusage-has-env u) (wusage-is-varargs-call u))
      (abi-unsupported "env with varargs"))
    ;; A varargs call must ALSO put float arguments in the matching integer
    ;; register, so the callee can spill them to shadow space without a
    ;; prototype.  Mark those integer registers as in use.
    (when (wusage-is-varargs-call u)
      (dotimes (i +winabi-nargregs+)
        (when (aref (wusage-regs-passed u) 1 i)
          (setf (aref (wusage-regs-passed u) 0 i) t))))
    (values acs env)))

;;; -------------------------------------------------------------- lowering
;;; winabi.c lower_call / lower_block_return / lower_vastart / lower_vaarg /
;;; lower_func_parameters / amd64_winabi_abi.
;;;
;;; Structural note: winabi.c is not a fork of sysv.c but an independent
;;; rewrite, so the function boundaries do not line up with amd64-abi.lisp's
;;; sel-call / sel-par / sel-ret.  Each upstream function is transcribed as-is
;;; rather than folded into the SysV shape -- the oracle is a byte diff of the
;;; `-dA` dump, so matching the structure is what makes a mismatch readable.
;;;
;;; As everywhere in the backend, QBE emits instructions *backward*: `emit`
;;; pushes onto *emitted*, so writing the emits in upstream's order reproduces
;;; upstream's final order.

(defvar *win-extra-alloc* nil
  "winabi.c ExtraAlloc list: allocas requested by other blocks, to be hoisted
into the start block.  Pushed at the head, exactly like upstream's linked list,
so replaying it with PUSH onto *emitted* lands the oldest first.")

(defun win-push-extra-alloc (ins)
  (push ins *win-extra-alloc*)
  ins)

(defun win-alloc8 (to size fn)
  (make-instance 'ins :op :alloc8 :cls :l :to to :arg0 (getcon size fn) :arg1 nil))

(defun align-up (n a) (logand (+ n a -1) (- a)))

(defun win-lower-call (fn args call)
  "winabi.c lower_call.  ARGS is the arg ins run preceding CALL, source order."
  (let* ((argv (coerce args 'vector))
         (num-args (length argv))
         (u (make-wusage))
         (ret-size 0)
         (il-has-struct-return (and (ins-arg1 call) t))
         (is-struct-return nil))
    ;; Ocall's arg[1] is the return type when the function returns an aggregate.
    (when il-has-struct-return
      (let ((rt (ins-arg1 call)))
        (setf is-struct-return (winabi-by-copy-p rt))
        (when is-struct-return
          (winabi-assign u (make-warg) nil t))
        (setf ret-size (typ-size rt))))
    (multiple-value-bind (acs env) (winabi-classify u args)
      ;; Stack bytes for whatever did not fit in the four argument registers.
      ;; Aggregates copied by pointer are alloca'd separately and contribute
      ;; only their 8-byte pointer here.
      (let ((stack-usage 0))
        (dotimes (idx num-args)
          (let ((a (aref acs idx)))
            (case (warg-style a)
              (:inline-on-stack
               (when (> (warg-align a) 4) (abi-unsupported "alignment > 16"))
               (incf stack-usage (warg-size a)))
              (:copy-and-pointer-on-stack (incf stack-usage 8)))))
        (setf stack-usage (align-up stack-usage 16))
        ;; We are logically *after* the call here (emission is backward), so
        ;; this negative salloc is the post-call cleanup.
        (emit :salloc :l nil (getcon (- (+ stack-usage +shadow-space-size+)) fn) nil)
        (let ((return-pad nil))
          (cond
            (is-struct-return
             (setf return-pad
                   (win-push-extra-alloc
                    (win-alloc8 (newtmp "abi.ret_pad" :l fn) ret-size fn)))
             (setf (wusage-rax-returned u) t)
             (emit :copy (ins-cls call) (ins-to call) (rg +rax+) nil))
            (il-has-struct-return
             ;; The IL says "struct return" but the calling convention does not
             ;; pass it by pointer.  Later IL still treats the result as a
             ;; pointer, so store the returned value into an alloca.
             (win-push-extra-alloc (win-alloc8 (ins-to call) 8 fn))
             (let ((copy (newtmp "abi.copy" :l fn)))
               (emit :storel :w nil copy (ins-to call))
               (emit :copy :l copy (rg +rax+) nil))
             (setf (wusage-rax-returned u) t))
            ((= 0 (cls-base (ins-cls call)))
             (emit :copy (ins-cls call) (ins-to call) (rg +rax+) nil)
             (setf (wusage-rax-returned u) t))
            (t
             (emit :copy (ins-cls call) (ins-to call) (rg +xmm0+) nil)
             (setf (wusage-xmm0-returned u) t)))
          ;; The call itself: no `to` left (it is register traffic now), arg0 is
          ;; the callee and arg1 the RCall register-usage mask.
          (emit :call (ins-cls call) nil (ins-arg0 call)
                (make-call-ref (winabi-call-arg-value u)))
          (when env
            (emit :copy :l (rg +rax+) env nil))
          ;; A variadic call duplicates float arguments into the matching
          ;; integer register so the callee can spill without a prototype.
          (when (wusage-is-varargs-call u)
            (loop for idx from 0 below +winabi-nargregs+
                  when (aref (wusage-regs-passed u) 1 idx)
                    do (emit :cast :l (rg (aref *winabi-int-args* idx))
                             (rg (aref *winabi-sse-args* idx)) nil)))
          (let ((reg-counter 0))
            (when is-struct-return
              (emit :copy :l (winabi-reg-for-arg :l reg-counter) (ins-to return-pad) nil)
              (incf reg-counter))
            ;; Now the values themselves, into registers or stack slots.
            (let ((arg-stack-slots (newtmp "abi.args" :l fn))
                  (slot-offset +shadow-space-size+))
              (dotimes (idx num-args)
                (let ((i (aref argv idx)) (a (aref acs idx)))
                  (ecase (warg-style a)
                    (:register
                     (let ((into (winabi-reg-for-arg (warg-cls a) reg-counter)))
                       (incf reg-counter)
                       (if (eq (ins-op i) :argc)
                           ;; A small aggregate by value: the instruction holds a
                           ;; pointer, the register wants the pointee.
                           (emit :load (warg-cls a) into (ins-arg1 i) nil)
                           (emit :copy (ins-cls i) into (ins-arg0 i) nil))))
                    (:inline-on-stack
                     (let ((slot (newtmp "abi.off" :l fn)))
                       (if (eq (ins-op i) :argc)
                           ;; Small aggregate again -- load through the pointer,
                           ;; then store into the slot (emitted backward, so the
                           ;; store is written first).
                           (let ((smalltmp (newtmp "abi.smalltmp" (warg-cls a) fn)))
                             (emit :storel :w nil smalltmp slot)
                             (emit :load (warg-cls a) smalltmp (ins-arg1 i) nil))
                           (emit :storel :w nil (ins-arg0 i) slot))
                       (emit :add :l slot arg-stack-slots (getcon slot-offset fn))
                       (incf slot-offset (warg-size a))))
                    ((:copy-and-pointer-in-register :copy-and-pointer-on-stack)
                     ;; Alloca a copy and blit into it, then pass its address.
                     (let ((copy-ref (newtmp "abi.copy" :l fn)))
                       (win-push-extra-alloc (win-alloc8 copy-ref (warg-size a) fn))
                       (emit :blit1 :w nil (warg-size a) nil)
                       (emit :blit0 :w nil (ins-arg1 i) copy-ref)
                       (if (eq (warg-style a) :copy-and-pointer-in-register)
                           (let ((into (winabi-reg-for-arg (warg-cls a) reg-counter)))
                             (incf reg-counter)
                             (emit :copy :l into copy-ref nil))
                           (let ((slot (newtmp "abi.off" :l fn)))
                             (emit :storel :w nil copy-ref slot)
                             (emit :add :l slot arg-stack-slots (getcon slot-offset fn))
                             (incf slot-offset 8)))))
                    ;; Handled at the call site above (env copy / vararg dupes).
                    ((:env-tag :varargs-tag) nil))))
              (if (/= 0 stack-usage)
                  ;; Last thing in emission order = first in call order: reserve
                  ;; the scratch area the slots above were carved out of.
                  (emit :salloc :l arg-stack-slots
                        (getcon (+ stack-usage +shadow-space-size+) fn) nil)
                  ;; With no scratch there is nothing to name, but the shadow
                  ;; space still has to be reserved -- emitted without a `to` so
                  ;; later passes cannot drop it as useless.
                  (emit :salloc :l nil (getcon +shadow-space-size+ fn) nil)))))))))

(defun win-lower-block-return (fn b)
  "winabi.c lower_block_return."
  (let ((j (blk-jmp-type b)))
    (when (and (isret-jmp j) (not (eq j :ret0)))
      (let ((ret-arg (blk-jmp-arg b)) (u (make-wusage)))
        (setf (blk-jmp-type b) :ret0)
        (if (eq j :retc)
            (let ((ty (fn-rettyp fn)))
              (if (winabi-by-copy-p ty)
                  (progn
                    (emit :copy :l (rg +rax+) (fn-retr fn) nil)
                    (emit :blit1 :w nil (typ-size ty) nil)
                    (emit :blit0 :w nil ret-arg (fn-retr fn)))
                  (emit :load :l (rg +rax+) ret-arg nil))
              (setf (wusage-rax-returned u) t))
            (let ((k (ecase j (:retw :w) (:retl :l) (:rets :s) (:retd :d))))
              (if (= 0 (cls-base k))
                  (progn (emit :copy k (rg +rax+) ret-arg nil)
                         (setf (wusage-rax-returned u) t))
                  (progn (emit :copy k (rg +xmm0+) ret-arg nil)
                         (setf (wusage-xmm0-returned u) t)))))
        (setf (blk-jmp-arg b) (make-call-ref (winabi-call-arg-value u)))))))

(defun win-lower-vastart (fn param-usage valist)
  "winabi.c lower_vastart.  va_list is one pointer: the integer argument
registers are already spilled to shadow space (and float arguments duplicated
into them), and a varargs function always keeps an RBP frame, so `...` simply
starts past RBP by the number of named arguments actually passed."
  (unless (fn-vararg fn) (abi-unsupported "vastart in a non-variadic function"))
  (let ((offset (newtmp "abi.vastart" :l fn)))
    (emit :storel :w nil offset valist)
    ;; *8 for sizeof(u64); +16 because the return address and RBP are already
    ;; pushed by the time the body runs.
    (emit :add :l offset (rg +rbp+)
          (getcon (+ (* 8 (wusage-num-named-args-passed param-usage)) 16) fn))))

(defun win-lower-vaarg (fn i)
  "winabi.c lower_vaarg.  va_list is a void** here, so: load the pointer, load
the argument through it, bump the pointer.  (Emitted backward, as always.)"
  (let ((inc (newtmp "abi.vaarg.inc" :l fn))
        (ptr (newtmp "abi.vaarg.ptr" :l fn)))
    (emit :storel :w nil inc (ins-arg0 i))
    (emit :add :l inc ptr (getcon 8 fn))
    (emit :load (ins-cls i) (ins-to i) ptr nil)
    (emit :load :l ptr (ins-arg0 i) nil)))

(defun win-lower-args-for-block (fn b param-usage)
  "winabi.c lower_args_for_block."
  (let ((*emitted* nil) (vec (coerce (blk-ins b) 'vector)))
    (win-lower-block-return fn b)
    (loop with k = (length vec) while (> k 0) do
      (decf k)
      (let ((i (aref vec k)))
        (case (ins-op i)
          (:call
           (let ((i0 k))
             (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0)))))
                   do (decf i0))
             (win-lower-call fn (coerce (subseq vec i0 k) 'list) i)
             (setf k i0)))
          (:vastart (win-lower-vastart fn param-usage (ins-arg0 i)))
          (:vaarg   (win-lower-vaarg fn i))
          ((:arg :argc) (abi-unsupported "stray arg outside a call"))
          (t (push i *emitted*)))))
    ;; The start block is processed last, so the allocas the other blocks asked
    ;; for land at its head.
    (when (eq b (fn-start fn))
      (dolist (ea *win-extra-alloc*) (push ea *emitted*)))
    (setf (blk-ins b) *emitted*)))

(defun win-lower-func-parameters (fn)
  "winabi.c lower_func_parameters: copy registers/stack slots into the named
parameters.  Returns the RegisterUsage, which lower_vastart needs."
  (let* ((start (fn-start fn))
         (pars '()) (rest '()))
    (dolist (i (blk-ins start))
      (if (and (null rest) (ispar-op (ins-op i))) (push i pars) (push i rest)))
    (setf pars (nreverse pars) rest (nreverse rest))
    (let ((*emitted* nil) (u (make-wusage)) (reg-counter 0))
      ;; An aggregate return that the convention passes by pointer arrives in
      ;; RCX, ahead of every declared parameter.
      (when (and (fn-rettyp fn) (winabi-by-copy-p (fn-rettyp fn)))
        (winabi-assign u (make-warg) nil t)
        (let ((ret-ref (newtmp "abi.ret" :l fn)))
          (emit :copy :l ret-ref (rg +rcx+) nil)
          (setf (fn-retr fn) ret-ref)
          (incf reg-counter)))
      (multiple-value-bind (acs env) (winabi-classify u pars)
        (setf (fn-reg fn)
              (let ((m 0))
                (dolist (r (amd64-winabi-argregs (winabi-call-arg-value u)) m)
                  (setf m (logior m (ash 1 r))))))
        ;; SHADOW_SPACE_SIZE/4 + 4: slots are counted in 4-byte words, and the
        ;; incoming stack arguments sit just past the shadow space.
        (let ((slot-offset (+ (floor +shadow-space-size+ 4) 4)))
          (loop for i in pars for idx from 0 do
            (let ((a (aref acs idx)))
              (ecase (warg-style a)
                (:register
                 (let ((from (winabi-reg-for-arg (warg-cls a) reg-counter)))
                   (incf reg-counter)
                   ;; A struct at the IL level needs something to point at, so
                   ;; the register is spilled into an alloca (same below).
                   (if (eq (ins-op i) :parc)
                       (progn
                         (setf (warg-ref a) (newtmp "abi" :l fn))
                         (emit :storel :w nil (warg-ref a) (ins-to i))
                         (emit :copy (ins-cls i) (warg-ref a) from nil)
                         (emit :alloc8 :l (ins-to i) (getcon (warg-size a) fn) nil))
                       (emit :copy (ins-cls i) (ins-to i) from nil))))
                (:inline-on-stack
                 (if (eq (ins-op i) :parc)
                     (progn
                       (setf (warg-ref a) (newtmp "abi" :l fn))
                       (emit :storel :w nil (warg-ref a) (ins-to i))
                       (emit :copy (ins-cls i) (warg-ref a) (make-slot-ref (- slot-offset)) nil)
                       (emit :alloc8 :l (ins-to i) (getcon (warg-size a) fn) nil))
                     (emit :copy :l (ins-to i) (make-slot-ref (- slot-offset)) nil))
                 (incf slot-offset 2))
                (:copy-and-pointer-on-stack
                 (emit :load :l (ins-to i) (make-slot-ref (- slot-offset)) nil)
                 (incf slot-offset 2))
                (:copy-and-pointer-in-register
                 ;; The copy is ours, so the pointer register is the value.
                 (let ((from (winabi-reg-for-arg :l reg-counter)))
                   (incf reg-counter)
                   (emit :copy :l (ins-to i) from nil)))
                (:env-tag nil)))))
        ;; An env parameter arrives in RAX.
        (when env (emit :copy :l env (rg +rax+) nil)))
      (setf (blk-ins start) (append *emitted* rest))
      u)))

(defun amd64-winabi-abi (fn)
  "QBE amd64_winabi_abi: lower parameters, then returns/calls/varargs per block.
See the header comment of winabi.c for how the Microsoft convention differs
from SysV; the short version is four shared-counter argument registers and
by-pointer aggregates."
  (let ((*win-extra-alloc* nil))
    (let ((param-usage (win-lower-func-parameters fn)))
      ;; The start block goes last so the other blocks' allocas can be added to
      ;; it -- struct arguments and returns passed by value need those copies.
      (let* ((blocks (fn-blocks fn)) (start (car blocks)))
        (dolist (b (append (cdr blocks) (list start)))
          (win-lower-args-for-block fn b param-usage))))))
