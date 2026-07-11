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

(defun cls-base (k) (if (member k '(:w :l :m)) 0 1))  ; KBASE (Km == Kl)

;;; ------------------------------------------------------------ emission
;;; A tiny backward-emit reproduction: EMIT pushes onto *emitted*, so
;;; iterating in QBE's order yields QBE's final instruction order.
(defvar *emitted* nil)

(defun emit (op cls to a0 a1)
  (push (make-instance 'ins :op op :cls cls :to to :arg0 a0 :arg1 a1) *emitted*))

;;; ------------------------------------------------------- float-constant pool
;;; emit.c stashbits: floating-point constants can't be x86 immediates, so isel
;;; interns their bit patterns into a run-global (per-module) pool referenced by
;;; the local symbol `.LfpN`, emitted into .rodata by the module driver.
(defvar *stash* (make-array 0 :adjustable t :fill-pointer 0))
(defun reset-stash () (setf *stash* (make-array 0 :adjustable t :fill-pointer 0)))
(defun stashbits (n size)
  "Intern bit-pattern N at SIZE (4/8) into the fp pool; return its index."
  (dotimes (i (fill-pointer *stash*))
    (let ((b (aref *stash* i)))
      (when (and (<= size (cdr b)) (= (car b) n)) (return-from stashbits i))))
  (vector-push-extend (cons n size) *stash*)
  (1- (fill-pointer *stash*)))

;;; ---------------------------------------------------------------- abi1

(defun abi-unsupported (what)
  (error "qbe amd64 abi (M3/B1): unsupported ~a" what))

;;; ---------------------------------------------- SysV aggregate classification
;;; amd64/sysv.c AClass/typclass/classify: split an aggregate into up to two
;;; eightbytes, each classified INTEGER (:l) or SSE (:d), or force it in memory.

(defstruct (aclass (:constructor make-aclass))
  type (inmem 0) (align 0) (size 0)
  (cls (vector :x :x))            ; per-eightbyte class (:l / :d / :x empty)
  (ref (vector nil nil)))         ; abi-generated refs (selcall/selpar/selret)

(defun classify-into (a ty s)
  "sysv.c classify: fold TY's members (at byte offset S) into A's eightbytes."
  (dotimes (n (typ-nunion ty))
    (let ((s2 s))
      (loop for f across (aref (typ-fields ty) n) do
        (let ((ftype (car f)) (len (cdr f)))
          (ecase ftype
            (:pad (incf s2 len))
            ((:s :d)
             (when (eq (aref (aclass-cls a) (floor s2 8)) :x)
               (setf (aref (aclass-cls a) (floor s2 8)) :d))
             (incf s2 len))
            ((:b :h :w :l)
             (setf (aref (aclass-cls a) (floor s2 8)) :l)
             (incf s2 len))
            (:typ (classify-into a len s2) (incf s2 (typ-size len)))))))))

(defun typclass (ty)
  "sysv.c typclass: the AClass of aggregate type TY."
  (let* ((a (make-aclass :type ty :align (typ-align ty)))
         (al (max 8 (ash 1 (typ-align ty))))
         (sz (logand (+ (typ-size ty) al -1) (- al))))
    (setf (aclass-size a) sz)
    (if (or (typ-isdark ty) (> sz 16) (= sz 0))
        (setf (aclass-inmem a) 1)
        (progn (setf (aclass-inmem a) 0)
               (classify-into a ty 0)))
    a))

;;; ------------------------------------------------------------------ abi1
;;; amd64/sysv.c selpar/selcall/selret + rarg/argsclass/retr, faithful port:
;;; register + stack(overflow) + struct(by-reg/by-mem) params/args/returns +
;;; env.  Vararg (vastart/vaarg) is a later slice.  QBE emits backward; `emit`
;;; here pushes, so emitting in QBE's order yields QBE's final order.

(defvar *abi-ral* nil "Struct-return pad allocs, hoisted into the start block.")
(defvar *abi-fa* 0     "selpar's frame/arg descriptor (for a later vararg slice).")

(defun ispar-op (op) (member op '(:par :parc :pare :parsb :parub :parsh :paruh)))

(defun abi-rarg (k nins)
  "sysv.c rarg: next arg register for class K (NINS = #(ni ns), mutated)."
  (if (= (cls-base k) 0)
      (prog1 (rg (aref *sysv-int-args* (aref nins 0))) (incf (aref nins 0)))
      (prog1 (rg (+ +xmm0+ (aref nins 1))) (incf (aref nins 1)))))

(defun abi-retr (aret)
  "sysv.c retr: (values ca reg-vector) for aggregate return ARET."
  (let ((retreg #(#(1 3) #(17 18))) (nr (vector 0 0)) (ca 0) (regs (vector nil nil)))
    (loop for n from 0 while (< (* n 8) (aclass-size aret)) do
      (let ((k (cls-base (aref (aclass-cls aret) n))))
        (setf (aref regs n) (rg (aref (aref retreg k) (aref nr k))))
        (incf (aref nr k)) (incf ca (ash 1 (* 2 k)))))
    (values ca regs)))

(defun abi-argsclass (args aret parp)
  "sysv.c argsclass.  ARGS = arg/par ins list; ARET = aclass or NIL; PARP = t
   for parameters.  Returns (values ca aclass-vector env)."
  (let ((nint (if (and aret (= 1 (aclass-inmem aret))) 5 6))
        (nsse 8) (varc 0) (envc 0) (env nil) (acs (make-array (length args))))
    (loop for i in args for idx from 0 do
      (let ((op (ins-op i)))
        (cond
          ((member op '(:arg :par))
           (let ((a (make-aclass :align 3 :size 8)) (int (= (cls-base (ins-cls i)) 0)))
             (if (> (if int nint nsse) 0)
                 (progn (if int (decf nint) (decf nsse)) (setf (aclass-inmem a) 0))
                 (setf (aclass-inmem a) 2))
             (setf (aref (aclass-cls a) 0) (ins-cls i) (aref acs idx) a)))
          ((member op '(:argc :parc))
           (let ((a (typclass (ins-arg0 i))))
             (setf (aref acs idx) a)
             (unless (= 1 (aclass-inmem a))
               (let ((ni 0) (ns 0))
                 (loop for n from 0 while (< (* n 8) (aclass-size a)) do
                   (if (= (cls-base (aref (aclass-cls a) n)) 0) (incf ni) (incf ns)))
                 (if (and (>= nint ni) (>= nsse ns))
                     (progn (decf nint ni) (decf nsse ns))
                     (setf (aclass-inmem a) 1))))))
          ((member op '(:arge :pare))
           (setf envc 1 env (if parp (ins-to i) (ins-arg0 i)) (aref acs idx) (make-aclass)))
          ((eq op :argv) (setf varc 1 (aref acs idx) (make-aclass)))
          (t (abi-unsupported (format nil "abi arg op ~a" op))))))
    (when (and (= varc 1) (= envc 1)) (abi-unsupported "variadic env call"))
    (values (logior (ash (logior varc envc) 12) (ash (- 6 nint) 4) (ash (- 8 nsse) 8))
            acs env)))

(defun abi-alloc-op (al)
  (if (<= 0 al 2) (aref #(:alloc4 :alloc8 :alloc16) al) (abi-unsupported "alloc align")))

(defun sel-ret (b fn)
  "sysv.c selret: lower B's return terminator (scalar + aggregate)."
  (let ((j (blk-jmp-type b)))
    (when (and (isret-jmp j) (not (eq j :ret0)))
      (let ((r0 (blk-jmp-arg b)) (ca 0))
        (setf (blk-jmp-type b) :ret0)
        (if (eq j :retc)
            (let ((aret (typclass (fn-rettyp fn))))
              (if (= 1 (aclass-inmem aret))
                  (progn
                    (emit :copy :l (rg +rax+) (fn-retr fn) nil)
                    (emit :blit1 :w nil (typ-size (aclass-type aret)) nil)
                    (emit :blit0 :w nil r0 (fn-retr fn))
                    (setf ca 1))
                  (multiple-value-bind (c regs) (abi-retr aret)
                    (setf ca c)
                    (when (> (aclass-size aret) 8)
                      (let ((r (newtmp "abi" :l fn)))
                        (emit :load :l (aref regs 1) r nil)
                        (emit :add :l r r0 (getcon 8 fn))))
                    (emit :load :l (aref regs 0) r0 nil))))
            (let ((k (ecase j (:retw :w) (:retl :l) (:rets :s) (:retd :d))))
              (if (= (cls-base k) 0)
                  (progn (emit :copy k (rg +rax+) r0 nil) (setf ca 1))
                  (progn (emit :copy k (rg +xmm0+) r0 nil) (setf ca (ash 1 2))))))
        (setf (blk-jmp-arg b) (make-call-ref ca))))))

(defun sel-call (fn args call)
  "sysv.c selcall: lower CALL with its preceding ARGS (source order)."
  (let* ((aret (and (ins-arg1 call) (typclass (ins-arg1 call))))
         (cae (multiple-value-list (abi-argsclass args aret nil)))
         (ca (first cae)) (acs (second cae)) (env (third cae))
         (argl (coerce args 'vector)) (stk 0) (hidden nil))
    ;; stack size for inmem args
    (loop for idx from (1- (length argl)) downto 0
          for a = (aref acs idx) do
      (when (/= 0 (aclass-inmem a))
        (when (> (aclass-align a) 4) (abi-unsupported "alignment > 16"))
        (incf stk (aclass-size a))
        (when (= (aclass-align a) 4) (incf stk (logand stk 15)))))
    (incf stk (logand stk 15))
    (when (/= stk 0) (emit :salloc :l nil (getcon (- stk) fn) nil))
    ;; return handling
    (if aret
        (if (= 1 (aclass-inmem aret))
            ;; inmem: caller allocates the return pad (a fresh temp), passes its
            ;; address as a hidden arg, and reads the returned pointer from RAX.
            (let ((r1 (newtmp "abi" :l fn)))
              (emit :copy :l (ins-to call) (rg +rax+) nil) (incf ca 1)
              (setf hidden r1) (abi-push-ral fn aret r1))
            (progn
              (when (> (aclass-size aret) 8)
                (let ((r (newtmp "abi" :l fn)))
                  (setf (aref (aclass-ref aret) 1) (newtmp "abi" (aref (aclass-cls aret) 1) fn))
                  (emit :storel :w nil (aref (aclass-ref aret) 1) r)
                  (emit :add :l r (ins-to call) (getcon 8 fn))))
              (setf (aref (aclass-ref aret) 0) (newtmp "abi" (aref (aclass-cls aret) 0) fn))
              (emit :storel :w nil (aref (aclass-ref aret) 0) (ins-to call))
              (multiple-value-bind (c regs) (abi-retr aret)
                (incf ca c)
                (when (> (aclass-size aret) 8)
                  (emit :copy (aref (aclass-cls aret) 1) (aref (aclass-ref aret) 1) (aref regs 1) nil))
                (emit :copy (aref (aclass-cls aret) 0) (aref (aclass-ref aret) 0) (aref regs 0) nil))
              (abi-push-ral fn aret (ins-to call))))
        (if (= (cls-base (ins-cls call)) 0)
            (progn (emit :copy (ins-cls call) (ins-to call) (rg +rax+) nil) (incf ca 1))
            (progn (emit :copy (ins-cls call) (ins-to call) (rg +xmm0+) nil) (incf ca (ash 1 2)))))
    (emit :call (ins-cls call) nil (ins-arg0 call) (make-call-ref ca))
    (cond
      (env (emit :copy :l (rg +rax+) env nil))
      ((= 1 (logand (ash ca -12) 1))
       (emit :copy :w (rg +rax+) (getcon (logand (ash ca -8) 15) fn) nil)))
    (let ((nins (vector 0 0)))
      (when (and aret (= 1 (aclass-inmem aret)))
        (emit :copy :l (abi-rarg :l nins) hidden nil))
      (dotimes (idx (length argl))
        (let ((i (aref argl idx)) (a (aref acs idx)))
          (unless (or (member (ins-op i) '(:arge :argv)) (/= 0 (aclass-inmem a)))
            (let ((r1 (abi-rarg (aref (aclass-cls a) 0) nins)))
              (if (eq (ins-op i) :argc)
                  (progn
                    (when (> (aclass-size a) 8)
                      (let ((r2 (abi-rarg (aref (aclass-cls a) 1) nins)) (r (newtmp "abi" :l fn)))
                        (emit :load (aref (aclass-cls a) 1) r2 r nil)
                        (emit :add :l r (ins-arg1 i) (getcon 8 fn))))
                    (emit :load (aref (aclass-cls a) 0) r1 (ins-arg1 i) nil))
                  (emit :copy (ins-cls i) r1 (ins-arg0 i) nil)))))))
    (when (/= stk 0)
      (let ((r (newtmp "abi" :l fn)) (off 0))
        (dotimes (idx (length argl))
          (let ((i (aref argl idx)) (a (aref acs idx)))
            (when (and (not (member (ins-op i) '(:arge :argv))) (/= 0 (aclass-inmem a)))
              (let ((r1 (newtmp "abi" :l fn)))
                (if (eq (ins-op i) :argc)
                    (progn
                      (when (= (aclass-align a) 4) (incf off (logand off 15)))
                      (emit :blit1 :w nil (typ-size (aclass-type a)) nil)
                      (emit :blit0 :w nil (ins-arg1 i) r1))
                    (emit :storel :w nil (ins-arg0 i) r1))
                (emit :add :l r1 r (getcon off fn))
                (incf off (aclass-size a))))))
        (emit :salloc :l r (getcon stk fn) nil)))))

(defun abi-push-ral (fn aret loc)
  "sysv.c RAlloc: stash a struct-return pad alloc (to LOC) for the start block."
  (let ((al (if (>= (aclass-align aret) 2) (- (aclass-align aret) 2) 0)))
    (push (make-instance 'ins :op (abi-alloc-op al) :cls :l :to loc
                         :arg0 (getcon (aclass-size aret) fn) :arg1 nil)
          *abi-ral*)))

(defun sel-par (fn pars)
  "sysv.c selpar: lower PARS (the leading par ins); returns the fa descriptor."
  (let* ((aret (and (fn-rettyp fn) (typclass (fn-rettyp fn))))
         (nins (vector 0 0)))
    (multiple-value-bind (fa acs env) (abi-argsclass pars aret t)
      (setf (fn-reg fn)
            (let ((m 0)) (dolist (r (sysv-argregs fa) m) (setf m (logior m (ash 1 r))))))
      ;; aggregate params passed in registers: alloc a slot + store the halves
      (loop for i in pars for idx from 0
            for a = (aref acs idx) do
        (when (and (eq (ins-op i) :parc) (= 0 (aclass-inmem a)))
          (when (> (aclass-size a) 8)
            (let ((r (newtmp "abi" :l fn)))
              (setf (aref (aclass-ref a) 1) (newtmp "abi" :l fn))
              (emit :storel :w nil (aref (aclass-ref a) 1) r)
              (emit :add :l r (ins-to i) (getcon 8 fn))))
          (setf (aref (aclass-ref a) 0) (newtmp "abi" :l fn))
          (emit :storel :w nil (aref (aclass-ref a) 0) (ins-to i))
          (let ((al (if (>= (aclass-align a) 2) (- (aclass-align a) 2) 0)))
            (emit (abi-alloc-op al) :l (ins-to i) (getcon (aclass-size a) fn) nil))))
      (when (and aret (= 1 (aclass-inmem aret)))
        (let ((r (newtmp "abi" :l fn)))
          (emit :copy :l r (abi-rarg :l nins) nil)
          (setf (fn-retr fn) r)))
      (let ((s 4))
        (loop for i in pars for idx from 0
              for a = (aref acs idx) do
          (case (aclass-inmem a)
            (1 (when (> (aclass-align a) 4) (abi-unsupported "alignment > 16"))
               (when (= (aclass-align a) 4) (setf s (logand (+ s 3) -4)))
               (setf (tmp-slot (ins-to i)) (- s))
               (incf s (floor (aclass-size a) 4)))
            (2 (emit :load (ins-cls i) (ins-to i) (make-slot-ref (- s)) nil)
               (incf s 2))
            (t
             (unless (eq (ins-op i) :pare)
               (let ((r (abi-rarg (aref (aclass-cls a) 0) nins)))
                 (if (eq (ins-op i) :parc)
                     (progn
                       (emit :copy (aref (aclass-cls a) 0) (aref (aclass-ref a) 0) r nil)
                       (when (> (aclass-size a) 8)
                         (emit :copy (aref (aclass-cls a) 1) (aref (aclass-ref a) 1)
                               (abi-rarg (aref (aclass-cls a) 1) nins) nil)))
                     (emit :copy (ins-cls i) (ins-to i) r nil)))))))
        (when env (emit :copy :l env (rg +rax+) nil))
        (logior fa (ash (* s 4) 12))))))


;;; ------------------------------------------------------------------ vararg
;;; sysv.c split/chpred/selvastart/selvaarg: lower va_start and va_arg.  va_arg
;;; splits its block into a register-save-area path and an overflow path joined
;;; by a phi (`split` flushes the current emit buffer into a fresh block).

(defun abi-chpred (b bp bp1)
  "sysv.c chpred: rename predecessor BP to BP1 in B's phis."
  (dolist (p (blk-phis b))
    (let ((cell (assoc bp (phi-args p) :test #'eq)))
      (when cell (setf (car cell) bp1)))))

(defun abi-split (fn b)
  "sysv.c split: make the current emit buffer a fresh block linked after B."
  (incf (fn-nblk fn))
  (let ((bn (make-instance 'blk)))
    (setf (blk-ins bn) *emitted* *emitted* nil)
    (incf (blk-visit b))
    (setf (blk-visit bn) (blk-visit b)
          (blk-name bn) (format nil "~a.~d" (blk-name b) (blk-visit b))
          (blk-loop bn) (blk-loop b)
          (blk-link bn) (blk-link b) (blk-link b) bn)
    (let ((cell (member b (fn-blocks fn) :test #'eq)))
      (setf (cdr cell) (cons bn (cdr cell))))
    bn))

(defun sel-vastart (fn fa ap)
  "sysv.c selvastart: initialise the va_list at AP (gp/fp/overflow pointers)."
  (let ((gp (* (logand (ash fa -4) 15) 8))
        (fp (+ 48 (* (logand (ash fa -8) 15) 16)))
        (sp (ash fa -12)))
    (let ((r0 (newtmp "abi" :l fn)) (r1 (newtmp "abi" :l fn)))
      (emit :storel :w nil r1 r0)
      (emit :add :l r1 (rg 15) (getcon -176 fn))     ; RBP - 176 (reg save area)
      (emit :add :l r0 ap (getcon 16 fn)))
    (let ((r0 (newtmp "abi" :l fn)) (r1 (newtmp "abi" :l fn)))
      (emit :storel :w nil r1 r0)
      (emit :add :l r1 (rg 15) (getcon sp fn))
      (emit :add :l r0 ap (getcon 8 fn)))
    (let ((r0 (newtmp "abi" :l fn)))
      (emit :storew :w nil (getcon fp fn) r0)
      (emit :add :l r0 ap (getcon 4 fn)))
    (emit :storew :w nil (getcon gp fn) ap)))

(defun sel-vaarg (fn b i)
  "sysv.c selvaarg: lower va_arg, splitting B into reg/stack paths + a phi."
  (let* ((ap (ins-arg0 i)) (isint (= (cls-base (ins-cls i)) 0))
         (c4 (getcon 4 fn)) (c8 (getcon 8 fn)) (c16 (getcon 16 fn))
         (z (getcon 0 fn)) (loc (newtmp "abi" :l fn)))
    (emit :load (ins-cls i) (ins-to i) loc nil)
    (let ((b0 (abi-split fn b)))
      (setf (blk-jmp-type b0) (blk-jmp-type b) (blk-jmp-arg b0) (blk-jmp-arg b)
            (blk-s1 b0) (blk-s1 b) (blk-s2 b0) (blk-s2 b))
      (when (blk-s1 b) (abi-chpred (blk-s1 b) b b0))
      (when (and (blk-s2 b) (not (eq (blk-s2 b) (blk-s1 b)))) (abi-chpred (blk-s2 b) b b0))
      (let ((lreg (newtmp "abi" :l fn)) (nr (newtmp "abi" :l fn))
            (r0 (newtmp "abi" :w fn)) (r1 (newtmp "abi" :l fn)))
        (emit :storew :w nil r0 r1)
        (emit :add :l r1 ap (if isint z c4))
        (emit :add :w r0 nr (if isint c8 c16))
        (let ((r0b (newtmp "abi" :l fn)) (r1b (newtmp "abi" :l fn)))
          (emit :add :l lreg r1b nr)
          (emit :load :l r1b r0b nil)
          (emit :add :l r0b ap c16))
        (let ((breg (abi-split fn b)))
          (setf (blk-jmp-type breg) :jmp (blk-s1 breg) b0 (blk-s2 breg) nil)
          (let ((lstk (newtmp "abi" :l fn)) (r0 (newtmp "abi" :l fn)) (r1 (newtmp "abi" :l fn)))
            (emit :storel :w nil r1 r0)
            (emit :add :l r1 lstk c8)
            (emit :load :l lstk r0 nil)
            (emit :add :l r0 ap c8)
            (let ((bstk (abi-split fn b)))
              (setf (blk-jmp-type bstk) :jmp (blk-s1 bstk) b0 (blk-s2 bstk) nil)
              (setf (blk-phis b0)
                    (list (make-instance 'phi :to loc :cls :l
                                         :args (list (cons bstk lstk) (cons breg lreg)))))
              (let ((r0 (newtmp "abi" :l fn)) (r1 (newtmp "abi" :w fn)))
                (setf (blk-jmp-type b) :jnz (blk-jmp-arg b) r1
                      (blk-s1 b) breg (blk-s2 b) bstk)
                (emit :cultw :w r1 nr (getcon (if isint 48 176) fn))
                (emit :loadsw :l nr r0 nil)
                (emit :add :l r0 ap (if isint z c4))))))))))

(defun amd64-abi (fn)
  "amd64 SysV abi1 (B2: register + stack + struct + env + vararg).  Rewrites FN."
  (dolist (b (fn-blocks fn)) (setf (blk-visit b) 0))
  (let ((*abi-ral* nil) (*abi-fa* 0))
    ;; 1. lower parameters
    (let* ((start (fn-start fn)) (pars '()) (rest nil))
      (dolist (i (blk-ins start))
        (if (and (null rest) (ispar-op (ins-op i))) (push i pars) (push i rest)))
      (setf pars (nreverse pars) rest (nreverse rest))
      (let ((*emitted* nil))
        (setf *abi-fa* (sel-par fn pars))
        (setf (blk-ins start) (append *emitted* rest))))
    ;; 2. lower returns, calls (and later varargs); start block processed LAST so
    ;; the accumulated struct-return pad allocs land at its head.
    (let* ((blocks (fn-blocks fn)) (start (car blocks)))
      (dolist (b (append (cdr blocks) (list start)))
        (let ((*emitted* nil) (vec (coerce (blk-ins b) 'vector)))
          (sel-ret b fn)
          (loop with k = (length vec) while (> k 0) do
            (decf k)
            (let ((i (aref vec k)))
              (cond
                ((eq (ins-op i) :call)
                 (let ((i0 k))
                   (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0))))) do (decf i0))
                   (sel-call fn (coerce (subseq vec i0 k) 'list) i)
                   (setf k i0)))
                ((eq (ins-op i) :vastart) (sel-vastart fn *abi-fa* (ins-arg0 i)))
                ((eq (ins-op i) :vaarg) (sel-vaarg fn b i))
                (t (push i *emitted*)))))
          (when (eq b start)
            (dolist (ra *abi-ral*) (push ra *emitted*)))
          (setf (blk-ins b) *emitted*))))))
