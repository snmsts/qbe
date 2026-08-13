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

;;; QBE T_amd64_apple.  The ABI *is* SysV -- Apple's x86-64 ABI adopts it
;;; wholesale, so abi1/isel/emitfn/registers are all shared with amd64_sysv.
;;; What the target carries is the asm dialect amd64/emit.c keys off `T.apple`:
;;; `_`-prefixed globals, bare `L` locals, no ELF `.type`/`.size` footer or
;;; GNU-stack note, `@plt`-less calls, fp constants in `__TEXT,__literal*`
;;; sections (macho_emitfin), and TLS through the mach-o `@tlvp` indirection
;;; instead of `%fs`-relative offsets.
(defparameter *amd64-apple-target*
  (make-target
   :name "amd64_apple"
   :apple t
   :asloc "L"                   ; QBE T_amd64_apple.asloc -- bare `L`, not `.L`
   :assym "_"
   :gpr0 +rax+   :ngpr +amd64-ngpr+
   :fpr0 +xmm0+  :nfpr +amd64-nfpr+
   :rglob *amd64-rglob* :nrglob 2
   :rsave *sysv-rsave*  :nrsave *amd64-nrsave*
   :rclob *rclob*
   :rsave-mask *amd64-rsave-mask*
   :regs *amd64-regs*
   :abi0 nil
   :abi1 #'amd64-abi
   :isel #'amd64-isel
   :emitfn #'be-emit-fn
   :emitfin nil                 ; emit-fin is called by be-emit-module directly
   :retregs #'amd64-retregs
   :argregs #'amd64-argregs
   :memargs #'amd64-memargs
   :cansel t
   :objfmt :macho)
  "The amd64 Apple target (QBE T_amd64_apple).")

;;; QBE T_amd64_win.  Everything but the ABI is AMD64_COMMON: same registers,
;;; same isel, same instruction emitter.  What the target has to carry is the
;;; Microsoft calling convention (amd64-winabi.lisp), the caller/callee-save
;;; split that comes with it (RSI/RDI move to callee-save), and the handful of
;;; dialect differences amd64/emit.c keys off `T.windows` -- bare `L` local
;;; labels, no ELF symbol-size footer, no GNU-stack note, and a vararg prologue
;;; that spills the four argument registers into the caller's shadow space
;;; instead of a 176-byte area inside the frame.
(defparameter *amd64-win-target*
  (make-target
   :name "amd64_win"
   :apple nil
   :windows t
   :asloc "L"                   ; QBE T_amd64_win.asloc -- bare `L`, not `.L`
   :assym ""
   :gpr0 +rax+   :ngpr +amd64-ngpr+
   :fpr0 +xmm0+  :nfpr +amd64-nfpr+
   :rglob *amd64-rglob* :nrglob 2
   :rsave *winabi-rsave* :nrsave *winabi-nrsave*
   :rclob *winabi-rclob*
   :rsave-mask *winabi-rsave-mask*
   :regs *amd64-regs*
   :abi0 nil
   :abi1 #'amd64-winabi-abi
   :isel #'amd64-isel
   :emitfn #'be-emit-fn
   :emitfin nil                 ; emit-fin is called by be-emit-module directly
   :retregs #'amd64-winabi-retregs
   :argregs #'amd64-winabi-argregs
   :memargs #'amd64-memargs
   :cansel t
   :vararg-abi :gpr             ; the four argument registers, in shadow space
   :objfmt :coff)
  "The amd64 Windows target (QBE T_amd64_win).")

;;; Default the active target to amd64 SysV so passes invoked directly (the
;;; per-pass oracle tests: spill / rega / live, which don't go through
;;; be-emit-module) find a bound *target*.  be-emit-module rebinds it per call.
(setf *target* *amd64-sysv-target*)
