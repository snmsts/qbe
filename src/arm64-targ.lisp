;;;; arm64-targ.lisp --- the arm64_apple target instance (mirrors arm64/targ.c).
;;;;
;;;; Built after the arm64 passes (arm64-abi / arm64-isel) so the function slots
;;;; can be filled.  The isel/abi tests bind *target* to *arm64-apple-target* so
;;;; tg-apple / tg-asloc and the register model resolve to arm64 (the default
;;;; *target* is amd64).  emit slots (emitfn/emitfin) are wired in G4.

(in-package #:qbe)

;;; ------------------------------------------------------- register-model ids
;;; arm64/all.h enum Arm64Reg (RXX=0): R0=1..R15=16, IP0=17, IP1=18, R18=19,
;;; R19=20..R28=29, FP=30, LR=31, SP=32, V0=33..V30=63.
(defconstant +a64-ip0+ 17) (defconstant +a64-ip1+ 18) (defconstant +a64-r18+ 19)
(defconstant +a64-fp+ 30) (defconstant +a64-lr+ 31)

;;; arm64/targ.c RGLOB = BIT(FP) | BIT(SP) | BIT(IP1) | BIT(R18)
(defparameter *arm64-rglob*
  (logior (ash 1 +a64-fp+) (ash 1 +a64-sp+) (ash 1 +a64-ip1+) (ash 1 +a64-r18+)))

;;; arm64/targ.c arm64_rsave / arm64_rclob (caller-save order / callee-save).
(defparameter *arm64-rsave*
  (coerce
   (append (loop for i from 0 to 15 collect (+ +a64-r0+ i))     ; R0..R15
           (list +a64-ip0+ +a64-ip1+ +a64-r18+ +a64-lr+)         ; IP0,IP1,R18,LR
           (loop for i from 0 to 7 collect (+ +a64-v0+ i))       ; V0..V7
           (loop for i from 16 to 30 collect (+ +a64-v0+ i)))    ; V16..V30
   'vector))
(defparameter *arm64-rclob*
  (coerce
   (append (loop for i from 19 to 28 collect (+ +a64-r0+ i))      ; R19..R28 (ids 20..29)
           (loop for i from 8 to 15 collect (+ +a64-v0+ i)))      ; V8..V15
   'vector))

;;; NGPS = (R18-R0+1) + 1 (LR) = 20; NFPS = (V7-V0+1)+(V30-V16+1) = 8+15 = 23.
(defparameter *arm64-nrsave* (vector 20 23))     ; {NGPS, NFPS}
(defparameter *arm64-rsave-mask*
  (reduce (lambda (m id) (logior m (ash 1 id))) *arm64-rsave* :initial-value 0))

(defun arm64-memargs (op) (declare (ignore op)) 0)   ; arm64/targ.c arm64_memargs

;;; ------------------------------------------------------------------ instance
(defparameter *arm64-apple-target*
  (make-target
   :name "arm64_apple"
   :apple t
   :asloc "L"
   :assym "_"
   :gpr0 +a64-r0+ :ngpr +a64-ngpr+
   :fpr0 +a64-v0+ :nfpr +a64-nfpr+
   :rglob *arm64-rglob* :nrglob 4
   :rsave *arm64-rsave* :nrsave *arm64-nrsave*
   :rclob *arm64-rclob*
   :rsave-mask *arm64-rsave-mask*
   :regs *arm64-regs*
   :abi0 #'a64-apple-extsb
   :abi1 #'arm64-abi
   :isel #'arm64-isel
   :emitfn #'a64-be-emit-fn
   :emitfin #'a64-emit-fin
   :retregs #'arm64-retregs
   :argregs #'arm64-argregs
   :memargs #'arm64-memargs
   :cansel nil)                 ; no if-conversion on arm64 (T.cansel = 0)
  "The arm64 Apple target (QBE T_arm64_apple).")
