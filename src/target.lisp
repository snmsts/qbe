;;;; target.lisp --- per-target model (QBE's `Target` struct), CL edition.
;;;;
;;;; QBE keeps everything a target-specific about the machine in a single
;;;; `Target` struct (all.h): register counts and ids, the reserved-register
;;;; mask, the caller/callee-save sets, and function pointers for the per-target
;;;; passes (abi0/abi1/isel/emitfn/emitfin) and RCall-mask decoders
;;;; (retregs/argregs/memargs).  `func()` in main.c dispatches through it.
;;;;
;;;; We mirror that 1:1: a `defstruct target` with data slots + function-valued
;;;; slots (NOT a CLOS class hierarchy -- QBE's design is a struct of function
;;;; pointers, and a struct with funcallable slots is the lighter idiomatic
;;;; match while keeping source-correspondence with targ.c).  The generic
;;;; backend passes (spill / rega / be-fill-live / fill-cost) read the register
;;;; model through the thin `tg-*` accessors below instead of amd64 globals, so
;;;; the same passes serve every target once *target* is bound.
;;;;
;;;; What stays SHARED (not per-target): +tmp0+ (=NBit=64, the reg/temp id
;;;; boundary, identical on every target), kwide, materialize-regs, ref<->id.
;;;;
;;;; The concrete instances (*amd64-target* etc.) are built in each target's
;;;; targ file, after its register spec / rsave / passes exist -- exactly as
;;;; QBE builds T_amd64 in amd64/targ.c after the rest of the backend.

(in-package #:qbe)

;;; ------------------------------------------------------------------ boundary
;;; NBit / Tmp0: register ids occupy [0,+tmp0+); user temps start at +tmp0+.
;;; Shared by every target (QBE: MAKESURE(reg < Tmp0) on each arch).
(defconstant +tmp0+ 64 "NBit: first user-temp id; regs occupy [0,+tmp0+).")

;;; ------------------------------------------------------------------- struct
(defstruct target
  ;; --- identity / asm dialect ---
  name                 ; "amd64_sysv" | "arm64_apple" | ...
  apple                ; boolean: Apple (mach-o) conventions in abi0/emit
  asloc                ; local-label prefix (".L" elf / "L" apple)
  assym                ; symbol prefix ("" elf / "_" apple)
  ;; --- register model (data; QBE Target.{gpr0,ngpr,fpr0,nfpr,rglob,...}) ---
  gpr0 ngpr            ; first GP register id, count
  fpr0 nfpr            ; first FP register id, count
  rglob nrglob         ; reserved-register bitmask (never spilled), count
  rsave nrsave         ; caller-save order (vector) / #(ngps nfps)
  rclob                ; callee-save registers (vector)
  rsave-mask           ; derived: bitmask of all rsave registers
  regs                 ; vector: register id -> reg struct
  ;; --- per-target passes (QBE Target function pointers) ---
  abi0 abi1 isel emitfn emitfin
  ;; --- RCall-mask decoders + misc (QBE Target.{retregs,argregs,memargs}) ---
  retregs argregs      ; (mask) -> (values reg-id-list ngp nfp)
  memargs              ; (op)   -> how many operands may stay memory (0..2)
  cansel)              ; if-conversion enabled for this target?

;;; The active target.  Bound (usually let-bound per compile) by the driver.
(defvar *target*)

;;; ---------------------------------------------------------- thin accessors
;;; The backend passes read the register model through these instead of amd64
;;; globals.  Kept as trivial inline readers so the spill/rega diff is minimal
;;; and every reference obviously routes through *target*.
(declaim (inline tg-gpr0 tg-ngpr tg-fpr0 tg-nfpr tg-rglob tg-nrglob
                 tg-rsave tg-nrsave tg-rclob tg-rsave-mask))
(defun tg-gpr0 () (target-gpr0 *target*))
(defun tg-ngpr () (target-ngpr *target*))
(defun tg-fpr0 () (target-fpr0 *target*))
(defun tg-nfpr () (target-nfpr *target*))
(defun tg-rglob () (target-rglob *target*))
(defun tg-nrglob () (target-nrglob *target*))
(defun tg-rsave () (target-rsave *target*))
(defun tg-nrsave () (target-nrsave *target*))
(defun tg-rclob () (target-rclob *target*))
(defun tg-rsave-mask () (target-rsave-mask *target*))

(defun tg-apple () (target-apple *target*))
(defun tg-asloc () (target-asloc *target*))

(defun tg-rg (id) (aref (target-regs *target*) id))
(defun tg-retregs (mask) (funcall (target-retregs *target*) mask))
(defun tg-argregs (mask) (funcall (target-argregs *target*) mask))
(defun tg-memargs (op) (funcall (target-memargs *target*) op))

(defun reg-fp-p (id)
  "Is register id ID a floating-point register on the current target?"
  (and (<= (tg-fpr0) id) (< id (+ (tg-fpr0) (tg-nfpr)))))

;;; KWIDE (Kl/Kd occupy 8 bytes) is target-independent; it is defined once in
;;; gvn.lisp (cls-code variant) and used across the mid-end and backend.
