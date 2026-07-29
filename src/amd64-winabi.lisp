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
