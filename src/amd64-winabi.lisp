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
