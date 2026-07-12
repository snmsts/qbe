;;;; arm64-abi.lisp --- arm64 ABI lowering (G2), mirrors arm64/abi.c.
;;;;
;;;; Two passes, matching QBE's two `-dA` dumps for arm64_apple:
;;;;   abi0 = apple_extsb : "> After Apple pre-ABI:"  (sub-word ext insertion)
;;;;   abi1 = arm64_abi   : "> After ABI lowering:"   (params/returns/calls,
;;;;                         HFA + struct + stack + env + vararg)
;;;;
;;;; Like amd64-abi.lisp we reproduce QBE's backward `emit` by pushing onto
;;;; *emitted* in QBE's loop order, then reversing into the block.

(in-package #:qbe)

;;; ------------------------------------------------------------ abi0: extsb
;;; apple_extsb (arm64/abi.c): Apple passes/returns sub-word (b/h) scalars
;;; already sign/zero extended, so insert an ext{s,u}{b,h} around each argsb/
;;; argub/argsh/arguh call argument and each retsb/retub/retsh/retuh return.

(defparameter *argbh->ext*
  '((:argsb . :extsb) (:argub . :extub) (:argsh . :extsh) (:arguh . :extuh))
  "sub-word arg op -> the extension op that materializes its value.")

(defparameter *retbh->ext*
  '((:retsb . :extsb) (:retub . :extub) (:retsh . :extsh) (:retuh . :extuh))
  "sub-word ret terminator -> its extension op.")

(defun argbh-op-p (op) (and (assoc op *argbh->ext*) t))

(defun a64-apple-extsb (fn)
  "arm64/abi.c apple_extsb (abi0): extend sub-word call args and returns."
  (dolist (b (fn-blocks fn))
    (let ((*emitted* nil)
          (vec (coerce (blk-ins b) 'vector)))
      ;; return terminator: retbh -> ext into a fresh temp, then retw
      (let ((re (assoc (blk-jmp-type b) *retbh->ext*)))
        (when re
          (let ((r (newtmp "abi" :w fn)))
            (emit (cdr re) :w r (blk-jmp-arg b) nil)
            (setf (blk-jmp-arg b) r (blk-jmp-type b) :retw))))
      ;; walk instructions backward, re-emitting; around each call, extend its
      ;; sub-word args (QBE: replace argbh's result temp, feed the call the temp,
      ;; then emit the ext that fills it).
      (loop with k = (length vec) while (> k 0) do
        (decf k)
        (let ((i (aref vec k)))
          (cond
            ((eq (ins-op i) :call)
             ;; find the run of arg instructions [i0,k) preceding the call
             (let ((i0 k) (exts '()))
               (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0)))))
                     do (decf i0))
               ;; emit the call itself
               (push i *emitted*)
               ;; pass 1: emit args (k-1..i0).  For an argbh, thread its carried
               ;; value through a fresh Kl temp: the emitted arg now carries the
               ;; temp, and we remember (temp <- ext(original value)) for pass 2.
               (loop for j from (1- k) downto i0
                     for a = (aref vec j) do
                 (if (argbh-op-p (ins-op a))
                     (let ((r (newtmp "abi" :l fn)) (orig (ins-arg0 a)))
                       (setf (ins-arg0 a) r)
                       (push (list (cdr (assoc (ins-op a) *argbh->ext*)) r orig) exts))
                     nil)
                 (push a *emitted*))
               ;; pass 2: emit each ext (in the same backward order QBE uses)
               (dolist (e (nreverse exts))
                 (destructuring-bind (op r orig) e (emit op :w r orig nil)))
               (setf k i0)))
            (t (push i *emitted*)))))
      (setf (blk-ins b) *emitted*))))

;;; ------------------------------------------------------- abi1: register model
;;; arm64 register ids (arm64/all.h, RXX=0): R0=1..R7=8, R8=9 (indirect result),
;;; R9=10 (env), ..., SP=32, V0=33..V7=40.

(defconstant +a64-r0+ 1) (defconstant +a64-r8+ 9) (defconstant +a64-r9+ 10)
(defconstant +a64-sp+ 32) (defconstant +a64-v0+ 33)
(defconstant +a64-ngpr+ 32) (defconstant +a64-nfpr+ 31)  ; R0..SP (32), V0..V30 (31)

(defparameter *a64-reg-spec*
  (append (loop for i from 0 to 30 collect (cons (+ +a64-r0+ i)  ; R0..R28,FP,LR
                                                 (format nil "x~d" i)))
          (list (cons +a64-sp+ "sp"))
          (loop for i from 0 to 30 collect (cons (+ +a64-v0+ i)  ; V0..V30
                                                 (format nil "d~d" i))))
  "arm64 register id -> a display name (only the id matters for the -dA dump).")

(defparameter *arm64-regs*
  (let ((v (make-array (+ +a64-v0+ 31) :initial-element nil)))
    (loop for (id . name) in *a64-reg-spec*
          do (setf (aref v id) (make-reg id name (if (>= id +a64-v0+) :d :l))))
    v)
  "Vector: arm64 register id -> reg object.")

(defun a64rg (id) (aref *arm64-regs* id))
(defun a64-gpreg (n) (a64rg (+ +a64-r0+ n)))    ; nth GP arg register R<n>
(defun a64-fpreg (n) (a64rg (+ +a64-v0+ n)))    ; nth FP arg register V<n>

;;; -------------------------------------------------------- abi1: classes
;;; A Class records how one par/arg travels: in registers (reg[]/cls[] + nreg),
;;; on the stack (Cstk), or replaced by a pointer (Cptr).  arm64 aggregate
;;; classification is HFA-or-integer-eightbytes, NOT SysV eightbyte, and Apple
;;; passes non-KWIDE scalars in a 4-byte slot.

(defconstant +a64-cstk+ 1)   ; pass on the stack
(defconstant +a64-cptr+ 2)   ; replaced by a pointer to caller memory

(defstruct a64class
  (class 0) ishfa (hfa-base :x) (hfa-size 0)
  (size 8) (align 8) ty
  (nreg 0) (ngp 0) (nfp 0)
  (reg (make-array 4 :initial-element nil))   ; chosen register ids
  (cls (make-array 4 :initial-element :x)))   ; per-register class

;;; --------------------------------------------------- aggregate: isfloatv/typclass

(defun a64-isfloatv (ty base-cell)
  "arm64/abi.c isfloatv: t if TY is all-float with a single base class (Ks or
Kd), accumulated into BASE-CELL (a 1-element vector).  0 (nil) otherwise."
  (dotimes (n (typ-nunion ty) t)
    (loop for f across (aref (typ-fields ty) n) do
      (let ((ftype (car f)) (len (cdr f)))
        (case ftype
          (:pad nil)
          (:s (when (eq (aref base-cell 0) :d) (return-from a64-isfloatv nil))
              (setf (aref base-cell 0) :s))
          (:d (when (eq (aref base-cell 0) :s) (return-from a64-isfloatv nil))
              (setf (aref base-cell 0) :d))
          (:typ (unless (a64-isfloatv len base-cell)
                  (return-from a64-isfloatv nil)))
          (t (return-from a64-isfloatv nil)))))))

(defun a64-typclass (c ty gp0 fp0)
  "arm64/abi.c typclass: classify aggregate TY into C.  GP0/FP0 are the next
gp/fp arg-register indices; C's reg ids are assigned from there.  Does NOT
advance any shared counter — argsclass advances only when the aggregate fits
(mirroring the by-value pointer pass in C)."
  (let* ((sz (logand (+ (typ-size ty) 7) -8))
         (base (make-array 1 :initial-element :x)))
    (setf (a64class-ty c) ty (a64class-class c) 0
          (a64class-ngp c) 0 (a64class-nfp c) 0 (a64class-align c) 8)
    (when (> (typ-align ty) 3)
      (abi-unsupported "arm64 alignments larger than 8"))
    (setf (a64class-size c) sz)
    (let* ((ishfa (a64-isfloatv ty base))
           (hb (aref base 0))
           (hfasz (floor (typ-size ty) (if (kwide hb) 8 4))))
      (setf (a64class-hfa-base c) hb
            (a64class-ishfa c) (and ishfa (not (typ-isdark ty)) (<= hfasz 4))
            (a64class-hfa-size c) hfasz)
      (cond
        ((a64class-ishfa c)
         (dotimes (n hfasz)
           (setf (aref (a64class-reg c) n) (+ +a64-v0+ fp0 n)
                 (aref (a64class-cls c) n) hb)
           (incf (a64class-nfp c)))
         (setf (a64class-nreg c) hfasz))
        ((or (typ-isdark ty) (> sz 16) (= sz 0))
         ;; large structs: replaced by a pointer to caller-allocated memory
         (setf (a64class-class c) (logior (a64class-class c) +a64-cptr+)
               (a64class-size c) 8 (a64class-ngp c) 1
               (aref (a64class-reg c) 0) (+ +a64-r0+ gp0)
               (aref (a64class-cls c) 0) :l))
        (t
         (dotimes (n (floor sz 8))
           (setf (aref (a64class-reg c) n) (+ +a64-r0+ gp0 n)
                 (aref (a64class-cls c) n) :l)
           (incf (a64class-ngp c)))
         (setf (a64class-nreg c) (floor sz 8)))))))

;;; ---------------------------------------------------- aggregate: sttmps/ldregs

(defparameter *a64-store*
  (let ((v (make-array 4)))
    (setf (aref v (cls-code :w)) :storew (aref v (cls-code :l)) :storel
          (aref v (cls-code :s)) :stores (aref v (cls-code :d)) :stored)
    v)
  "arm64/abi.c store[]: class -> store op.")

(defun a64-sttmps (nreg cls-vec mem fn)
  "arm64/abi.c sttmps: emit stores of NREG fresh temps into MEM[0,8,..].
Returns the vector of fresh temps."
  (let ((tmp (make-array nreg)) (off 0))
    (dotimes (n nreg)
      (let ((tn (newtmp "abi" (aref cls-vec n) fn)) (r (newtmp "abi" :l fn)))
        (setf (aref tmp n) tn)
        (emit (aref *a64-store* (cls-code (aref cls-vec n))) :w nil tn r)
        (emit :add :l r mem (getcon off fn))
        (incf off (if (kwide (aref cls-vec n)) 8 4))))
    tmp))

(defun a64-ldregs (reg-vec cls-vec n mem fn)
  "arm64/abi.c ldregs: emit loads of MEM[0,8,..] into registers REG-VEC[0..n)."
  (let ((off 0))
    (dotimes (i n)
      (let ((r (newtmp "abi" :l fn)))
        (emit :load (aref cls-vec i) (a64rg (aref reg-vec i)) r nil)
        (emit :add :l r mem (getcon off fn))
        (incf off (if (kwide (aref cls-vec i)) 8 4))))))

(defun a64-stkblob (r c fn)
  "arm64/abi.c stkblob: an alloc ins reserving C's stack blob, defining R.
Returns the ins (caller hoists it into the start block, QBE's Insl list)."
  (let* ((al (max 0 (- (typ-align (a64class-ty c)) 2)))   ; NAlign == 3
         (sz (if (logtest (a64class-class c) +a64-cptr+)
                 (typ-size (a64class-ty c)) (a64class-size c))))
    (make-instance 'ins :op (a64-alloc-op al) :cls :l :to r
                   :arg0 (getcon sz fn) :arg1 nil)))

(defun a64-alloc-op (al)
  (if (<= 0 al 2) (aref #(:alloc4 :alloc8 :alloc16) al)
      (abi-unsupported "arm64 alloc align")))

(defun a64-align (x al) (logand (+ x al -1) (- al)))

;;; ----------------------------------------------------------- argsclass

(defun a64-argsclass (ins-list)
  "arm64/abi.c argsclass.  INS-LIST = par/arg ins.  Returns
(values cty class-vector env va)."
  (let ((ngp 8) (nfp 8) (gp (make-array 1 :initial-element 0))
        (fp (make-array 1 :initial-element 0))
        (va nil) (envc 0) (env nil)
        (cs (make-array (length ins-list))))
    (loop for i in ins-list for idx from 0 do
      (let* ((op (ins-op i)) (c (make-a64class)))
        (setf (aref cs idx) c)
        (flet ((scalar (size cls)
                 (setf (a64class-size c) size (a64class-align c) size
                       (aref (a64class-cls c) 0) cls)
                 (cond
                   (va (setf (a64class-class c) +a64-cstk+
                             (a64class-size c) 8 (a64class-align c) 8))
                   ((and (= (cls-base cls) 0) (> ngp 0))
                    (decf ngp)
                    (setf (aref (a64class-reg c) 0) (+ +a64-r0+ (aref gp 0)))
                    (incf (aref gp 0)))
                   ((and (= (cls-base cls) 1) (> nfp 0))
                    (decf nfp)
                    (setf (aref (a64class-reg c) 0) (+ +a64-v0+ (aref fp 0)))
                    (incf (aref fp 0)))
                   (t (setf (a64class-class c) +a64-cstk+)))))
          (case op
            ((:argsb :argub :parsb :parub) (scalar 1 :w))
            ((:argsh :arguh :parsh :paruh) (scalar 2 :w))
            ((:par :arg)
             (scalar (if (kwide (ins-cls i)) 8 4) (ins-cls i)))  ; apple: size 4 for non-wide
            ((:argc :parc)
             (a64-typclass c (ins-arg0 i) (aref gp 0) (aref fp 0))
             (cond
               ((<= (a64class-ngp c) ngp)
                (cond
                  ((<= (a64class-nfp c) nfp)
                   (decf ngp (a64class-ngp c)) (decf nfp (a64class-nfp c))
                   (incf (aref gp 0) (a64class-ngp c))
                   (incf (aref fp 0) (a64class-nfp c)))
                  (t (setf nfp 0
                           (a64class-class c) (logior (a64class-class c) +a64-cstk+)))))
               (t (setf ngp 0
                        (a64class-class c) (logior (a64class-class c) +a64-cstk+)))))
            ((:arge :pare)
             (setf (aref (a64class-reg c) 0) +a64-r9+ (aref (a64class-cls c) 0) :l
                   envc 1 env (if (eq op :pare) (ins-to i) (ins-arg0 i))))
            ((:argv) (setf va t))
            (t (abi-unsupported (format nil "arm64 arg op ~a" op)))))))
    ;; NB: QBE recomputes gp/fp deltas from pointer arithmetic; ngp/nfp above only
    ;; track *remaining* capacity, so cty uses the consumed counts (aref gp/fp 0).
    (values (logior (ash envc 14) (ash (aref gp 0) 5) (ash (aref fp 0) 9))
            cs env va)))

;;; RCall mask decoders (arm64/abi.c retregs/argregs); (values reg-ids ngp nfp).
(defun arm64-retregs (mask)
  (let ((ngp (logand mask 3)) (nfp (logand (ash mask -2) 7)) (regs '()))
    (dotimes (i ngp) (push (+ +a64-r0+ i) regs))
    (dotimes (i nfp) (push (+ +a64-v0+ i) regs))
    (values (nreverse regs) ngp nfp)))

(defun arm64-argregs (mask)
  (let ((ngp (logand (ash mask -5) 15)) (nfp (logand (ash mask -9) 15))
        (x8 (logand (ash mask -13) 1)) (x9 (logand (ash mask -14) 1)) (regs '()))
    (dotimes (i ngp) (push (+ +a64-r0+ i) regs))
    (dotimes (i nfp) (push (+ +a64-v0+ i) regs))
    (when (= x8 1) (push +a64-r8+ regs))
    (when (= x9 1) (push +a64-r9+ regs))
    (values (nreverse regs) (+ ngp x8 x9) nfp)))

;;; isargbh / isparbh (arm64/abi.c uses these to pick store/load widths).
(defun a64-isargbh (op) (member op '(:argsb :argub :argsh :arguh)))
(defun a64-isparbh (op) (member op '(:parsb :parub :parsh :paruh)))

;;; ------------------------------------------------------------ abi1: selret
(defun a64-selret (b fn)
  "arm64/abi.c selret: lower B's return terminator (scalar + aggregate)."
  (let ((j (blk-jmp-type b)))
    (when (and (isret-jmp j) (not (eq j :ret0)))
      (let ((r (blk-jmp-arg b)) (cty 0))
        (setf (blk-jmp-type b) :ret0)
        (if (eq j :retc)
            (let ((cr (make-a64class)))
              (a64-typclass cr (fn-rettyp fn) 0 0)
              (if (logtest (a64class-class cr) +a64-cptr+)
                  (progn                         ; large struct: blit into retr
                    (emit :blit1 :w nil (typ-size (a64class-ty cr)) nil)
                    (emit :blit0 :w nil r (fn-retr fn))
                    (setf cty 0))
                  (progn                         ; small struct: load into regs
                    (a64-ldregs (a64class-reg cr) (a64class-cls cr)
                                (a64class-nreg cr) r fn)
                    (setf cty (logior (ash (a64class-nfp cr) 2) (a64class-ngp cr))))))
            (let ((k (ecase j (:retw :w) (:retl :l) (:rets :s) (:retd :d))))
              (if (= (cls-base k) 0)
                  (progn (emit :copy k (a64rg +a64-r0+) r nil) (setf cty 1))
                  (progn (emit :copy k (a64rg +a64-v0+) r nil) (setf cty (ash 1 2))))))
        (setf (blk-jmp-arg b) (make-call-ref cty))))))

;;; ------------------------------------------------------------ abi1: selcall
(defun a64-selcall (fn args call ilp)
  "arm64/abi.c selcall: lower CALL with preceding ARGS.  Struct blobs (allocs)
are pushed onto ILP (a list cell in a 1-vector), hoisted into the start block."
  (multiple-value-bind (cty cs env va) (a64-argsclass args)
    (declare (ignore env va))
    (let ((argl (coerce args 'vector)) (stk 0))
      ;; Cptr args: replace with a pointer to a fresh stack blob; sum stack size.
      (dotimes (idx (length argl))
        (let ((i (aref argl idx)) (c (aref cs idx)))
          (when (logtest (a64class-class c) +a64-cptr+)
            (setf (ins-arg0 i) (newtmp "abi" :l fn))
            (push (a64-stkblob (ins-arg0 i) c fn) (aref ilp 0))
            (setf (ins-op i) :arg))
          (when (logtest (a64class-class c) +a64-cstk+)
            (setf stk (a64-align stk (a64class-align c)))
            (incf stk (a64class-size c)))))
      (setf stk (a64-align stk 16))
      (let ((rstk (getcon stk fn)))
        (when (/= stk 0) (emit :add :l (a64rg +a64-sp+) (a64rg +a64-sp+) rstk))
        ;; return handling
        (if (ins-arg1 call)
            (let ((cr (make-a64class)))
              (a64-typclass cr (ins-arg1 call) 0 0)
              (push (a64-stkblob (ins-to call) cr fn) (aref ilp 0))
              (setf cty (logior cty (ash (a64class-nfp cr) 2) (a64class-ngp cr)))
              (if (logtest (a64class-class cr) +a64-cptr+)
                  (progn                         ; dummy copy so spill/rega see it
                    (setf cty (logior cty (ash 1 13) 1))
                    (emit :copy :w nil (a64rg +a64-r0+) nil))
                  (let ((tmp (a64-sttmps (a64class-nreg cr) (a64class-cls cr)
                                         (ins-to call) fn)))
                    (dotimes (n (a64class-nreg cr))
                      (emit :copy (aref (a64class-cls cr) n) (aref tmp n)
                            (a64rg (aref (a64class-reg cr) n)) nil)))))
            (if (= (cls-base (ins-cls call)) 0)
                (progn (emit :copy (ins-cls call) (ins-to call) (a64rg +a64-r0+) nil)
                       (setf cty (logior cty 1)))
                (progn (emit :copy (ins-cls call) (ins-to call) (a64rg +a64-v0+) nil)
                       (setf cty (logior cty (ash 1 2))))))
        (emit :call :w nil (ins-arg0 call) (make-call-ref cty))
        (when (logtest cty (ash 1 13))           ; struct return argument in R8
          (emit :copy :l (a64rg +a64-r8+) (ins-to call) nil))
        ;; register args: copy each into its parameter register
        (dotimes (idx (length argl))
          (let ((i (aref argl idx)) (c (aref cs idx)))
            (unless (logtest (a64class-class c) +a64-cstk+)
              (when (or (member (ins-op i) '(:arg :arge)) (a64-isargbh (ins-op i)))
                (emit :copy (aref (a64class-cls c) 0) (a64rg (aref (a64class-reg c) 0))
                      (ins-arg0 i) nil))
              (when (eq (ins-op i) :argc)
                (a64-ldregs (a64class-reg c) (a64class-cls c) (a64class-nreg c)
                            (ins-arg1 i) fn)))))
        ;; populate the stack (Cstk args)
        (let ((off 0))
          (dotimes (idx (length argl))
            (let ((i (aref argl idx)) (c (aref cs idx)))
              (when (logtest (a64class-class c) +a64-cstk+)
                (setf off (a64-align off (a64class-align c)))
                (let ((r (newtmp "abi" :l fn)))
                  (if (or (eq (ins-op i) :arg) (a64-isargbh (ins-op i)))
                      (let ((op (case (a64class-size c)
                                  (1 :storeb) (2 :storeh)
                                  ((4 8) (aref *a64-store* (cls-code (aref (a64class-cls c) 0))))
                                  (t (abi-unsupported "arm64 stack arg size")))))
                        (emit op :w nil (ins-arg0 i) r))
                      (progn                     ; :argc — blit the struct onto the stack
                        (emit :blit1 :w nil (a64class-size c) nil)
                        (emit :blit0 :w nil (ins-arg1 i) r)))
                  (emit :add :l r (a64rg +a64-sp+) (getcon off fn))
                  (incf off (a64class-size c)))))))
        (when (/= stk 0) (emit :sub :l (a64rg +a64-sp+) (a64rg +a64-sp+) rstk))
        ;; Cptr args: blit caller value into the pointed-to blob
        (dotimes (idx (length argl))
          (let ((i (aref argl idx)) (c (aref cs idx)))
            (when (logtest (a64class-class c) +a64-cptr+)
              (emit :blit1 :w nil (typ-size (a64class-ty c)) nil)
              (emit :blit0 :w nil (ins-arg1 i) (ins-arg0 i)))))))))

;;; selpar's register-struct handling consumes sttmps' fresh temps in a second
;;; pass (QBE keeps them in a `tmp[]` array indexed by `t`).  We stash them on a
;;; FIFO produced by a64-sttmps-par (first pass) and drain it via a64-par-tmp
;;; (second pass); arm64-abi rebinds it per function.
(defvar *a64-par-tmps* nil "FIFO of sttmps-produced temps for register structs.")
(defun a64-sttmps-par (nreg cls-vec mem fn)
  (let ((tmp (a64-sttmps nreg cls-vec mem fn)))
    (dotimes (n nreg) (setf *a64-par-tmps* (nconc *a64-par-tmps* (list (aref tmp n)))))))
(defun a64-par-tmp () (pop *a64-par-tmps*))

;;; ------------------------------------------------------------ abi1: selpar
(defun a64-selpar (fn pars)
  "arm64/abi.c selpar: lower PARS (leading par run).  Returns (values stk ngp nfp)."
  (multiple-value-bind (cty cs env va) (a64-argsclass pars)
    (declare (ignore env va))
    (setf (fn-reg fn) (let ((m 0))
                        (dolist (rid (arm64-argregs cty) m)
                          (setf m (logior m (ash 1 rid))))))
    (let ((parl (coerce pars 'vector)) (il '()))
      ;; register-passed struct params: stash the reg halves into a fresh slot
      (dotimes (idx (length parl))
        (let ((i (aref parl idx)) (c (aref cs idx)))
          (when (and (eq (ins-op i) :parc)
                     (not (logtest (a64class-class c) (logior +a64-cptr+ +a64-cstk+))))
            (a64-sttmps-par (a64class-nreg c) (a64class-cls c) (ins-to i) fn)
            (push (a64-stkblob (ins-to i) c fn) il))))
      ;; hoist the struct-param allocs (QBE flushes the Insl list here, head
      ;; first — i.e. newest blob first, exactly as accumulated).
      (dolist (ins il) (push ins *emitted*))
      ;; struct return by pointer: caller passed the address in R8
      (when (fn-rettyp fn)
        (let ((cr (make-a64class)))
          (a64-typclass cr (fn-rettyp fn) 0 0)
          (when (logtest (a64class-class cr) +a64-cptr+)
            (setf (fn-retr fn) (newtmp "abi" :l fn))
            (emit :copy :l (fn-retr fn) (a64rg +a64-r8+) nil)
            (setf (fn-reg fn) (logior (fn-reg fn) (ash 1 +a64-r8+))))))
      (let ((off 0))
        (dotimes (idx (length parl))
          (let ((i (aref parl idx)) (c (aref cs idx)))
            (cond
              ((and (eq (ins-op i) :parc)
                    (not (logtest (a64class-class c) +a64-cptr+)))
               (if (logtest (a64class-class c) +a64-cstk+)
                   (progn (setf off (a64-align off (a64class-align c)))
                          (setf (tmp-slot (ins-to i)) (- (+ off 2)))
                          (incf off (a64class-size c)))
                   (dotimes (n (a64class-nreg c))
                     (emit :copy (aref (a64class-cls c) n) (a64-par-tmp)
                           (a64rg (aref (a64class-reg c) n)) nil))))
              ((logtest (a64class-class c) +a64-cstk+)
               (setf off (a64-align off (a64class-align c)))
               (let ((op (if (a64-isparbh (ins-op i))
                             (aref #(:loadsb :loadub :loadsh :loaduh)
                                   (position (ins-op i) #(:parsb :parub :parsh :paruh)))
                             :load)))
                 (emit op (aref (a64class-cls c) 0) (ins-to i)
                       (make-slot-ref (- (+ off 2))) nil))
               (incf off (a64class-size c)))
              (t (emit :copy (aref (a64class-cls c) 0) (ins-to i)
                       (a64rg (aref (a64class-reg c) 0)) nil)))))
        (values (a64-align off 8)
                (logand (ash cty -5) 15) (logand (ash cty -9) 15))))))

;;; ------------------------------------------------------------ abi1: vararg
;;; Apple's va_list is a single pointer into the on-stack overflow area (there
;;; is no register-save area), so apple_selvaarg / apple_selvastart need no
;;; block splitting — unlike the Linux arm64_selva* (deferred, error-stub).

(defun a64-apple-selvastart (fn stk ap)
  "arm64/abi.c apple_selvastart: init the va_list at AP to point past STK."
  (let ((off (getcon stk fn))
        (s (newtmp "abi" :l fn)) (arg (newtmp "abi" :l fn)))
    (emit :storel :w nil arg ap)                     ; storel arg, ap
    (emit :add :l arg s off)                         ; arg = add stk, off
    (emit :addr :l s (make-slot-ref -1) nil)))       ; stk = addr S-1

(defun a64-apple-selvaarg (fn i)
  "arm64/abi.c apple_selvaarg: load the next arg from AP, bump AP by 8."
  (let ((ap (ins-arg0 i)) (c8 (getcon 8 fn))
        (stk8 (newtmp "abi" :l fn)) (stk (newtmp "abi" :l fn)))
    (emit :storel :w nil stk8 ap)                    ; storel stk8, ap
    (emit :add :l stk8 stk c8)                        ; stk8 = add stk, 8
    (emit :load (ins-cls i) (ins-to i) stk nil)      ; i->to = load stk
    (emit :load :l stk ap nil)))                     ; stk = loadl ap

;;; ------------------------------------------------------------ abi1: driver
(defun ispar-a64 (op) (member op '(:par :parc :pare :parsb :parub :parsh :paruh)))

(defun arm64-abi (fn)
  "arm64/abi.c arm64_abi (abi1): lower params, returns, calls.  Rewrites FN."
  (dolist (b (fn-blocks fn)) (setf (blk-visit b) 0))
  (let ((il (make-array 1 :initial-element nil))   ; shared Insl (stkblob) list
        (*a64-par-tmps* nil) (pstk 0))              ; pstk = Params.stk for vastart
    ;; 1. lower parameters (leading par run of the start block)
    (let* ((start (fn-start fn)) (pars '()) (rest nil))
      (dolist (i (blk-ins start))
        (if (and (null rest) (ispar-a64 (ins-op i))) (push i pars) (push i rest)))
      (setf pars (nreverse pars) rest (nreverse rest))
      (let ((*emitted* nil))
        (setf pstk (a64-selpar fn pars))
        (setf (blk-ins start) (append *emitted* rest))))
    ;; 2. lower returns / calls / varargs; start block LAST, then flush `il`.
    (let* ((blocks (fn-blocks fn)) (start (car blocks)))
      (dolist (b (append (cdr blocks) (list start)))
        (let ((*emitted* nil) (vec (coerce (blk-ins b) 'vector)))
          (a64-selret b fn)
          (loop with k = (length vec) while (> k 0) do
            (decf k)
            (let ((i (aref vec k)))
              (cond
                ((eq (ins-op i) :call)
                 (let ((i0 k))
                   (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0))))) do (decf i0))
                   (a64-selcall fn (coerce (subseq vec i0 k) 'list) i il)
                   (setf k i0)))
                ((eq (ins-op i) :vastart) (a64-apple-selvastart fn pstk (ins-arg0 i)))
                ((eq (ins-op i) :vaarg) (a64-apple-selvaarg fn i))
                (t (push i *emitted*)))))
          ;; start block is processed last: flush accumulated stkblob allocs.
          ;; QBE iterates the Insl list head-first (newest blob first); each
          ;; emiti = push, so the list-head order is preserved verbatim.
          (when (eq b start)
            (dolist (ins (aref il 0)) (push ins *emitted*)))
          (setf (blk-ins b) *emitted*))))))
