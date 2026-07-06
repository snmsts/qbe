;;;; amd64-abi.lisp --- amd64 SysV ABI lowering (M3 / B1), mirrors amd64/sysv.c
;;;;
;;;; abi1 = amd64_sysv_abi: lower params (par -> copy from arg register),
;;;; returns (ret<k> -> copy to RAX/XMM0 + ret0 with a live-return mask), and
;;;; calls.  This B1 slice covers the scalar integer/float path: <=6 integer
;;;; and <=8 sse register params, scalar/void returns, call-free functions.
;;;; Struct params/returns, stack (inmem) params, varargs, env, and calls are
;;;; out of scope and signal an error rather than miscompile (as in M1).
;;;;
;;;; QBE's backend emits instructions *backward* into a scratch buffer via
;;;; `emit`.  We reproduce it exactly by pushing onto a list in QBE's loop
;;;; order: same order of emit()/process => same final instruction order.
;;;;
;;;; Oracle: `qbe -dA`'s "> After ABI lowering:" printfn dump, on the subset
;;;; where the (still-unimplemented) mid-end opts are no-ops.

(in-package #:qbe)

;;; ------------------------------------------------------- register model
;;; QBE amd64 register ids (amd64/all.h): RXX=0, then:
(defparameter *amd64-reg-spec*
  '((1 . "rax") (2 . "rcx") (3 . "rdx") (4 . "rsi") (5 . "rdi")
    (6 . "r8") (7 . "r9") (8 . "r10") (9 . "r11")
    (10 . "rbx") (11 . "r12") (12 . "r13") (13 . "r14") (14 . "r15")
    (15 . "rbp") (16 . "rsp")
    (17 . "xmm0") (18 . "xmm1") (19 . "xmm2") (20 . "xmm3") (21 . "xmm4")
    (22 . "xmm5") (23 . "xmm6") (24 . "xmm7") (25 . "xmm8") (26 . "xmm9")
    (27 . "xmm10") (28 . "xmm11") (29 . "xmm12") (30 . "xmm13")
    (31 . "xmm14") (32 . "xmm15")))

(defparameter *amd64-regs*
  (let ((v (make-array 33 :initial-element nil)))
    (loop for (id . name) in *amd64-reg-spec*
          do (setf (aref v id) (make-reg id name (if (>= id 17) :d :l))))
    v)
  "Vector: QBE register id -> reg object.")

(defun rg (id) (aref *amd64-regs* id))

(defconstant +rax+ 1) (defconstant +xmm0+ 17)

;;; rarg register sequence (amd64_sysv_rsave), integer part then sse.
(defparameter *sysv-int-args* #(5 4 3 2 6 7))   ; RDI RSI RDX RCX R8 R9
(defparameter *sysv-nint* 6)
(defparameter *sysv-nsse* 8)

(defun cls-base (k) (if (member k '(:w :l)) 0 1))  ; KBASE

;;; ------------------------------------------------------------ emission
;;; A tiny backward-emit reproduction: EMIT pushes onto *emitted*, so
;;; iterating in QBE's order yields QBE's final instruction order.
(defvar *emitted* nil)

(defun emit (op cls to a0 a1)
  (push (make-instance 'ins :op op :cls cls :to to :arg0 a0 :arg1 a1) *emitted*))

;;; ---------------------------------------------------------------- abi1

(defun abi-unsupported (what)
  (error "qbe amd64 abi (M3/B1): unsupported ~a" what))

(defun sel-par (fn)
  "Lower the leading `par` instructions of the start block into copies from
argument registers.  Returns the list of copy instructions, in order."
  (let ((*emitted* nil) (ni 0) (ns 0) (pars '()))
    ;; collect leading par instructions
    (dolist (i (blk-ins (fn-start fn)))
      (if (member (ins-op i) '(:par :parc :pare :parsb :parub :parsh :paruh))
          (push i pars)
          (return)))
    (setf pars (nreverse pars))
    (dolist (i pars)
      (case (ins-op i)
        (:par
         (if (= (cls-base (ins-cls i)) 0)
             (if (< ni *sysv-nint*)
                 (emit :copy (ins-cls i) (ins-to i) (rg (aref *sysv-int-args* ni)) nil)
                 (abi-unsupported "stack (inmem) integer parameter"))
             (if (< ns *sysv-nsse*)
                 (emit :copy (ins-cls i) (ins-to i) (rg (+ +xmm0+ ns)) nil)
                 (abi-unsupported "stack (inmem) sse parameter")))
         (if (= (cls-base (ins-cls i)) 0) (incf ni) (incf ns)))
        (:pare (abi-unsupported "env parameter"))
        (t (abi-unsupported "sub-word or aggregate parameter"))))
    ;; *emitted* read left-to-right already equals QBE's forward emit order
    ;; (push == QBE's prepend-at-\-\-curi), so no reversal.
    *emitted*))

(defun sel-ret (b fn)
  "Lower B's return terminator, emitting the return-register copy and setting
the ret0 mask.  Pushes onto *emitted* (called first, so copies land last)."
  (declare (ignore fn))
  (let ((jt (blk-jmp-type b)))
    (when (and (member jt '(:retw :retl :rets :retd :retsb :retub :retsh :retuh :retc))
               (not (eq jt :ret0)))
      (let ((r0 (blk-jmp-arg b)))
        (setf (blk-jmp-type b) :ret0)
        (case jt
          (:retc (abi-unsupported "aggregate return"))
          ((:retsb :retub :retsh :retuh) (abi-unsupported "sub-word return"))
          (t
           (let ((k (ecase jt (:retw :w) (:retl :l) (:rets :s) (:retd :d))))
             (if (= (cls-base k) 0)
                 (progn (emit :copy k (rg +rax+) r0 nil)
                        (setf (blk-jmp-arg b) (make-call-ref 1)))
                 (progn (emit :copy k (rg +xmm0+) r0 nil)
                        (setf (blk-jmp-arg b) (make-call-ref (ash 1 2))))))))))))

;;; -------------------------------------------------------------- calls
;;; amd64/sysv.c selcall + argsclass + rarg, scalar path: register-passed
;;; integer/sse args (<=6 int, <=8 sse), scalar/void return.  Struct args/
;;; returns, stack-passed (overflow) args, env, and varargs are unsupported.

(defun argsclass-scalar (args)
  "Classify scalar call ARGS; return (values ca inmem-flags).  CA is the
argsclass mask (passed-reg counts), inmem-flags a per-arg list (0=reg, 2=stack)."
  (let ((nint *sysv-nint*) (nsse *sysv-nsse*) (ac '()))
    (dolist (i args)
      (unless (eq (ins-op i) :arg)
        (abi-unsupported "aggregate/env/vararg call argument"))
      (if (= (cls-base (ins-cls i)) 0)
          (if (> nint 0) (progn (decf nint) (push 0 ac)) (push 2 ac))
          (if (> nsse 0) (progn (decf nsse) (push 0 ac)) (push 2 ac))))
    (values (logior (ash (- *sysv-nint* nint) 4) (ash (- *sysv-nsse* nsse) 8))
            (nreverse ac))))

(defun sel-call (fn args call)
  "Lower a scalar CALL (with ARGS the preceding arg instructions), emitting the
arg-register copies, the call, and the result copy (amd64/sysv.c selcall)."
  (declare (ignore fn))
  (unless (null (ins-arg1 call)) (abi-unsupported "aggregate (struct) return"))
  (multiple-value-bind (ca ac) (argsclass-scalar args)
    (when (member 2 ac) (abi-unsupported "stack (inmem) call argument"))
    ;; result register copy (emitted first, so it lands after the call)
    (let ((cls (ins-cls call)))
      (if (= (cls-base cls) 0)
          (progn (emit :copy cls (ins-to call) (rg +rax+) nil) (incf ca 1))
          (progn (emit :copy cls (ins-to call) (rg +xmm0+) nil) (incf ca (ash 1 2)))))
    ;; the call itself
    (emit :call (ins-cls call) nil (ins-arg0 call) (make-call-ref ca))
    ;; argument register copies, in source order (rarg register sequence)
    (let ((ni 0) (ns 0))
      (dolist (i args)
        (if (= (cls-base (ins-cls i)) 0)
            (progn (emit :copy (ins-cls i) (rg (aref *sysv-int-args* ni)) (ins-arg0 i) nil)
                   (incf ni))
            (progn (emit :copy (ins-cls i) (rg (+ +xmm0+ ns)) (ins-arg0 i) nil)
                   (incf ns)))))))

(defun amd64-abi (fn)
  "amd64 SysV abi1 (B2 scalar + calls).  Rewrites FN in place."
  ;; 1. lower parameters: splice the arg-register copies before the rest.
  (let* ((start (fn-start fn))
         (par-copies (sel-par fn))
         (rest (member-if-not
                (lambda (i) (member (ins-op i)
                                    '(:par :parc :pare :parsb :parub :parsh :paruh)))
                (blk-ins start))))
    (setf (blk-ins start) (append par-copies rest)))
  ;; 2. lower returns and calls per block (backward, mirroring the emit buffer).
  (dolist (b (fn-blocks fn))
    (let ((*emitted* nil)
          (vec (coerce (blk-ins b) 'vector)))
      (sel-ret b fn)
      (loop with k = (length vec) while (> k 0) do
        (decf k)
        (let ((i (aref vec k)))
          (cond
            ((eq (ins-op i) :call)
             (let ((i0 k))
               (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0)))))
                     do (decf i0))
               (sel-call fn (coerce (subseq vec i0 k) 'list) i)
               (setf k i0)))
            ((member (ins-op i) '(:vastart :vaarg))
             (abi-unsupported "vararg instruction"))
            (t (push i *emitted*)))))
      (setf (blk-ins b) *emitted*))))
