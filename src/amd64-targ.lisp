;;;; amd64-targ.lisp --- the amd64 SysV `target` instance (QBE amd64/targ.c).
;;;;
;;;; Built last, after the register spec (amd64-abi.lisp), the passes
;;;; (amd64-abi / amd64-isel / be-emit-fn) and *rclob* (amd64-emit.lisp) exist
;;;; -- exactly as QBE assembles T_amd64_sysv at the bottom of the backend.
;;;; Binding *target* to this is what makes the generic spill/rega/liveness
;;;; passes read the amd64 register model through the tg-* accessors.

(in-package #:qbe)

(defparameter *amd64-sysv-target*
  (make-target
   :name "amd64_sysv"
   :apple nil
   :asloc ".L"
   :assym ""
   :gpr0 +rax+   :ngpr +amd64-ngpr+
   :fpr0 +xmm0+  :nfpr +amd64-nfpr+
   :rglob *amd64-rglob* :nrglob 2
   :rsave *sysv-rsave*  :nrsave *amd64-nrsave*
   :rclob *rclob*
   :rsave-mask *amd64-rsave-mask*
   :regs *amd64-regs*
   :abi0 nil                    ; amd64 abi0 (elimsb) not yet a separate pass
   :abi1 #'amd64-abi
   :isel #'amd64-isel
   :emitfn #'be-emit-fn
   :emitfin nil                 ; emit-fin is called by be-emit-module directly
   :retregs #'amd64-retregs
   :argregs #'amd64-argregs
   :memargs #'amd64-memargs
   :cansel t)
  "The amd64 System V target (QBE T_amd64_sysv).")

;;; Default the active target to amd64 SysV so passes invoked directly (the
;;; per-pass oracle tests: spill / rega / live, which don't go through
;;; be-emit-module) find a bound *target*.  be-emit-module rebinds it per call.
(setf *target* *amd64-sysv-target*)
