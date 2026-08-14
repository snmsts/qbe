;;;; rv64-abi.lisp --- RISC-V 64 (LP64D) ABI lowering, mirrors rv64/abi.c.
;;;;
;;;; abi0 is the shared elimsb (like arm64 ELF: sub-word arg/par/ret forms carry
;;;; no ABI meaning on Linux, the C type system extends).  abi1 = rv64-abi below:
;;;; params/returns/calls under the LP64D calling convention -- two-field
;;;; flattening of small aggregates (fpstruct), the float-in-GPR overflow rule
;;;; (Cfpint), register/stack splits (Cstk1/Cstk2), and the 64-byte vararg
;;;; register save area.
;;;;
;;;; As elsewhere QBE emits backward; `emit` pushes onto *emitted* so emitting
;;;; in QBE's loop order yields QBE's final block order.

(in-package #:qbe)

;;; ------------------------------------------------------- register-model ids
;;; rv64/all.h enum Rv64Reg (RXX=0): T0=1..T5=6, A0=7..A7=14, S1=15..S11=25,
;;; FP=26, SP=27, GP=28, TP=29, RA=30, FT0=31..FT10=41, FA0=42..FA7=49,
;;; FS0=50..FS11=61, T6=62, FT11=63.  FT11 < Tmp0 = 64, a perfect fit.
(defconstant +rv-t0+ 1) (defconstant +rv-t5+ 6)
(defconstant +rv-a0+ 7) (defconstant +rv-a7+ 14)
(defconstant +rv-s1+ 15) (defconstant +rv-s11+ 25)
(defconstant +rv-fp+ 26) (defconstant +rv-sp+ 27)
(defconstant +rv-gp+ 28) (defconstant +rv-tp+ 29) (defconstant +rv-ra+ 30)
(defconstant +rv-ft0+ 31) (defconstant +rv-ft10+ 41)
(defconstant +rv-fa0+ 42) (defconstant +rv-fa7+ 49)
(defconstant +rv-fs0+ 50) (defconstant +rv-fs11+ 61)
(defconstant +rv-t6+ 62) (defconstant +rv-ft11+ 63)

(defconstant +rv-ngpr+ 30 "NGPR = RA - T0 + 1: T0..RA are allocatable ids.")
(defconstant +rv-nfpr+ 31 "NFPR = FS11 - FT0 + 1 (T6/FT11 stay reserved).")

(defparameter *rv64-reg-names*
  (let ((v (make-array 64 :initial-element nil)))
    (loop for id from +rv-t0+ to +rv-t5+
          for n from 0 do (setf (aref v id) (format nil "t~d" n)))
    (loop for id from +rv-a0+ to +rv-a7+
          for n from 0 do (setf (aref v id) (format nil "a~d" n)))
    (loop for id from +rv-s1+ to +rv-s11+
          for n from 1 do (setf (aref v id) (format nil "s~d" n)))
    (setf (aref v +rv-fp+) "fp" (aref v +rv-sp+) "sp" (aref v +rv-gp+) "gp"
          (aref v +rv-tp+) "tp" (aref v +rv-ra+) "ra")
    (loop for id from +rv-ft0+ to +rv-ft10+
          for n from 0 do (setf (aref v id) (format nil "ft~d" n)))
    (loop for id from +rv-fa0+ to +rv-fa7+
          for n from 0 do (setf (aref v id) (format nil "fa~d" n)))
    (loop for id from +rv-fs0+ to +rv-fs11+
          for n from 0 do (setf (aref v id) (format nil "fs~d" n)))
    (setf (aref v +rv-t6+) "t6" (aref v +rv-ft11+) "ft11")
    v)
  "rv64/emit.c rname: register id -> assembler name.")

(defparameter *rv64-regs*
  (let ((v (make-array 64 :initial-element nil)))
    (dotimes (id 64 v)
      (let ((name (aref *rv64-reg-names* id)))
        (when name
          (setf (aref v id)
                (make-reg id name (if (>= id +rv-ft0+) :d :l)))))))
  "Vector: rv64 register id -> reg object.")

(defun rvrg (id) (aref *rv64-regs* id))

;;; rv64/abi.c gpreg/fpreg: the argument register sequences.  Padded to 10 like
;;; the C arrays -- typclass may peek one past the last valid entry while
;;; classifying an aggregate that ends up on the stack; the value is never used.
(defparameter *rv-gpreg*
  (coerce (append (loop for i from +rv-a0+ to +rv-a7+ collect i) '(0 0)) 'vector))
(defparameter *rv-fpreg*
  (coerce (append (loop for i from +rv-fa0+ to +rv-fa7+ collect i) '(0 0)) 'vector))

;;; --------------------------------------------------- RCall mask decoders
;;; layout of call's second argument (rv64/abi.c):
;;;   bit 12: env pointer passed in t5;  bits 8-11: fp regs passed (0..8);
;;;   bits 4-7: gp regs passed (0..8);  bits 2-3: fp returned;  bits 0-1: gp.
(defun rv64-retregs (mask)
  (let ((ngp (logand mask 3)) (nfp (logand (ash mask -2) 3)) (regs '()))
    (dotimes (i ngp) (push (+ +rv-a0+ i) regs))
    (dotimes (i nfp) (push (+ +rv-fa0+ i) regs))
    (values (nreverse regs) ngp nfp)))

(defun rv64-argregs (mask)
  (let ((ngp (logand (ash mask -4) 15)) (nfp (logand (ash mask -8) 15))
        (t5 (logand (ash mask -12) 1)) (regs '()))
    (dotimes (i ngp) (push (+ +rv-a0+ i) regs))
    (dotimes (i nfp) (push (+ +rv-fa0+ i) regs))
    (when (= t5 1) (push +rv-t5+ regs))
    (values (nreverse regs) (+ ngp t5) nfp)))

;;; -------------------------------------------------------------- Class
;;; rv64/abi.c Class flags: how one par/arg travels.
(defconstant +rv-cptr+ 1)    ; replaced by a pointer
(defconstant +rv-cstk1+ 2)   ; pass first XLEN on the stack
(defconstant +rv-cstk2+ 4)   ; pass second XLEN on the stack
(defconstant +rv-cstk+ (logior +rv-cstk1+ +rv-cstk2+))
(defconstant +rv-cfpint+ 8)  ; float passed like integer

(defstruct rvclass
  (class 0) ty
  (reg (make-array 2 :initial-element 0))
  (cls (make-array 2 :initial-element :x))
  (off (make-array 2 :initial-element 0))
  (ngp 0) (nfp 0) (nreg 0))

;;; ----------------------------------------------------- fpstruct / typclass

(defun rv-fpstruct (ty off c)
  "rv64/abi.c fpstruct: flatten TY's scalar fields (at byte offset OFF) into
C's two slots.  Returns C's nfp, or -1 when the type cannot use the fp ABI
(union, or more than two scalar fields)."
  (when (typ-isunion ty) (return-from rv-fpstruct -1))
  (loop for f across (aref (typ-fields ty) 0) do
    (let ((ftype (car f)) (len (cdr f)))
      (case ftype
        (:pad (incf off len))
        (:typ (when (= -1 (rv-fpstruct len off c))
                (return-from rv-fpstruct -1))
              (incf off (typ-size len)))
        (t
         (let ((n (+ (rvclass-nfp c) (rvclass-ngp c))))
           (when (= n 2) (return-from rv-fpstruct -1))
           (ecase ftype
             ((:b :h :w) (setf (aref (rvclass-cls c) n) :w) (incf (rvclass-ngp c)))
             (:l (setf (aref (rvclass-cls c) n) :l) (incf (rvclass-ngp c)))
             (:s (setf (aref (rvclass-cls c) n) :s) (incf (rvclass-nfp c)))
             (:d (setf (aref (rvclass-cls c) n) :d) (incf (rvclass-nfp c))))
           (setf (aref (rvclass-off c) n) off)
           (incf off len))))))
  (rvclass-nfp c))

(defun rv-typclass (c ty fpabi gp0 fp0)
  "rv64/abi.c typclass: classify aggregate TY into C.  GP0/FP0 are the next
gp/fp arg-register indices (the caller's cursor; not advanced here)."
  (setf (rvclass-ty c) ty (rvclass-class c) 0
        (rvclass-ngp c) 0 (rvclass-nfp c) 0)
  (when (> (typ-align ty) 4)
    (abi-unsupported "rv64 alignments larger than 16"))
  (cond
    ((or (typ-isdark ty) (> (typ-size ty) 16) (= (typ-size ty) 0))
     ;; large structs are replaced by a pointer to caller-allocated memory
     (setf (rvclass-class c) (logior (rvclass-class c) +rv-cptr+)
           (aref (rvclass-cls c) 0) :l
           (aref (rvclass-off c) 0) 0
           (rvclass-ngp c) 1))
    ((or (not fpabi) (<= (rv-fpstruct ty 0 c) 0))
     (let ((n 0))
       (loop while (< (* 8 n) (typ-size ty)) do
         (setf (aref (rvclass-cls c) n) :l (aref (rvclass-off c) n) (* 8 n))
         (incf n))
       (setf (rvclass-nfp c) 0 (rvclass-ngp c) n))))
  (setf (rvclass-nreg c) (+ (rvclass-nfp c) (rvclass-ngp c)))
  (dotimes (i (rvclass-nreg c))
    (if (= (cls-base (aref (rvclass-cls c) i)) 0)
        (setf (aref (rvclass-reg c) i) (aref *rv-gpreg* gp0) gp0 (1+ gp0))
        (setf (aref (rvclass-reg c) i) (aref *rv-fpreg* fp0) fp0 (1+ fp0)))))

;;; ----------------------------------------------------- sttmps / ldregs

(defparameter *rv-store*
  (let ((v (make-array 4)))
    (setf (aref v (cls-code :w)) :storew (aref v (cls-code :l)) :storel
          (aref v (cls-code :s)) :stores (aref v (cls-code :d)) :stored)
    v)
  "rv64/abi.c st[]: class -> store op.")

(defun rv-sttmps (ntmp c mem fn)
  "rv64/abi.c sttmps: emit stores of NTMP fresh temps into MEM at C's offsets.
Returns the vector of fresh temps."
  (assert (<= 1 ntmp 2))
  (let ((tmp (make-array ntmp)))
    (dotimes (i ntmp tmp)
      (let ((tn (newtmp "abi" (aref (rvclass-cls c) i) fn))
            (r (newtmp "abi" :l fn)))
        (setf (aref tmp i) tn)
        (emit (aref *rv-store* (cls-code (aref (rvclass-cls c) i))) :w nil tn r)
        (emit :add :l r mem (getcon (aref (rvclass-off c) i) fn))))))

(defun rv-ldregs (c mem fn)
  "rv64/abi.c ldregs: emit loads of MEM at C's offsets into C's registers."
  (dotimes (i (rvclass-nreg c))
    (let ((r (newtmp "abi" :l fn)))
      (emit :load (aref (rvclass-cls c) i) (rvrg (aref (rvclass-reg c) i)) r nil)
      (emit :add :l r mem (getcon (aref (rvclass-off c) i) fn)))))

;;; ------------------------------------------------------------------ selret

(defun rv-selret (b fn)
  "rv64/abi.c selret: lower B's return terminator."
  (let ((j (blk-jmp-type b)))
    (when (and (isret-jmp j) (not (eq j :ret0)))
      (let ((r (blk-jmp-arg b)) (cty 0))
        (setf (blk-jmp-type b) :ret0)
        (if (eq j :retc)
            (let ((cr (make-rvclass)))
              (rv-typclass cr (fn-rettyp fn) t 0 0)
              (if (logtest (rvclass-class cr) +rv-cptr+)
                  (progn
                    (assert (tmp-p (fn-retr fn)))
                    (emit :blit1 :w nil (typ-size (rvclass-ty cr)) nil)
                    (emit :blit0 :w nil r (fn-retr fn))
                    (setf cty 0))
                  (progn
                    (rv-ldregs cr r fn)
                    (setf cty (logior (ash (rvclass-nfp cr) 2) (rvclass-ngp cr))))))
            (let ((k (ecase j (:retw :w) (:retl :l) (:rets :s) (:retd :d))))
              (if (= (cls-base k) 0)
                  (progn (emit :copy k (rvrg +rv-a0+) r nil) (setf cty 1))
                  (progn (emit :copy k (rvrg +rv-fa0+) r nil) (setf cty (ash 1 2))))))
        (setf (blk-jmp-arg b) (make-call-ref cty))))))

;;; --------------------------------------------------------------- argsclass

(defun rv-argsclass (ins-list retptr)
  "rv64/abi.c argsclass: classify the par/arg run INS-LIST.  RETPTR skips A0
for the hidden aggregate-return pointer.  Returns (values cty class-vector)."
  (let ((gpi 0) (fpi 0) (ngp 8) (nfp 8) (va nil) (envc 0)
        (cs (make-array (length ins-list))))
    (when retptr (incf gpi) (decf ngp))
    (loop for i in ins-list for idx from 0 do
      (let ((c (make-rvclass)) (op (ins-op i)))
        (setf (aref cs idx) c)
        (case op
          ((:par :arg)
           (setf (aref (rvclass-cls c) 0) (ins-cls i))
           (cond
             ((and (not va) (= (cls-base (ins-cls i)) 1) (> nfp 0))
              (decf nfp)
              (setf (aref (rvclass-reg c) 0) (aref *rv-fpreg* fpi))
              (incf fpi))
             ((> ngp 0)
              (when (= (cls-base (ins-cls i)) 1)
                (setf (rvclass-class c) (logior (rvclass-class c) +rv-cfpint+)))
              (decf ngp)
              (setf (aref (rvclass-reg c) 0) (aref *rv-gpreg* gpi))
              (incf gpi))
             (t (setf (rvclass-class c) (logior (rvclass-class c) +rv-cstk1+)))))
          (:argv (setf va t))
          ((:parc :argc)
           (let ((ty (ins-arg0 i)))
             (rv-typclass c ty t gpi fpi)
             (when (and (> (rvclass-nfp c) 0)
                        (or (>= (rvclass-nfp c) nfp) (>= (rvclass-ngp c) ngp)))
               (rv-typclass c ty nil gpi fpi))
             (assert (<= (rvclass-nfp c) nfp))
             (cond
               ((<= (rvclass-ngp c) ngp)
                (decf ngp (rvclass-ngp c)) (decf nfp (rvclass-nfp c))
                (incf gpi (rvclass-ngp c)) (incf fpi (rvclass-nfp c)))
               ((> ngp 0)
                (assert (= (rvclass-ngp c) 2))
                (assert (= (rvclass-class c) 0))
                (setf (rvclass-class c) (logior (rvclass-class c) +rv-cstk2+)
                      (rvclass-nreg c) 1)
                (decf ngp) (incf gpi))
               (t
                (setf (rvclass-class c) (logior (rvclass-class c) +rv-cstk1+))
                (when (> (rvclass-nreg c) 1)
                  (setf (rvclass-class c) (logior (rvclass-class c) +rv-cstk2+)))
                (setf (rvclass-nreg c) 0)))))
          ((:pare :arge)
           (setf (aref (rvclass-reg c) 0) +rv-t5+
                 (aref (rvclass-cls c) 0) :l
                 envc 1))
          (t (abi-unsupported (format nil "rv64 arg op ~a" op))))))
    (values (logior (ash envc 12) (ash gpi 4) (ash fpi 8)) cs)))

;;; ------------------------------------------------------------------ stkblob

(defun rv-stkblob (r ty fn)
  "rv64/abi.c stkblob: an alloc ins reserving TY's stack blob, defining R.
Returned to the caller, who hoists it into the start block (QBE's Insl list)."
  (let* ((al (max 0 (- (typ-align ty) 2)))       ; specific to NAlign == 3
         (sz (logand (+ (typ-size ty) 7) -8)))
    (make-instance 'ins :op (aref #(:alloc4 :alloc8 :alloc16) al) :cls :l
                        :to r :arg0 (getcon sz fn) :arg1 nil)))

;;; ------------------------------------------------------------------ selcall

(defun rv-selcall (fn args call ilp)
  "rv64/abi.c selcall: lower CALL with preceding ARGS.  Struct blobs (allocs)
are pushed onto ILP (a list cell in a 1-vector), hoisted into the start block."
  (let ((cr (make-rvclass)) (argl (coerce args 'vector)))
    (unless (null (ins-arg1 call))
      (rv-typclass cr (ins-arg1 call) t 0 0))
    (multiple-value-bind (cty cs)
        (rv-argsclass args (logtest (rvclass-class cr) +rv-cptr+))
      (let ((stk 0))
        (dotimes (idx (length argl))
          (let ((i (aref argl idx)) (c (aref cs idx)))
            (unless (eq (ins-op i) :argv)
              (when (logtest (rvclass-class c) +rv-cptr+)
                (setf (ins-arg0 i) (newtmp "abi" :l fn))
                (push (rv-stkblob (ins-arg0 i) (rvclass-ty c) fn) (aref ilp 0))
                (setf (ins-op i) :arg))
              (when (logtest (rvclass-class c) +rv-cstk1+) (incf stk 8))
              (when (logtest (rvclass-class c) +rv-cstk2+) (incf stk 8)))))
        (incf stk (logand stk 15))
        (when (/= stk 0)
          (emit :salloc :l nil (getcon (- stk) fn) nil))
        ;; return value
        (cond
          ((ins-arg1 call)
           (push (rv-stkblob (ins-to call) (rvclass-ty cr) fn) (aref ilp 0))
           (setf cty (logior cty (ash (rvclass-nfp cr) 2) (rvclass-ngp cr)))
           (if (logtest (rvclass-class cr) +rv-cptr+)
               ;; spill & rega expect calls to be followed by copies from
               ;; regs, so we emit a dummy
               (emit :copy :w nil (rvrg +rv-a0+) nil)
               (let ((tmp (rv-sttmps (rvclass-nreg cr) cr (ins-to call) fn)))
                 (dotimes (j (rvclass-nreg cr))
                   (emit :copy (aref (rvclass-cls cr) j) (aref tmp j)
                         (rvrg (aref (rvclass-reg cr) j)) nil)))))
          ((= (cls-base (ins-cls call)) 0)
           (emit :copy (ins-cls call) (ins-to call) (rvrg +rv-a0+) nil)
           (setf cty (logior cty 1)))
          (t
           (emit :copy (ins-cls call) (ins-to call) (rvrg +rv-fa0+) nil)
           (setf cty (logior cty (ash 1 2)))))
        (emit :call :w nil (ins-arg0 call) (make-call-ref cty))
        (when (logtest (rvclass-class cr) +rv-cptr+)
          ;; struct return argument
          (emit :copy :l (rvrg +rv-a0+) (ins-to call) nil))
        ;; move arguments into registers
        (dotimes (idx (length argl))
          (let ((i (aref argl idx)) (c (aref cs idx)))
            (unless (or (eq (ins-op i) :argv)
                        (logtest (rvclass-class c) +rv-cstk1+))
              (cond
                ((eq (ins-op i) :argc)
                 (rv-ldregs c (ins-arg1 i) fn))
                ((logtest (rvclass-class c) +rv-cfpint+)
                 (let* ((k (if (kwide (aref (rvclass-cls c) 0)) :l :w))
                        (r (newtmp "abi" k fn)))
                   (emit :copy k (rvrg (aref (rvclass-reg c) 0)) r nil)
                   (setf (aref (rvclass-reg c) 0) r)))   ; the cast below defines it
                (t
                 (emit :copy (aref (rvclass-cls c) 0)
                       (rvrg (aref (rvclass-reg c) 0)) (ins-arg0 i) nil))))))
        (dotimes (idx (length argl))
          (let ((i (aref argl idx)) (c (aref cs idx)))
            (when (logtest (rvclass-class c) +rv-cfpint+)
              (let ((k (if (kwide (aref (rvclass-cls c) 0)) :l :w)))
                (emit :cast k (aref (rvclass-reg c) 0) (ins-arg0 i) nil)))
            (when (logtest (rvclass-class c) +rv-cptr+)
              (emit :blit1 :w nil (typ-size (rvclass-ty c)) nil)
              (emit :blit0 :w nil (ins-arg1 i) (ins-arg0 i)))))
        (when (/= stk 0)
          ;; populate the stack
          (let ((off 0) (r (newtmp "abi" :l fn)))
            (dotimes (idx (length argl))
              (let ((i (aref argl idx)) (c (aref cs idx)))
                (unless (or (eq (ins-op i) :argv)
                            (not (logtest (rvclass-class c) +rv-cstk+)))
                  (when (eq (ins-op i) :arg)
                    (let ((r1 (newtmp "abi" :l fn)))
                      (emit (aref *rv-store* (cls-code (ins-cls i))) :w
                            nil (ins-arg0 i) r1)
                      (when (eq (ins-cls i) :w)
                        ;; TODO (upstream): we only need this sign extension
                        ;; for l temps passed as w arguments (rv64/isel.c fixarg)
                        (let ((st (car *emitted*)) (r2 (newtmp "abi" :l fn)))
                          (setf (ins-op st) :storel (ins-arg0 st) r2)
                          (emit :extsw :l r2 (ins-arg0 i) nil)))
                      (emit :add :l r1 r (getcon off fn))
                      (incf off 8)))
                  (when (eq (ins-op i) :argc)
                    (when (logtest (rvclass-class c) +rv-cstk1+)
                      (let ((r1 (newtmp "abi" :l fn)) (r2 (newtmp "abi" :l fn)))
                        (emit :storel :w nil r2 r1)
                        (emit :add :l r1 r (getcon off fn))
                        (emit :load :l r2 (ins-arg1 i) nil)
                        (incf off 8)))
                    (when (logtest (rvclass-class c) +rv-cstk2+)
                      (let ((r1 (newtmp "abi" :l fn)) (r2 (newtmp "abi" :l fn)))
                        (emit :storel :w nil r2 r1)
                        (emit :add :l r1 r (getcon off fn))
                        (let ((r3 (newtmp "abi" :l fn)))
                          (emit :load :l r2 r3 nil)
                          (emit :add :l r3 (ins-arg1 i) (getcon 8 fn)))
                        (incf off 8)))))))
            (emit :salloc :l r (getcon stk fn) nil)))))))

;;; ------------------------------------------------------------------ selpar

(defun rv-selpar (fn pars)
  "rv64/abi.c selpar: lower PARS (leading par run).  Returns (values stk ngp
nfp), QBE's Params, for selvastart."
  (let ((cr (make-rvclass)) (parl (coerce pars 'vector)) (il '()) (tmps '()))
    (when (fn-rettyp fn)
      (rv-typclass cr (fn-rettyp fn) t 0 0)
      (when (logtest (rvclass-class cr) +rv-cptr+)
        (setf (fn-retr fn) (newtmp "abi" :l fn))
        (emit :copy :l (fn-retr fn) (rvrg +rv-a0+) nil)))
    (multiple-value-bind (cty cs)
        (rv-argsclass pars (logtest (rvclass-class cr) +rv-cptr+))
      (setf (fn-reg fn) (let ((m 0))
                          (dolist (rid (rv64-argregs cty) m)
                            (setf m (logior m (ash 1 rid))))))
      (dotimes (idx (length parl))
        (let ((i (aref parl idx)) (c (aref cs idx)))
          (when (logtest (rvclass-class c) +rv-cfpint+)
            (let ((r (ins-to i)) (k (aref (rvclass-cls c) 0)))
              (setf (aref (rvclass-cls c) 0) (if (kwide k) :l :w)
                    (ins-to i) (newtmp "abi" k fn))
              (emit :cast k r (ins-to i) nil)))
          (when (and (eq (ins-op i) :parc)
                     (not (logtest (rvclass-class c) +rv-cptr+))
                     (/= (rvclass-nreg c) 0))
            (let ((nt (rvclass-nreg c)))
              (when (logtest (rvclass-class c) +rv-cstk2+)
                (setf (aref (rvclass-cls c) 1) :l (aref (rvclass-off c) 1) 8)
                (assert (= nt 1))
                (setf nt 2))
              (let ((tv (rv-sttmps nt c (ins-to i) fn)))
                (dotimes (n nt) (setf tmps (nconc tmps (list (aref tv n))))))
              (push (rv-stkblob (ins-to i) (rvclass-ty c) fn) il)))))
      ;; hoist the struct-param allocs (QBE flushes the Insl list here, head
      ;; first -- newest blob first, exactly as accumulated).
      (dolist (ins il) (push ins *emitted*))
      (let ((s (+ 2 (if (fn-vararg fn) 8 0))))
        (dotimes (idx (length parl))
          (let ((i (aref parl idx)) (c (aref cs idx)))
            (cond
              ((and (eq (ins-op i) :parc)
                    (not (logtest (rvclass-class c) +rv-cptr+)))
               (if (= (rvclass-nreg c) 0)
                   (progn
                     (setf (tmp-slot (ins-to i)) (- s))
                     (incf s (if (logtest (rvclass-class c) +rv-cstk2+) 2 1)))
                   (progn
                     (dotimes (j (rvclass-nreg c))
                       (emit :copy (aref (rvclass-cls c) j) (pop tmps)
                             (rvrg (aref (rvclass-reg c) j)) nil))
                     (when (logtest (rvclass-class c) +rv-cstk2+)
                       (emit :load :l (pop tmps) (make-slot-ref (- s)) nil)
                       (incf s)))))
              ((logtest (rvclass-class c) +rv-cstk1+)
               (emit :load (aref (rvclass-cls c) 0) (ins-to i)
                     (make-slot-ref (- s)) nil)
               (incf s))
              (t
               (emit :copy (aref (rvclass-cls c) 0) (ins-to i)
                     (rvrg (aref (rvclass-reg c) 0)) nil)))))
        (values s (logand (ash cty -4) 15) (logand (ash cty -8) 15))))))

;;; ------------------------------------------------------------------ varargs

(defun rv-selvaarg (fn i)
  "rv64/abi.c selvaarg: load the next arg from the va_list at I's arg, bump by 8."
  (let ((loc (newtmp "abi" :l fn)) (newloc (newtmp "abi" :l fn)))
    (emit :storel :w nil newloc (ins-arg0 i))
    (emit :add :l newloc loc (getcon 8 fn))
    (emit :load (ins-cls i) (ins-to i) loc nil)
    (emit :load :l loc (ins-arg0 i) nil)))

(defun rv-selvastart (fn pstk pngp ap)
  "rv64/abi.c selvastart: point the va_list at AP into the register save area
(first unnamed slot) or past the named stack parameters."
  (let ((rsave (newtmp "abi" :l fn))
        (s (if (> pstk (+ 2 (if (fn-vararg fn) 8 0))) pstk (+ 2 pngp))))
    (emit :storel :w nil rsave ap)
    (emit :addr :l rsave (make-slot-ref (- s)) nil)))

;;; ------------------------------------------------------------------ driver

(defun rv-ispar (op) (member op '(:par :parc :pare :parsb :parub :parsh :paruh)))

(defun rv64-abi (fn)
  "rv64/abi.c rv64_abi (abi1): lower params, returns, calls.  Rewrites FN."
  (dolist (b (fn-blocks fn)) (setf (blk-visit b) 0))
  (let ((il (make-array 1 :initial-element nil))   ; shared Insl (stkblob) list
        (pstk 0) (pngp 0))
    ;; 1. lower parameters (leading par run of the start block)
    (let* ((start (fn-start fn)) (pars '()) (rest nil))
      (dolist (i (blk-ins start))
        (if (and (null rest) (rv-ispar (ins-op i))) (push i pars) (push i rest)))
      (setf pars (nreverse pars) rest (nreverse rest))
      (let ((*emitted* nil))
        (multiple-value-setq (pstk pngp) (rv-selpar fn pars))
        (setf (blk-ins start) (append *emitted* rest))))
    ;; 2. lower returns / calls / varargs; start block LAST, then flush `il`.
    (let* ((blocks (fn-blocks fn)) (start (car blocks)))
      (dolist (b (append (cdr blocks) (list start)))
        (let ((*emitted* nil) (vec (coerce (blk-ins b) 'vector)))
          (rv-selret b fn)
          (loop with k = (length vec) while (> k 0) do
            (decf k)
            (let ((i (aref vec k)))
              (case (ins-op i)
                (:call
                 (let ((i0 k))
                   (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0)))))
                         do (decf i0))
                   (rv-selcall fn (coerce (subseq vec i0 k) 'list) i il)
                   (setf k i0)))
                (:vastart (rv-selvastart fn pstk pngp (ins-arg0 i)))
                (:vaarg (rv-selvaarg fn i))
                ((:arg :argc) (error "rv64 abi: unreachable arg op"))
                (t (push i *emitted*)))))
          ;; start block is processed last: flush accumulated stkblob allocs.
          (when (eq b start)
            (dolist (ins (aref il 0)) (push ins *emitted*)))
          (setf (blk-ins b) *emitted*))))))
