;;;; rv64-targ.lisp --- the rv64 target instance (mirrors rv64/targ.c).
;;;;
;;;; One target only: RISC-V 64 Linux, LP64D, ELF/GNU dialect.  abi0 is the
;;;; shared elimsb (like arm64 ELF); everything else is the rv64-* passes.

(in-package #:qbe)

;;; rv64/targ.c RGLOB = BIT(FP) | BIT(SP) | BIT(GP) | BIT(TP) | BIT(RA)
(defparameter *rv64-rglob*
  (logior (ash 1 +rv-fp+) (ash 1 +rv-sp+) (ash 1 +rv-gp+)
          (ash 1 +rv-tp+) (ash 1 +rv-ra+)))

;;; rv64/targ.c rv64_rsave (caller-save order) / rv64_rclob (callee-save).
(defparameter *rv64-rsave*
  (coerce
   (append (loop for i from +rv-t0+ to +rv-t5+ collect i)     ; T0..T5
           (loop for i from +rv-a0+ to +rv-a7+ collect i)     ; A0..A7
           (loop for i from +rv-fa0+ to +rv-fa7+ collect i)   ; FA0..FA7
           (loop for i from +rv-ft0+ to +rv-ft10+ collect i)) ; FT0..FT10
   'vector))
(defparameter *rv64-rclob*
  (coerce
   (append (loop for i from +rv-s1+ to +rv-s11+ collect i)    ; S1..S11
           (loop for i from +rv-fs0+ to +rv-fs11+ collect i)) ; FS0..FS11
   'vector))

;;; NGPS = A7 - T0 + 1 = 14; NFPS = FA7 - FT0 + 1 = 19.
(defparameter *rv64-nrsave* (vector 14 19))
(defparameter *rv64-rsave-mask*
  (reduce (lambda (m id) (logior m (ash 1 id))) *rv64-rsave* :initial-value 0))

(defun rv64-memargs (op) (declare (ignore op)) 0)   ; rv64/targ.c rv64_memargs

;;; ------------------------------------------------------------------ instance
(defparameter *rv64-target*
  (make-target
   :name "rv64"
   :apple nil
   :asloc ".L"
   :assym ""
   :gpr0 +rv-t0+ :ngpr +rv-ngpr+
   :fpr0 +rv-ft0+ :nfpr +rv-nfpr+
   :rglob *rv64-rglob* :nrglob 5
   :rsave *rv64-rsave* :nrsave *rv64-nrsave*
   :rclob *rv64-rclob*
   :rsave-mask *rv64-rsave-mask*
   :regs *rv64-regs*
   :abi0 #'elimsb
   :abi1 #'rv64-abi
   :isel #'rv64-isel
   :emitfn #'rv64-emit-fn
   :emitfin #'rv64-emit-fin
   :retregs #'rv64-retregs
   :argregs #'rv64-argregs
   :memargs #'rv64-memargs
   :cansel nil                  ; no if-conversion on rv64 (T.cansel = 0)
   :vararg-abi :gpr             ; 64-byte GPR save area above the frame
   :store-tmp -1                ; t6 is the emitter's own scratch, not spill's
   :objfmt :elf
   :litsec *a64-elf-litsec*)
  "The RISC-V 64 (LP64D, ELF/Linux) target (QBE T_rv64).")
