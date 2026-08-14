;;;; rv64-emit.lisp --- rv64 assembly emission, mirrors rv64/emit.c.
;;;;
;;;; ELF/GNU dialect only (there is exactly one rv64 target): no symbol prefix,
;;;; `.L` locals, `.type`/`.size` footers, `.rodata` literals, GNU-stack note.
;;;; The characteristic rv64 shapes: `lla`/`lga` pseudo-instructions for
;;;; symbol addresses, tprel TLS, t6/ft11 as the reserved scratch pair, and the
;;;; fp-relative frame with the 64-byte vararg register save area above it.

(in-package #:qbe)

;;; ------------------------------------------------------------------ omap
;;; rv64/emit.c omap: (op cls fmt), matched in order.  cls is :ki (Kw/Kl),
;;; :ka (all), or a specific class.  %k prints the class char UNLESS Kl.
(defparameter *rv-omap*
  `((:add    :ki "add%k %=, %0, %1")
    (:add    :ka "fadd.%k %=, %0, %1")
    (:sub    :ki "sub%k %=, %0, %1")
    (:sub    :ka "fsub.%k %=, %0, %1")
    (:neg    :ki "neg%k %=, %0")
    (:neg    :ka "fneg.%k %=, %0")
    (:div    :ki "div%k %=, %0, %1")
    (:div    :ka "fdiv.%k %=, %0, %1")
    (:rem    :ki "rem%k %=, %0, %1")
    (:rem    :l  "rem %=, %0, %1")
    (:udiv   :ki "divu%k %=, %0, %1")
    (:urem   :ki "remu%k %=, %0, %1")
    (:mul    :ki "mul%k %=, %0, %1")
    (:mul    :ka "fmul.%k %=, %0, %1")
    (:and    :ki "and %=, %0, %1")
    (:or     :ki "or %=, %0, %1")
    (:xor    :ki "xor %=, %0, %1")
    (:sar    :ki "sra%k %=, %0, %1")
    (:shr    :ki "srl%k %=, %0, %1")
    (:shl    :ki "sll%k %=, %0, %1")
    (:csltl  :ki "slt %=, %0, %1")
    (:cultl  :ki "sltu %=, %0, %1")
    (:ceqs   :ki "feq.s %=, %0, %1")
    (:cges   :ki "fge.s %=, %0, %1")
    (:cgts   :ki "fgt.s %=, %0, %1")
    (:cles   :ki "fle.s %=, %0, %1")
    (:clts   :ki "flt.s %=, %0, %1")
    (:ceqd   :ki "feq.d %=, %0, %1")
    (:cged   :ki "fge.d %=, %0, %1")
    (:cgtd   :ki "fgt.d %=, %0, %1")
    (:cled   :ki "fle.d %=, %0, %1")
    (:cltd   :ki "flt.d %=, %0, %1")
    (:storeb :w  "sb %0, %M1")
    (:storeh :w  "sh %0, %M1")
    (:storew :w  "sw %0, %M1")
    (:storel :ki "sd %0, %M1")
    (:stores :w  "fsw %0, %M1")
    (:stored :w  "fsd %0, %M1")
    (:loadsb :ki "lb %=, %M0")
    (:loadub :ki "lbu %=, %M0")
    (:loadsh :ki "lh %=, %M0")
    (:loaduh :ki "lhu %=, %M0")
    (:loadsw :ki "lw %=, %M0")
    ;; riscv64 always sign-extends 32-bit values stored in 64-bit registers
    (:loaduw :w  "lw %=, %M0")
    (:loaduw :l  "lwu %=, %M0")
    (:load   :w  "lw %=, %M0")
    (:load   :l  "ld %=, %M0")
    (:load   :s  "flw %=, %M0")
    (:load   :d  "fld %=, %M0")
    (:extsb  :ki "sext.b %=, %0")
    (:extub  :ki "zext.b %=, %0")
    (:extsh  :ki "sext.h %=, %0")
    (:extuh  :ki "zext.h %=, %0")
    (:extsw  :l  "sext.w %=, %0")
    (:extuw  :l  "zext.w %=, %0")
    (:truncd :s  "fcvt.s.d %=, %0")
    (:exts   :d  "fcvt.d.s %=, %0")
    (:stosi  :w  "fcvt.w.s %=, %0, rtz")
    (:stosi  :l  "fcvt.l.s %=, %0, rtz")
    (:stoui  :w  "fcvt.wu.s %=, %0, rtz")
    (:stoui  :l  "fcvt.lu.s %=, %0, rtz")
    (:dtosi  :w  "fcvt.w.d %=, %0, rtz")
    (:dtosi  :l  "fcvt.l.d %=, %0, rtz")
    (:dtoui  :w  "fcvt.wu.d %=, %0, rtz")
    (:dtoui  :l  "fcvt.lu.d %=, %0, rtz")
    (:swtof  :ka "fcvt.%k.w %=, %0")
    (:uwtof  :ka "fcvt.%k.wu %=, %0")
    (:sltof  :ka "fcvt.%k.l %=, %0")
    (:ultof  :ka "fcvt.%k.lu %=, %0")
    (:cast   :w  "fmv.x.w %=, %0")
    (:cast   :l  "fmv.x.d %=, %0")
    (:cast   :s  "fmv.w.x %=, %0")
    (:cast   :d  "fmv.d.x %=, %0")
    (:copy   :ki "mv %=, %0")
    (:copy   :ka "fmv.%k %=, %0")
    (:swap   :ki ,(format nil "mv %?, %0~%~Cmv %0, %1~%~Cmv %1, %?" #\Tab #\Tab))
    (:swap   :ka ,(format nil "fmv.%k %?, %0~%~Cfmv.%k %0, %1~%~Cfmv.%k %1, %?" #\Tab #\Tab))
    (:reqz   :ki "seqz %=, %0")
    (:rnez   :ki "snez %=, %0")
    (:call   :w  "jalr %0"))
  "rv64/emit.c omap[].")

(defun rv-omap-match (op cls)
  (dolist (row *rv-omap*
           (error "rv64 emit: no omap match for ~s(~s)" op cls))
    (destructuring-bind (o c fmt) row
      (when (and (eq o op)
                 (or (eq c cls) (eq c :ka)
                     (and (eq c :ki) (= (cls-base cls) 0))))
        (return fmt)))))

;;; ------------------------------------------------------------------ E state
(defstruct (rve (:conc-name rve-)) stream fn (frame 0))

(defun rve-out (e fmt &rest args) (apply #'format (rve-stream e) fmt args))

(defun rv-rname (id) (aref *rv64-reg-names* id))

;;; ------------------------------------------------------------------ slots
(defun rv-slot (r e)
  "rv64/emit.c slot: RSlot R -> byte offset off fp."
  (let ((s (slot-ref-n r)) (fn (rve-fn e)))
    (assert (<= s (fn-slot fn)))
    (if (< s 0)
        (* 8 (- s))
        (* -4 (- (fn-slot fn) s)))))

;;; ------------------------------------------------------------------ emitaddr
(defun rv-emitaddr (c e)
  "rv64/emit.c emitaddr: print a CAddr constant (no offsets on externs)."
  (assert (not (member :thr (con-symtype c))))
  (write-string (con-symname c) (rve-stream e))
  (when (/= (con-off c) 0)
    ;; TODO (upstream): fix isel to ensure no offset for SGlo
    (when (member :ext (con-symtype c))
      (error "rv64 emit: extern with offset is not supported"))
    (rve-out e "+~d" (con-off c))))

;;; ------------------------------------------------------------------ emitf
(defun rv-getarg (ch i)
  (ecase ch (#\0 (ins-arg0 i)) (#\1 (ins-arg1 i)) (#\= (ins-to i))))

(defparameter *rv-clschr* #(#\w #\l #\s #\d))

(defun rv-emitf (fmt i e)
  "rv64/emit.c emitf: interpret an omap format string for instruction I."
  (let ((s (rve-stream e)) (p 0) (n (length fmt)))
    (write-char #\Tab s)
    (loop while (< p n) do
      (let ((c (char fmt p)))
        (incf p)
        (if (char/= c #\%)
            (write-char c s)
            (let ((d (char fmt p)))
              (incf p)
              (case d
                (#\?
                 (write-string (if (= (cls-base (ins-cls i)) 0) "t6" "ft11") s))
                (#\k
                 (unless (eq (ins-cls i) :l)
                   (write-char (aref *rv-clschr* (cls-code (ins-cls i))) s)))
                ((#\= #\0)
                 (let ((r (rv-getarg d i)))
                   (assert (reg-p r))
                   (write-string (rv-rname (reg-id r)) s)))
                (#\1
                 (let ((r (ins-arg1 i)))
                   (cond
                     ((reg-p r) (write-string (rv-rname (reg-id r)) s))
                     ((con-p r)
                      (assert (eq (con-kind r) :bits))
                      (assert (<= -2048 (con-rawbits r) 2047))
                      (rve-out e "~d" (con-rawbits r)))
                     (t (error "rv64 emit: invalid second argument")))))
                (#\M
                 (let* ((mc (char fmt p)) (r (rv-getarg mc i)))
                   (incf p)
                   (cond
                     ((reg-p r) (rve-out e "0(~a)" (rv-rname (reg-id r))))
                     ((con-p r)
                      (assert (eq (con-kind r) :addr))
                      (rv-emitaddr r e)
                      ;; store (and float load) pseudo-instructions need a
                      ;; temporary register in which to load the address
                      (when (or (isstore-op (ins-op i))
                                (and (isload-op (ins-op i))
                                     (= (cls-base (ins-cls i)) 1)))
                        (write-string ", t6" s)))
                     ((slot-ref-p r)
                      (let ((off (rv-slot r e)))
                        (assert (<= -2048 off 2047))
                        (rve-out e "~d(fp)" off)))
                     (t (error "rv64 emit: invalid address argument")))))
                (t (error "rv64 emit: invalid escape %~a" d)))))))
    (write-char #\Newline s)))

;;; ------------------------------------------------------------ loadaddr etc.
(defun rv-loadaddr (c rn e)
  "rv64/emit.c loadaddr: materialize symbol address C into register name RN."
  (let ((st (con-symtype c)))
    (cond
      ((and (member :thr st) (member :ext st))
       (error "rv64 emit: extern thread unavailable on rv64"))
      ((member :thr st)
       (let ((off (if (/= (con-off c) 0) (format nil "+~d" (con-off c)) ""))
             (l (con-symname c)))
         (rve-out e "~Clui ~a, %tprel_hi(~a)~a~%" #\Tab rn l off)
         (rve-out e "~Cadd ~a, ~a, tp, %tprel_add(~a)~a~%" #\Tab rn rn l off)
         (rve-out e "~Caddi ~a, ~a, %tprel_lo(~a)~a~%" #\Tab rn rn l off)))
      (t
       (rve-out e "~C~a ~a, " #\Tab (if (member :ext st) "lga" "lla") rn)
       (rv-emitaddr c e)
       (write-char #\Newline (rve-stream e))))))

(defun rv-loadcon (c rid k e)
  "rv64/emit.c loadcon: materialize constant C into register RID at class K."
  (let ((rn (rv-rname rid)))
    (ecase (con-kind c)
      (:addr (rv-loadaddr c rn e))
      (:bits
       (let ((n (con-rawbits c)))
         (unless (kwide k) (setf n (s32* n)))
         (rve-out e "~Cli ~a, ~d~%" #\Tab rn n))))))

(defun rv-fixmem (r e)
  "rv64/emit.c fixmem: an extern/thread address, or a slot beyond the 12-bit
range, is materialized into t6 first.  Returns the operand to use."
  (cond
    ((and (con-p r) (eq (con-kind r) :addr) (con-symtype r))
     (rv-loadcon r +rv-t6+ :l e)
     (rvrg +rv-t6+))
    ((slot-ref-p r)
     (let ((s (rv-slot r e)))
       (if (or (< s -2048) (> s 2047))
           (progn
             (rve-out e "~Cli t6, ~d~%" #\Tab s)
             (rve-out e "~Cadd t6, fp, t6~%" #\Tab)
             (rvrg +rv-t6+))
           r)))
    (t r)))

;;; ------------------------------------------------------------------ emitins
(defun rv-emitins-table (i e)
  (rv-emitf (rv-omap-match (ins-op i) (ins-cls i)) i e))

(defun rv-emitins (i e)
  "rv64/emit.c emitins."
  (let ((op (ins-op i)))
    (case op
      (:nop)
      (:dbgloc)                                    ; debug info: skipped
      (:copy (rv-emit-copyins i e))
      (:addr
       (assert (slot-ref-p (ins-arg0 i)))
       (let ((rn (rv-rname (reg-id (ins-to i)))) (s (rv-slot (ins-arg0 i) e)))
         (if (< (- s) 2048)
             (rve-out e "~Cadd ~a, fp, ~d~%" #\Tab rn s)
             (progn
               (rve-out e "~Cli ~a, ~d~%" #\Tab rn s)
               (rve-out e "~Cadd ~a, fp, ~a~%" #\Tab rn rn)))))
      (:call
       (let ((a0 (ins-arg0 i)))
         (cond
           ((con-p a0)
            (when (or (not (eq (con-kind a0) :addr))
                      (member :thr (con-symtype a0))
                      (/= (con-off a0) 0))
              (error "rv64 emit: invalid call argument"))
            (rve-out e "~Ccall ~a~%" #\Tab (con-symname a0)))
           ((reg-p a0) (rv-emitf "jalr %0" i e))
           (t (error "rv64 emit: invalid call argument")))))
      (:salloc
       (rv-emitf "sub sp, sp, %0" i e)
       (when (ins-to i) (rv-emitf "mv %=, sp" i e)))
      (t
       (cond
         ((isload-op op) (setf (ins-arg0 i) (rv-fixmem (ins-arg0 i) e)))
         ((isstore-op op) (setf (ins-arg1 i) (rv-fixmem (ins-arg1 i) e))))
       (rv-emitins-table i e)))))

(defun rv-emit-copyins (i e)
  "rv64/emit.c emitins Ocopy case."
  (let ((to (ins-to i)) (a0 (ins-arg0 i)))
    (cond
      ((and to a0 (ref= to a0)))                   ; nop copy
      ((slot-ref-p to)
       (when (or (slot-ref-p a0) (con-p a0))
         (error "rv64 emit: unimplemented copy into slot"))
       (assert (reg-p a0))
       (setf (ins-arg1 i) to (ins-to i) nil
             (ins-op i) (aref #(:storew :storel :stores :stored)
                              (cls-code (ins-cls i))))
       (setf (ins-arg1 i) (rv-fixmem (ins-arg1 i) e))
       (rv-emitins-table i e))
      (t
       (assert (reg-p to))
       (cond
         ((con-p a0) (rv-loadcon a0 (reg-id to) (ins-cls i) e))
         ((slot-ref-p a0)
          (setf (ins-op i) :load
                (ins-arg0 i) (rv-fixmem (ins-arg0 i) e))
          (rv-emitins-table i e))
         (t (assert (reg-p a0)) (rv-emitins-table i e)))))))

;;; ------------------------------------------------------------------ fn emit
;;;
;;;  Stack-frame layout (rv64/emit.c):
;;;
;;;  +=============+
;;;  | varargs     |
;;;  |  save area  |
;;;  +-------------+
;;;  |  saved ra   |
;;;  |  saved fp   |
;;;  +-------------+ <- fp
;;;  |    ...      |
;;;  | spill slots |
;;;  |    ...      |
;;;  +-------------+
;;;  |    ...      |
;;;  |   locals    |
;;;  |    ...      |
;;;  +-------------+
;;;  |   padding   |
;;;  +-------------+
;;;  | callee-save |
;;;  |  registers  |
;;;  +=============+

(defvar *rv-id0* 0 "Running block-label counter across a module's functions.")

(defun rv64-emit-fn (fn stream)
  "rv64/emit.c rv64_emitfn: emit one function."
  (let ((e (make-rve :stream stream :fn fn)))
    ;; emitfnlnk: .text, function alignment, .globl, label
    (rve-out e ".text~%.balign 16~%")
    (when (fn-export fn) (rve-out e ".globl ~a~%" (fn-name fn)))
    (rve-out e "~a:~%" (fn-name fn))
    (when (fn-vararg fn)
      ;; TODO (upstream): only need space for registers unused by named args
      (rve-out e "~Cadd sp, sp, -64~%" #\Tab)
      (loop for r from +rv-a0+ to +rv-a7+
            do (rve-out e "~Csd ~a, ~d(sp)~%" #\Tab (rv-rname r)
                        (* 8 (- r +rv-a0+)))))
    (rve-out e "~Csd fp, -16(sp)~%~Csd ra, -8(sp)~%~Cadd fp, sp, -16~%"
             #\Tab #\Tab #\Tab)
    (let ((frame (logand (+ 16 (* 4 (fn-slot fn)) 15) -16)))
      (loop for rc across (tg-rclob)
            when (logbitp rc (fn-reg fn)) do (incf frame 8))
      (setf frame (logand (+ frame 15) -16)
            (rve-frame e) frame)
      (if (<= frame 2048)
          (rve-out e "~Cadd sp, sp, -~d~%" #\Tab frame)
          (rve-out e "~Cli t6, ~d~%~Csub sp, sp, t6~%" #\Tab frame #\Tab))
      (let ((off 0))
        (loop for rc across (tg-rclob)
              when (logbitp rc (fn-reg fn))
              do (rve-out e "~C~a ~a, ~d(sp)~%" #\Tab
                          (if (< rc +rv-ft0+) "sd" "fsd") (rv-rname rc) off)
                 (incf off 8)))
      (let ((lbl nil))
        (loop for b = (fn-start fn) then (blk-link b) while b do
          (when (or lbl (> (length (blk-preds b)) 1))
            (rve-out e "~a~d:~%" (tg-asloc) (+ *rv-id0* (blk-id b))))
          (dolist (i (blk-ins b)) (rv-emitins i e))
          (setf lbl t)
          (case (blk-jmp-type b)
            (:hlt (rve-out e "~Cebreak~%" #\Tab))
            (:ret0
             (when (fn-dynalloc fn)
               (if (<= (- frame 16) 2048)
                   (rve-out e "~Cadd sp, fp, -~d~%" #\Tab (- frame 16))
                   (rve-out e "~Cli t6, ~d~%~Csub sp, fp, t6~%" #\Tab (- frame 16) #\Tab)))
             (let ((off 0))
               (loop for rc across (tg-rclob)
                     when (logbitp rc (fn-reg fn))
                     do (rve-out e "~C~a ~a, ~d(sp)~%" #\Tab
                                 (if (< rc +rv-ft0+) "ld" "fld") (rv-rname rc) off)
                        (incf off 8)))
             (rve-out e "~Cadd sp, fp, ~d~%~Cld ra, 8(fp)~%~Cld fp, 0(fp)~%~Cret~%"
                      #\Tab (+ 16 (if (fn-vararg fn) 64 0)) #\Tab #\Tab #\Tab))
            (:jmp
             (if (not (eq (blk-s1 b) (blk-link b)))
                 (rve-out e "~Cj ~a~d~%" #\Tab (tg-asloc) (+ *rv-id0* (blk-id (blk-s1 b))))
                 (setf lbl nil)))
            (:jnz
             (let ((neg nil))
               (when (eq (blk-link b) (blk-s2 b))
                 (rotatef (blk-s1 b) (blk-s2 b))
                 (setf neg t))
               (when (slot-ref-p (blk-jmp-arg b))
                 (let ((ii (make-instance 'ins :op :loadsw :cls :w :to nil
                                          :arg0 (blk-jmp-arg b) :arg1 nil)))
                   (rv-emitf "lw t6, %M0" ii e))
                 (setf (blk-jmp-arg b) (rvrg +rv-t6+)))
               (assert (reg-p (blk-jmp-arg b)))
               (rve-out e "~Cb~az ~a, ~a~d~%" #\Tab (if neg "ne" "eq")
                        (rv-rname (reg-id (blk-jmp-arg b)))
                        (tg-asloc) (+ *rv-id0* (blk-id (blk-s2 b))))
               (if (not (eq (blk-s1 b) (blk-link b)))
                   (rve-out e "~Cj ~a~d~%" #\Tab (tg-asloc) (+ *rv-id0* (blk-id (blk-s1 b))))
                   (setf lbl nil))))
            (t (error "rv64 emit: unhandled jump ~s" (blk-jmp-type b)))))))
    (incf *rv-id0* (fn-nblk fn))
    ;; elf_emitfnfin
    (rve-out e ".type ~a, @function~%.size ~a, .-~a~%" (fn-name fn) (fn-name fn) (fn-name fn))
    (rve-out e "/* end function ~a */~%~%" (fn-name fn))))

;;; ------------------------------------------------------------ backend driver
(defun rv64-backend-pipeline (fn)
  "Full rv64 backend (main.c func, T.cansel=0 -> NO ifconvert): abi0 = elimsb,
SSA, mid-end, abi1, isel, then spill/rega and simpljmp."
  (funcall (target-abi0 *target*) fn)
  (fill-cfg fn) (fill-use fn) (promote fn) (fill-use fn)
  (ssa fn) (fill-use fn)
  (fill-alias fn) (loadopt fn) (fill-use fn) (fill-alias fn) (coalesce fn)
  (fill-use fn) (fill-dom fn)
  (gvn fn) (fill-cfg fn) (simplcfg fn)
  (fill-use fn) (fill-dom fn) (gcm fn) (fill-use fn)
  (rv64-abi fn) (simpl fn) (fill-cfg fn) (fill-use fn)
  (rv64-isel fn)
  (materialize-regs fn)
  (fill-cfg fn) (be-fill-live fn) (fill-loop fn) (fill-cost fn)
  (spill fn) (rega fn)
  (fill-cfg fn) (simpljmp fn) (fill-cfg fn))

(defun rv64-fmt-double (x)
  "printf %f for the fp-pool comments, including the glibc nan/inf spellings."
  (cond
    ((sb-ext:float-nan-p x) (if (minusp (float-sign x)) "-nan" "nan"))
    ((sb-ext:float-infinity-p x) (if (plusp x) "inf" "-inf"))
    (t (format nil "~,6F" x))))

(defun rv64-emit-fin (stream)
  "emit.c elf_emitfin for rv64: the fp-constant pool in .rodata (with emitfin's
`/* %f */` value comments), then the GNU-stack note."
  (when (> (fill-pointer *stash*) 0)
    (format stream "/* floating point constants */~%")
    (loop for lg from 4 downto 2 do
      (dotimes (i (fill-pointer *stash*))
        (let ((b (aref *stash* i)))
          (when (= (cdr b) (ash 1 lg))
            (format stream ".section .rodata~%.p2align ~d~%~afp~d:" lg (tg-asloc) i)
            (ecase lg
              (4 (format stream "~%~C.quad ~d~%~C.quad 0~%~%" #\Tab (car b) #\Tab))
              (3 (format stream "~%~C.quad ~d /* ~a */~%~%" #\Tab (norm-i64 (car b))
                         (rv64-fmt-double (bits->double (car b)))))
              (2 (format stream "~%~C.int ~d /* ~a */~%~%" #\Tab (s32* (car b))
                         (rv64-fmt-double (float (bits->single (car b)) 1d0))))))))))
  (format stream ".section .note.GNU-stack,\"\",@progbits~%"))

(defun rv64-emit-module (module &optional (*target* *rv64-target*))
  "Run the rv64 backend per function and return the module's ELF assembly."
  (let ((s (make-string-output-stream)) (*rv-id0* 0))
    (setf *tmp-counter* 0)
    (reset-stash)
    (dolist (fn (module-funcs module))
      (rv64-backend-pipeline fn)
      (rv64-emit-fn fn s))
    (dolist (d (module-data module)) (a64-emit-data d s))
    (rv64-emit-fin s)
    (get-output-stream-string s)))
