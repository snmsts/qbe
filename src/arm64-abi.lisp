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
(defconstant +a64-ngpr+ 31) (defconstant +a64-nfpr+ 31)  ; R0..SP, V0..V30

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

;;; ---------------------------------------------------- abi1: scalar classes
;;; STAGE 1: scalars only.  A Class records how one par/arg travels: in a
;;; register (reg + cls) or on the stack (Cstk).  Aggregates (Oparc/Oargc),
;;; large-struct pointers (Cptr), and HFA are not handled yet (abi-unsupported).

(defconstant +a64-cstk+ 1)
(defconstant +a64-cptr+ 2)

(defstruct a64class
  (class 0) (size 8) (align 8) reg cls)   ; reg/cls: chosen register id + class

(defun a64-argsclass (ins-list)
  "arm64/abi.c argsclass (scalar subset).  INS-LIST = par/arg ins.  Returns
(values cty class-vector env va).  Signals abi-unsupported for aggregates."
  (let ((ngp 8) (nfp 8) (gpn 0) (fpn 0) (va nil) (envc 0) (env nil)
        (cs (make-array (length ins-list))))
    (loop for i in ins-list for idx from 0 do
      (let* ((op (ins-op i)) (c (make-a64class)))
        (setf (aref cs idx) c)
        (flet ((scalar (size cls)
                 (setf (a64class-size c) size (a64class-align c) size
                       (a64class-cls c) cls)
                 (cond
                   (va (setf (a64class-class c) +a64-cstk+
                             (a64class-size c) 8 (a64class-align c) 8))
                   ((and (= (cls-base cls) 0) (> ngp 0))
                    (decf ngp) (setf (a64class-reg c) (+ +a64-r0+ gpn)) (incf gpn))
                   ((and (= (cls-base cls) 1) (> nfp 0))
                    (decf nfp) (setf (a64class-reg c) (+ +a64-v0+ fpn)) (incf fpn))
                   (t (setf (a64class-class c) +a64-cstk+)))))
          (case op
            ((:argsb :argub :parsb :parub) (scalar 1 :w))
            ((:argsh :arguh :parsh :paruh) (scalar 2 :w))
            ((:par :arg)
             (scalar (if (kwide (ins-cls i)) 8 4) (ins-cls i)))  ; apple: size 4 for non-wide
            ((:argc :parc) (abi-unsupported "arm64 aggregate arg/par (stage 2)"))
            ((:arge :pare)
             (setf (a64class-reg c) +a64-r9+ (a64class-cls c) :l
                   envc 1 env (if (member op '(:pare)) (ins-to i) (ins-arg0 i))))
            ((:argv) (setf va t))
            (t (abi-unsupported (format nil "arm64 arg op ~a" op)))))))
    (values (logior (ash envc 14) (ash gpn 5) (ash fpn 9)) cs env va)))

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

;;; ------------------------------------------------------------ abi1: selret
(defun a64-selret (b fn)
  "arm64/abi.c selret (scalar subset)."
  (let ((j (blk-jmp-type b)))
    (when (and (isret-jmp j) (not (eq j :ret0)))
      (let ((r (blk-jmp-arg b)) (cty 0))
        (setf (blk-jmp-type b) :ret0)
        (if (eq j :retc)
            (abi-unsupported "arm64 struct return (stage 2)")
            (let ((k (ecase j (:retw :w) (:retl :l) (:rets :s) (:retd :d))))
              (if (= (cls-base k) 0)
                  (progn (emit :copy k (a64rg +a64-r0+) r nil) (setf cty 1))
                  (progn (emit :copy k (a64rg +a64-v0+) r nil) (setf cty (ash 1 2))))))
        (setf (blk-jmp-arg b) (make-call-ref cty))))))

;;; ------------------------------------------------------------ abi1: selcall
(defun a64-selcall (fn args call)
  "arm64/abi.c selcall (scalar subset: register args + env, scalar return)."
  (when (ins-arg1 call) (abi-unsupported "arm64 struct return (stage 2)"))
  (multiple-value-bind (cty cs env va) (a64-argsclass args)
    (declare (ignore va))
    (let ((argl (coerce args 'vector)))
      ;; any stack arg -> stage 2
      (loop for c across cs when (logtest (a64class-class c) +a64-cstk+)
            do (abi-unsupported "arm64 stack call args (stage 2)"))
      ;; scalar return in R0/V0
      (if (= (cls-base (ins-cls call)) 0)
          (progn (emit :copy (ins-cls call) (ins-to call) (a64rg +a64-r0+) nil)
                 (setf cty (logior cty 1)))
          (progn (emit :copy (ins-cls call) (ins-to call) (a64rg +a64-v0+) nil)
                 (setf cty (logior cty (ash 1 2)))))
      (emit :call (ins-cls call) nil (ins-arg0 call) (make-call-ref cty))
      ;; copy each register arg into its parameter register (QBE order)
      (dotimes (idx (length argl))
        (let ((i (aref argl idx)) (c (aref cs idx)))
          (when (and (a64class-reg c)
                     (member (ins-op i) '(:arg :arge :argsb :argub :argsh :arguh)))
            (emit :copy (a64class-cls c) (a64rg (a64class-reg c)) (ins-arg0 i) nil)))))))

;;; ------------------------------------------------------------ abi1: selpar
(defun a64-selpar (fn pars)
  "arm64/abi.c selpar (scalar subset).  Returns (values stk ngp nfp)."
  (multiple-value-bind (cty cs env va) (a64-argsclass pars)
    (declare (ignore env va))
    (setf (fn-reg fn) (let ((m 0))
                        (dolist (rid (arm64-argregs cty) m)
                          (setf m (logior m (ash 1 rid))))))
    (when (fn-rettyp fn) (abi-unsupported "arm64 struct return param (stage 2)"))
    (let ((parl (coerce pars 'vector)))
      (dotimes (idx (length parl))
        (let ((i (aref parl idx)) (c (aref cs idx)))
          (when (logtest (a64class-class c) +a64-cstk+)
            (abi-unsupported "arm64 stack params (stage 2)"))
          (when (eq (ins-op i) :parc) (abi-unsupported "arm64 aggregate param (stage 2)"))
          (emit :copy (a64class-cls c) (ins-to i) (a64rg (a64class-reg c)) nil))))
    (values 0 (logand (ash cty -5) 15) (logand (ash cty -9) 15))))

;;; ------------------------------------------------------------ abi1: driver
(defun ispar-a64 (op) (member op '(:par :parc :pare :parsb :parub :parsh :paruh)))

(defun arm64-abi (fn)
  "arm64/abi.c arm64_abi (abi1, stage 1: scalars).  Rewrites FN."
  (dolist (b (fn-blocks fn)) (setf (blk-visit b) 0))
  ;; 1. lower parameters (leading par run of the start block)
  (let* ((start (fn-start fn)) (pars '()) (rest nil))
    (dolist (i (blk-ins start))
      (if (and (null rest) (ispar-a64 (ins-op i))) (push i pars) (push i rest)))
    (setf pars (nreverse pars) rest (nreverse rest))
    (let ((*emitted* nil))
      (a64-selpar fn pars)
      (setf (blk-ins start) (append *emitted* rest))))
  ;; 2. lower returns / calls / varargs; start block LAST
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
                 (a64-selcall fn (coerce (subseq vec i0 k) 'list) i)
                 (setf k i0)))
              ((eq (ins-op i) :vastart) (abi-unsupported "arm64 vastart (stage 3)"))
              ((eq (ins-op i) :vaarg) (abi-unsupported "arm64 vaarg (stage 3)"))
              (t (push i *emitted*)))))
        (setf (blk-ins b) *emitted*)))))
