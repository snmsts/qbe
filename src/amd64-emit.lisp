;;;; amd64-emit.lisp --- M4 final assembly emission (amd64/emit.c), post-rega.
;;;;
;;;; Emits AT&T-syntax x86-64 for the register-allocated IR: function prologue
;;;; (endbr64 / frame / callee-save pushes), per-block labels + instructions via
;;;; the omap[] format-string table (with the 3->2 address conversion emitf
;;;; performs), conditional/unconditional jumps, and the epilogue.
;;;;
;;;; Scope = the isel/rega-supported scalar subset (int arithmetic, cmov, float
;;;; compares, int<->float conv).  Loads/stores/RMem, float-const memory, aggregate
;;;; args/returns, varargs are out of scope (unreached by the supported corpus).

(in-package #:qbe)

;;; register name table (amd64/emit.c rname): id -> #(quad long word byte).
(defparameter *rname*
  (let ((v (make-array 17 :initial-element nil)))
    (loop for (id q d w b) in
          '((1 "rax" "eax" "ax" "al") (2 "rcx" "ecx" "cx" "cl")
            (3 "rdx" "edx" "dx" "dl") (4 "rsi" "esi" "si" "sil")
            (5 "rdi" "edi" "di" "dil") (6 "r8" "r8d" "r8w" "r8b")
            (7 "r9" "r9d" "r9w" "r9b") (8 "r10" "r10d" "r10w" "r10b")
            (9 "r11" "r11d" "r11w" "r11b") (10 "rbx" "ebx" "bx" "bl")
            (11 "r12" "r12d" "r12w" "r12b") (12 "r13" "r13d" "r13w" "r13b")
            (13 "r14" "r14d" "r14w" "r14b") (14 "r15" "r15d" "r15w" "r15b")
            (15 "rbp" "ebp" "bp" "bpl") (16 "rsp" "esp" "sp" "spl"))
          do (setf (aref v id) (vector q d w b)))
    v))

(defconstant +slong+ 0) (defconstant +sword+ 1)
(defconstant +sshort+ 2) (defconstant +sbyte+ 3)

(defun regtoa (id sz)
  (if (>= id +xmm0+) (format nil "xmm~d" (- id +xmm0+))
      (aref (aref *rname* id) sz)))

;;; callee-save registers (amd64_sysv_rclob) for frame parity + save/restore.
(defparameter *rclob* #(10 11 12 13 14))    ; RBX R12 R13 R14 R15

;;; comparison code -> #(true-suffix false-suffix) setcc/jcc (emit.c CMP table,
;;; reindexed to the CL c-encoding: 0 eq,1 ne,2 sge,3 sgt,4 sle,5 slt,6 uge,
;;; 7 ugt,8 ule,9 ult, 10 feq,11 fge,12 fgt,13 fle,14 flt,15 fne,16 fo,17 fuo).
(defparameter *cc-suffix*
  #(#("z" "nz") #("nz" "z") #("ge" "l") #("g" "le") #("le" "g") #("l" "ge")
    #("ae" "b") #("a" "be") #("be" "a") #("b" "ae")
    #("z" "nz") #("ae" "b") #("a" "be") #("?" "?") #("?" "?")
    #("nz" "z") #("np" "p") #("p" "np")))
(defparameter *flag-op-code*
  (let ((h (make-hash-table))) (loop for op across *flag-ops* for c from 0
                                     do (setf (gethash op h) c)) h))
(defparameter *jf-jump-code*
  (let ((h (make-hash-table))) (loop for op across *jf-jumps-vec* for c from 0
                                     do (setf (gethash op h) c)) h))

;;; omap (amd64/emit.c): (op cls-key fmt).  cls-key :a=all, :i=int(w/l), or w/l/s/d.
(defparameter *omap*
  '((:add :a "+add%k %1, %=") (:sub :a "-sub%k %1, %=")
    (:and :i "+and%k %1, %=") (:or :i "+or%k %1, %=") (:xor :i "+xor%k %1, %=")
    (:sar :i "-sar%k %B1, %=") (:shr :i "-shr%k %B1, %=") (:shl :i "-shl%k %B1, %=")
    (:mul :i "+imul%k %1, %=") (:mul :s "+mulss %1, %=") (:mul :d "+mulsd %1, %=")
    (:div :a "-div%k %1, %=")
    (:storel :a "movq %L0, %M1") (:storew :a "movl %W0, %M1")
    (:storeh :a "movw %H0, %M1") (:storeb :a "movb %B0, %M1")
    (:stores :a "movss %S0, %M1") (:stored :a "movsd %D0, %M1")
    (:load :a "mov%k %M0, %=")
    (:loadsw :l "movslq %M0, %L=") (:loadsw :w "movl %M0, %W=") (:loaduw :i "movl %M0, %W=")
    (:loadsh :i "movsw%k %M0, %=") (:loaduh :i "movzw%k %M0, %=")
    (:loadsb :i "movsb%k %M0, %=") (:loadub :i "movzb%k %M0, %=")
    (:extsw :l "movslq %W0, %L=") (:extuw :l "movl %W0, %W=")
    (:extsh :i "movsw%k %H0, %=") (:extuh :i "movzw%k %H0, %=")
    (:extsb :i "movsb%k %B0, %=") (:extub :i "movzb%k %B0, %=")
    (:exts :d "cvtss2sd %0, %=") (:truncd :s "cvtsd2ss %0, %=")
    (:stosi :i "cvttss2si%k %0, %=") (:dtosi :i "cvttsd2si%k %0, %=")
    (:swtof :a "cvtsi2%k %W0, %=") (:sltof :a "cvtsi2%k %L0, %=")
    (:cast :i "movq %D0, %L=") (:cast :a "movq %L0, %D=")
    (:addr :i "lea%k %M0, %=") (:swap :i "xchg%k %0, %1")
    (:sign :l "cqto") (:sign :w "cltd")
    (:xdiv :i "div%k %0") (:xidiv :i "idiv%k %0")
    (:xcmp :s "ucomiss %S0, %S1") (:xcmp :d "ucomisd %D0, %D1") (:xcmp :i "cmp%k %0, %1")
    (:xtest :i "test%k %0, %1")))

(defun cls-base* (cls) (if (member cls '(:w :l)) 0 1))
(defun omap-match (op cls)
  (dolist (e *omap*)
    (when (and (eq (first e) op)
               (let ((k (second e)))
                 (or (eq k cls) (and (eq k :i) (= (cls-base* cls) 0)) (eq k :a))))
      (return (third e)))))

;;; emit state
(defstruct (es (:conc-name es-)) stream fn (fp +rsp+) (fsz 0) (nclob 0) leaf)

(defun es-out (e fmt &rest args) (apply #'format (es-stream e) fmt args))

(defun be-emitcon (con e)
  (ecase (con-kind con)
    (:bits (es-out e "~d" (con-value con)))
    (:addr (write-string (con-symname con) (es-stream e))
           (unless (zerop (con-off con)) (es-out e "~@d" (con-off con))))))

(defun getarg (ch i)
  (ecase ch (#\0 (ins-arg0 i)) (#\1 (ins-arg1 i)) (#\= (ins-to i))))

(defun emit-addr (m e)
  "Render an RMem addressing mode `disp(%base, %index, scale)` (emit.c Mem).
   A slot base folds into the frame-pointer-relative displacement."
  (when (slot-ref-p (mem-base m))
    (let ((offc (mem-offset m)))
      (unless (and offc (not (eq (con-kind offc) :undef)))
        (setf offc (make-con :kind :undef :value 0) (mem-offset m) offc))
      (addcon offc (make-con :kind :bits :value (be-slot (mem-base m) e)) 1)
      (setf (mem-base m) (rg (es-fp e)))))
  (let ((off (mem-offset m)))
    (when (and off (not (eq (con-kind off) :undef))) (be-emitcon off e)))
  (write-char #\( (es-stream e))
  (cond ((mem-base m) (es-out e "%~a" (regtoa (reg-id (mem-base m)) +slong+)))
        ((let ((o (mem-offset m))) (and o (eq (con-kind o) :addr)))
         (es-out e "%~a" "rip")))
  (when (mem-index m)
    (es-out e ", %~a, ~d" (regtoa (reg-id (mem-index m)) +slong+) (mem-scale m)))
  (write-char #\) (es-stream e)))

(defun emit-ref (ref sz e)
  "Print operand REF at size SZ (emit.c emitf Ref case)."
  (cond
    ((reg-p ref) (es-out e "%~a" (regtoa (reg-id ref) sz)))
    ((slot-ref-p ref) (es-out e "~d(%~a)" (be-slot ref e) (regtoa (es-fp e) +slong+)))
    ((mem-p ref) (emit-addr ref e))
    ((con-p ref) (write-char #\$ (es-stream e)) (be-emitcon ref e))
    (t (error "emit-ref: unhandled ~s" ref))))

(defun emit-mem (ref e)
  "Print a memory operand (%M spec): RMem, RSlot, RCon (rip-relative), or reg."
  (cond
    ((mem-p ref) (emit-addr ref e))
    ((slot-ref-p ref) (es-out e "~d(%~a)" (be-slot ref e) (regtoa (es-fp e) +slong+)))
    ((con-p ref) (be-emitcon ref e)
     (when (eq (con-kind ref) :addr) (es-out e "(%~a)" "rip")))
    ((reg-p ref) (es-out e "(%~a)" (regtoa (reg-id ref) +slong+)))
    (t (error "emit-mem: unhandled ~s" ref))))

(defun be-slot (ref e)
  "RSlot -> byte offset off the frame pointer (emit.c slot)."
  (let ((s (slot-ref-n ref)) (fn (es-fn e)))
    (cond
      ((< s 0) (if (= (es-fp e) +rsp+)
                   (+ (* 4 (- s)) -8 (es-fsz e) (* (es-nclob e) 8))
                   (* 4 (- s))))
      ((= (es-fp e) +rsp+) (+ (* 4 s) (* (es-nclob e) 8)))
      ((fn-vararg fn) (* -4 (- (fn-slot fn) s)))
      (t (* -4 (- (fn-slot fn) s))))))

(defparameter *clstoa* #("l" "q" "ss" "sd"))   ; %k by cls w/l/s/d
(defun class-str (cls) (aref *clstoa* (ecase cls (:w 0) (:l 1) (:s 2) (:d 3))))

(defun be-emitf (fmt i e)
  "Interpret an omap format string for instruction I (emit.c emitf)."
  (let ((s (es-stream e)) (p 0) (n (length fmt)))
    (when (and (> n 0) (member (char fmt 0) '(#\+ #\-)))
      (when (and (char= (char fmt 0) #\+) (ref= (ins-arg1 i) (ins-to i)))
        (rotatef (ins-arg0 i) (ins-arg1 i)))
      (be-emitcopy (ins-to i) (ins-arg0 i) (ins-cls i) e)
      (setf p 1))
    (write-char #\Tab s)
    (flet ((arg-at () (prog1 (getarg (char fmt p) i) (incf p))))
      (loop while (< p n) do
        (let ((c (char fmt p)))
          (incf p)
          (if (char/= c #\%)
              (write-char c s)
              (let ((d (char fmt p)))
                (incf p)
                (case d
                  (#\% (write-char #\% s))
                  (#\k (write-string (class-str (ins-cls i)) s))
                  ((#\0 #\1 #\=) (decf p)
                   (emit-ref (arg-at) (if (kwide (ins-cls i)) +slong+ +sword+) e))
                  ((#\D #\S) (emit-ref (arg-at) +slong+ e))
                  (#\L (emit-ref (arg-at) +slong+ e))
                  (#\W (emit-ref (arg-at) +sword+ e))
                  (#\H (emit-ref (arg-at) +sshort+ e))
                  (#\B (emit-ref (arg-at) +sbyte+ e))
                  (#\M (emit-mem (arg-at) e))
                  (t (error "bad spec %~a" d))))))))
    (write-char #\Newline s)))

(defun be-emitcopy (to arg0 cls e)
  (be-emitins (make-instance 'ins :op :copy :cls cls :to to :arg0 arg0 :arg1 nil) e))

(defun be-emitins (i e)
  "Emit one instruction (amd64/emit.c emitins), handling special cases."
  (let ((op (ins-op i)))
    (cond
      ((eq op :nop))
      ((eq op :copy) (be-emit-copyins i e))
      ((eq op :mul) (be-emit-mul i e))
      ((eq op :sub) (be-emit-sub i e))
      ((eq op :neg) (be-emit-neg i e))
      ((eq op :div) (be-emit-div i e))
      ((eq op :call) (be-emit-call i e))
      ((eq op :swap) (be-emit-swap i e))
      ((find op *xsel-ops*) (be-emit-xsel i e))
      ((gethash op *flag-op-code*)
       (let ((suf (aref (aref *cc-suffix* (gethash op *flag-op-code*)) 0)))
         (be-emitf (format nil "set~a %B=~C~Cmovzb%k %B=, %=" suf #\Newline #\Tab) i e)))
      (t (let ((fmt (omap-match op (ins-cls i))))
           (unless fmt (error "emit: no omap match for ~s(~s)" op (ins-cls i)))
           (be-emitf fmt i e))))))

(defun be-emit-copyins (i e)
  (let ((to (ins-to i)) (a0 (ins-arg0 i)))
    (unless (or (null to) (null a0) (ref= to a0))
      (let ((t0 a0))
        (cond
          ;; big / small integer constants into a register: movl for the low half
          ((and (eq (ins-cls i) :l) (con-p t0) (eq (con-kind t0) :bits)
                (reg-p to) (<= 0 (con-value t0) #xffffffff))
           (be-emitf "movl %W0, %W=" i e))
          ((and (reg-p to) (con-p t0) (eq (con-kind t0) :addr))
           (be-emitf "lea%k %M0, %=" i e))
          ;; slot<-slot/mem: x86 has no mem->mem mov; bounce through xmm15
          ((and (slot-ref-p to) (or (slot-ref-p t0) (mem-ref-p t0)))
           (setf (ins-cls i) (if (kwide (ins-cls i)) :d :s)
                 (ins-arg1 i) (rg (+ +xmm0+ 15)))
           (be-emitf "mov%k %0, %1" i e)
           (be-emitf "mov%k %1, %=" i e))
          (t (be-emitf "mov%k %0, %=" i e)))))))

(defun be-emit-mul (i e)
  (when (con-p (ins-arg1 i)) (rotatef (ins-arg0 i) (ins-arg1 i)))
  (if (and (= (cls-base* (ins-cls i)) 0) (con-p (ins-arg0 i)) (reg-p (ins-arg1 i)))
      (be-emitf "imul%k %0, %1, %=" i e)
      (be-emitf (omap-match :mul (ins-cls i)) i e)))

(defun be-emit-sub (i e)
  (if (and (ref= (ins-to i) (ins-arg1 i)) (not (ref= (ins-arg0 i) (ins-to i))))
      (progn (be-emitins (make-instance 'ins :op :neg :cls (ins-cls i)
                                        :to (ins-to i) :arg0 (ins-to i)) e)
             (be-emitf "add%k %0, %=" i e))
      (be-emitf (omap-match :sub (ins-cls i)) i e)))

(defun be-emit-neg (i e)
  (unless (ref= (ins-to i) (ins-arg0 i)) (be-emitf "mov%k %0, %=" i e))
  (if (= (cls-base* (ins-cls i)) 0)
      (be-emitf "neg%k %=" i e)
      (error "emit: float neg needs a stashed mask (out of scope)")))

(defun be-emit-div (i e)
  (when (ref= (ins-to i) (ins-arg1 i))
    (setf (ins-arg1 i) (rg (+ +xmm0+ 15)))
    (be-emitf "mov%k %=, %1" i e)
    (be-emitf "mov%k %0, %=" i e)
    (setf (ins-arg0 i) (ins-to i)))
  (be-emitf (omap-match :div (ins-cls i)) i e))

(defun be-emit-call (i e)
  (let ((a0 (ins-arg0 i)))
    (cond
      ((con-p a0)
       (es-out e "~Ccallq " #\Tab) (be-emitcon a0 e)
       (when (and (eq (con-kind a0) :addr) (member :ext (con-symtype a0)))
         (es-out e "@plt"))
       (write-char #\Newline (es-stream e)))
      ((reg-p a0) (be-emitf "callq *%L0" i e))
      (t (error "emit: invalid call argument")))))

(defun be-emit-swap (i e)
  (if (= (cls-base* (ins-cls i)) 0)
      (be-emitf (omap-match :swap (ins-cls i)) i e)
      (let ((x15 (rg (+ +xmm0+ 15))))
        (be-emitcopy x15 (ins-arg0 i) (ins-cls i) e)
        (be-emitcopy (ins-arg0 i) (ins-arg1 i) (ins-cls i) e)
        (be-emitcopy (ins-arg1 i) x15 (ins-cls i) e))))

(defun be-emit-xsel (i e)
  (let* ((c (position (ins-op i) *xsel-ops*))
         (suf0 (aref (aref *cc-suffix* c) 0))
         (suf1 (aref (aref *cc-suffix* c) 1)))
    (if (ref= (ins-to i) (ins-arg1 i))
        (be-emitf (format nil "cmov~a %0, %=" suf0) i e)
        (progn (unless (ref= (ins-to i) (ins-arg0 i)) (be-emitf "mov %0, %=" i e))
               (be-emitf (format nil "cmov~a %1, %=" suf1) i e)))))

;;; ------------------------------------------------------- frame + prologue
(defun be-framesz (e)
  "amd64/emit.c sysv_framesz: stack bytes to reserve (locals + save parity)."
  (let* ((fn (es-fn e)) (o 0) (f (fn-slot fn)))
    (unless (es-leaf e)
      (loop for rc across *rclob* do (setf o (logxor o (ash (fn-reg fn) (- rc)))))
      (setf o (logand o 1)))
    (setf f (logand (+ f 3) -4))
    (when (and (> f 0) (= (es-fp e) +rsp+) (= (fn-salign fn) 4)) (incf f 2))
    (setf (es-fsz e) (+ (* 4 f) (* 8 o) (* 176 (if (fn-vararg fn) 1 0))))))

(defun be-emit-epilogue (e)
  (let ((s (es-stream e)) (fn (es-fn e)))
    (loop for k from (1- (length *rclob*)) downto 0
          for rc = (aref *rclob* k)
          when (logbitp rc (fn-reg fn))
          do (format s "~Cpopq %~a~%" #\Tab (regtoa rc +slong+)))
    (cond ((= (es-fp e) +rbp+) (format s "~Cleave~%" #\Tab))
          ((> (es-fsz e) 0) (format s "~Caddq $~d, %rsp~%" #\Tab (es-fsz e))))
    (format s "~Cret~%" #\Tab)))

(defun be-emit-jmp (b e id0)
  "Emit B's terminator; return the lbl flag for the next block (emit.c switch)."
  (let ((s (es-stream e)))
    (case (blk-jmp-type b)
      (:hlt (format s "~Cud2~%" #\Tab) t)
      (:ret0 (be-emit-epilogue e) t)
      (:jmp (cond ((not (eq (blk-s1 b) (blk-link b)))
                   (format s "~Cjmp .Lbb~d~%" #\Tab (+ id0 (blk-id (blk-s1 b)))) t)
                  (t nil)))
      (t (let ((c (gethash (blk-jmp-type b) *jf-jump-code*)) (n 1))
           (unless c (error "emit: unhandled jump ~s" (blk-jmp-type b)))
           (if (eq (blk-link b) (blk-s2 b))
               (progn (rotatef (blk-s1 b) (blk-s2 b)) (setf n 0))
               (setf n 1))
           (format s "~Cj~a .Lbb~d~%" #\Tab (aref (aref *cc-suffix* c) n) (+ id0 (blk-id (blk-s2 b))))
           (cond ((not (eq (blk-s1 b) (blk-link b)))
                  (format s "~Cjmp .Lbb~d~%" #\Tab (+ id0 (blk-id (blk-s1 b)))) t)
                 (t nil)))))))

(defun be-emit-fn (fn stream id0)
  "Emit one function's assembly; returns the next label counter (id0)."
  (let* ((leaf (notany (lambda (b) (some (lambda (i) (eq (ins-op i) :call)) (blk-ins b)))
                       (fn-blocks fn)))
         (e (make-es :stream stream :fn fn :leaf leaf)))
    (format stream ".text~%.balign 16~%")
    (when (fn-export fn) (format stream ".globl ~a~%" (fn-name fn)))
    (format stream "~a:~%~Cendbr64~%" (fn-name fn) #\Tab)
    (if (or (not leaf) (fn-vararg fn) (fn-dynalloc fn))
        (progn (setf (es-fp e) +rbp+)
               (format stream "~Cpushq %rbp~%~Cmovq %rsp, %rbp~%" #\Tab #\Tab))
        (setf (es-fp e) +rsp+))
    (be-framesz e)
    (when (> (es-fsz e) 0) (format stream "~Csubq $~d, %rsp~%" #\Tab (es-fsz e)))
    (loop for rc across *rclob*
          when (logbitp rc (fn-reg fn))
          do (format stream "~Cpushq %~a~%" #\Tab (regtoa rc +slong+))
             (incf (es-nclob e)))
    (let ((lbl nil))
      (loop for b = (fn-start fn) then (blk-link b) while b do
        (when (or lbl (> (length (blk-preds b)) 1))
          (when (some (lambda (p) (>= (blk-id p) (blk-id b))) (blk-preds b))
            (format stream ".p2align 4~%"))
          (format stream ".Lbb~d:~%" (+ id0 (blk-id b))))
        (dolist (i (blk-ins b)) (be-emitins i e))
        (setf lbl (be-emit-jmp b e id0))))
    (format stream ".type ~a, @function~%.size ~a, .-~a~%/* end function ~a */~%~%"
            (fn-name fn) (fn-name fn) (fn-name fn) (fn-name fn))
    (+ id0 (fn-nblk fn))))

;;; ------------------------------------------------------------ module driver
(defun be-backend-pipeline (fn)
  "Full amd64 backend (mirrors main.c for T.cansel=1), through simpljmp."
  (fill-cfg fn) (fill-use fn) (promote fn) (fill-use fn)
  (ssa fn) (fill-use fn)
  (gvn fn) (fill-cfg fn) (simplcfg fn)
  (fill-use fn) (fill-dom fn) (gcm fn) (fill-use fn)
  (ifconvert fn) (fill-cfg fn) (fill-use fn) (fill-dom fn)
  (amd64-abi fn) (simpl fn) (fill-cfg fn) (fill-use fn)
  (amd64-isel fn)
  (materialize-regs fn)
  (fill-cfg fn) (be-fill-live fn) (fill-loop fn) (fill-cost fn)
  (spill fn) (rega fn)
  (fill-cfg fn) (simpljmp fn) (fill-cfg fn))

(defun be-emit-module (module)
  "Run the backend per function and return the module's amd64 assembly string."
  (let ((s (make-string-output-stream)) (id0 0))
    (setf *tmp-counter* 0)
    (dolist (fn (module-funcs module))
      (be-backend-pipeline fn)
      (setf id0 (be-emit-fn fn s id0)))
    (format s ".section .note.GNU-stack,\"\",@progbits~%")
    (get-output-stream-string s)))
