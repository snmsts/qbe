;;;; wasm.lisp --- naive code generator for WebAssembly (wasm64, LLVM .s).
;;;;
;;;; The W1 walking skeleton (see the arm64 G1 precedent): straight from the
;;;; parsed IL, no mid-end, no target record.  Unlike the register machines the
;;;; "naive" scheme is close to the real thing here -- wasm has no registers to
;;;; allocate (engines do that), so every temp simply becomes a typed local.
;;;; What wasm does NOT have is goto, and that is the actual porting problem:
;;;;
;;;;   * W1 (this file) uses the universal dispatcher pattern: one `loop`
;;;;     wrapping N nested `block`s and a `br_table` on a label local; every
;;;;     block body ends with `return` or set-label + `br` back to the loop.
;;;;     Correct for ANY CFG, structured or not, at a branch-overhead cost.
;;;;   * W4 will replace it with a real stackifier (LLVM CFGStackify-style
;;;;     block/loop nesting derived from the dominator tree).
;;;;
;;;; Target dialect: wasm64 (memory64) -- QBE IL is LP64 (`l` pointers), and so
;;;; are the corpus C drivers, so wasm32's ILP32 would break both signatures
;;;; and semantics.  Output is LLVM wasm assembly (.functype / local.get /
;;;; end_function), NOT wat: `clang --target=wasm64 -c` turns it into a
;;;; relocatable object that `wasm-ld -mwasm64` links, later against wasi-libc.
;;;; The shadow-stack global `__stack_pointer` (i64 here) is declared via
;;;; .globaltype and synthesized by the linker.
;;;;
;;;; W1 scope: scalar params/returns/calls, int+float arithmetic, compares
;;;; (co/cuo synthesized as on rv64), loads/stores, extends, conversions
;;;; (trunc_sat_*, matching the saturating hardware semantics of the rv64
;;;; port), cast (reinterpret), phi (2-phase staging locals), alloc off the
;;;; shadow stack, blit (memory.copy), data sections.  Out of scope (error):
;;;; aggregates/env (argc/arge/parc/pare), varargs, indirect calls, TLS.

(in-package #:qbe)

;;; ------------------------------------------------------------------- types
(defun wa-type (cls)
  (ecase cls ((:w) "i32") ((:l :m) "i64") (:s "f32") (:d "f64")))

(defun wa-cls (cls) (if (eq cls :m) :l cls))

(defun wa-unsupported (what)
  (error "qbe wasm (W1): unsupported ~a" what))

;;; ---------------------------------------------------------------- fn state
(defstruct (waf (:conc-name waf-))
  fn stream
  (tmp-local (make-hash-table :test 'eq))   ; tmp -> (index . cls)
  (staging (make-hash-table :test 'eq))     ; phi -> staging local index
  (blk-index (make-hash-table :test 'eq))   ; blk -> dispatcher index
  (nparams 0)
  (locals '())                              ; extra locals, reversed (cls list)
  (nlocals 0)                               ; params + extras allocated so far
  label-local                               ; the br_table selector, or NIL
  sp-save                                   ; saved __stack_pointer, or NIL
  has-alloc
  (calls '()))                              ; (name params ret) seen at calls

(defun wa-out (f fmt &rest args) (apply #'format (waf-stream f) fmt args))

(defun wa-new-local (f cls)
  "Allocate a fresh (non-param) local of class CLS; returns its index."
  (push cls (waf-locals f))
  (prog1 (waf-nlocals f) (incf (waf-nlocals f))))

(defun wa-tmp-entry (f r)
  (or (gethash r (waf-tmp-local f))
      (error "wasm: undefined temp ~s" (tmp-name r))))

;;; ------------------------------------------------------------ local layout
(defun wa-par-op-p (op) (member op '(:par :parsb :parub :parsh :paruh)))

(defun wa-layout (f)
  "Assign wasm locals: params from the leading par run, then every defined
temp, phi staging locals, the dispatcher selector, and the sp save slot."
  (let ((fn (waf-fn f)))
    ;; params: the leading par run of the start block
    (dolist (i (blk-ins (fn-start fn)))
      (let ((op (ins-op i)))
        (cond
          ((wa-par-op-p op)
           (setf (gethash (ins-to i) (waf-tmp-local f))
                 (cons (waf-nlocals f)
                       (if (eq op :par) (wa-cls (ins-cls i)) :w)))
           (incf (waf-nlocals f)))
          ((member op '(:parc :pare)) (wa-unsupported (format nil "op ~a" op)))
          (t (return)))))
    (setf (waf-nparams f) (waf-nlocals f))
    ;; every other defined temp, in program order
    (flet ((claim (r cls)
             (when (and (tmp-p r) (not (gethash r (waf-tmp-local f))))
               (setf (gethash r (waf-tmp-local f))
                     (cons (wa-new-local f cls) cls)))))
      (dolist (b (fn-blocks fn))
        (dolist (p (blk-phis b))
          (claim (phi-to p) (wa-cls (phi-cls p)))
          (setf (gethash p (waf-staging f))
                (wa-new-local f (wa-cls (phi-cls p)))))
        (dolist (i (blk-ins b))
          (when (and (ins-to i) (not (wa-par-op-p (ins-op i))))
            (claim (ins-to i) (wa-cls (ins-cls i))))
          (when (member (ins-op i) '(:alloc4 :alloc8 :alloc16))
            (setf (waf-has-alloc f) t)))))
    ;; dispatcher selector (multi-block functions only); starts 0 = entry
    (let ((blocks (fn-blocks fn)))
      (loop for b in blocks for k from 0
            do (setf (gethash b (waf-blk-index f)) k))
      (when (> (length blocks) 1)
        (setf (waf-label-local f) (wa-new-local f :w))))
    (when (waf-has-alloc f)
      (setf (waf-sp-save f) (wa-new-local f :l)))))

;;; -------------------------------------------------------------- constants
(defun wa-float-lit (bits wide)
  "A C99 hex-float literal for the ieee754 BITS (f64 when WIDE) -- exact, no
decimal rounding to worry about, and LLVM's asm parser takes hex floats."
  (let* ((ebits (if wide 11 8)) (mbits (if wide 52 23))
         (bias (if wide 1023 127))
         (u (logand bits (1- (ash 1 (+ 1 ebits mbits)))))
         (sign (if (logbitp (+ ebits mbits) u) "-" ""))
         (e (ldb (byte ebits mbits) u))
         (m (ldb (byte mbits 0) u))
         ;; pad the mantissa up to a whole number of hex digits
         (pad (mod (- 4 (mod mbits 4)) 4))
         (digits (ceiling (+ mbits pad) 4))
         (frac (format nil "~v,'0x" digits (ash m pad))))
    (cond
      ((= e (1- (ash 1 ebits)))                       ; inf / nan
       (if (zerop m) (format nil "~ainf" sign)
           (format nil "~anan:0x~x" sign m)))
      ((and (zerop e) (zerop m)) (format nil "~a0x0p0" sign))
      ((zerop e)                                      ; subnormal
       (format nil "~a0x0.~ap~d" sign frac (- 2 bias)))
      (t (format nil "~a0x1.~ap~d" sign frac (- e bias))))))

(defun wa-push-con (f c cls)
  (ecase (con-kind c)
    (:addr
     (unless (eq cls :l) (wa-unsupported "symbol address at a non-l class"))
     (when (con-symtype c) (wa-unsupported "extern/thread symbol address"))
     (wa-out f "~Ci64.const~C~a~@[~a~]~%" #\Tab #\Tab (con-symname c)
             (unless (zerop (con-off c)) (format nil "+~d" (con-off c)))))
    (:bits
     (let ((bits (con-rawbits c)))
       (ecase cls
         (:w (wa-out f "~Ci32.const~C~d~%" #\Tab #\Tab (s32* bits)))
         (:l (wa-out f "~Ci64.const~C~d~%" #\Tab #\Tab (norm-i64 bits)))
         (:s (wa-out f "~Cf32.const~C~a~%" #\Tab #\Tab
                     (wa-float-lit (logand (u64* bits) #xffffffff) nil)))
         (:d (wa-out f "~Cf64.const~C~a~%" #\Tab #\Tab
                     (wa-float-lit (u64* bits) t))))))))

;;; --------------------------------------------------------------- operands
(defun wa-push (f r cls)
  "Push operand R at class CLS (the class the consumer wants)."
  (let ((cls (wa-cls cls)))
    (cond
      ((tmp-p r)
       (destructuring-bind (idx . have) (wa-tmp-entry f r)
         (wa-out f "~Clocal.get~C~d~%" #\Tab #\Tab idx)
         (cond
           ((eq have cls))
           ((and (eq have :l) (eq cls :w))
            (wa-out f "~Ci32.wrap_i64~%" #\Tab))
           (t (wa-unsupported
               (format nil "operand ~a used at ~a but defined at ~a"
                       (tmp-name r) cls have))))))
      ((con-p r) (wa-push-con f r cls))
      (t (error "wasm: bad operand ~s" r)))))

(defun wa-set (f r)
  "Pop the stack top into temp R's local."
  (wa-out f "~Clocal.set~C~d~%" #\Tab #\Tab (car (wa-tmp-entry f r))))

;;; ------------------------------------------------------------ instructions
(defparameter *wa-binop*
  '((:add "add" . "add") (:sub "sub" . "sub") (:mul "mul" . "mul")
    (:div "div_s" . "div") (:udiv "div_u" . nil)
    (:rem "rem_s" . nil) (:urem "rem_u" . nil)
    (:and "and" . nil) (:or "or" . nil) (:xor "xor" . nil))
  "op -> (int-suffix . float-suffix); NIL = int only.")

(defparameter *wa-shift* '((:shl . "shl") (:shr . "shr_u") (:sar . "shr_s")))

(defparameter *wa-cmp-suffix*
  #("eq" "ne" "ge_s" "gt_s" "le_s" "lt_s" "ge_u" "gt_u" "le_u" "lt_u"
    "eq" "ge" "gt" "le" "lt" "ne" nil nil)
  "combined compare code -> wasm suffix (16 co / 17 cuo are synthesized).")

(defparameter *wa-load*
  '((:loadsb (:w . "i32.load8_s")  (:l . "i64.load8_s"))
    (:loadub (:w . "i32.load8_u")  (:l . "i64.load8_u"))
    (:loadsh (:w . "i32.load16_s") (:l . "i64.load16_s"))
    (:loaduh (:w . "i32.load16_u") (:l . "i64.load16_u"))
    (:loadsw (:w . "i32.load")     (:l . "i64.load32_s"))
    (:loaduw (:w . "i32.load")     (:l . "i64.load32_u"))
    (:load   (:w . "i32.load")     (:l . "i64.load")
             (:s . "f32.load")     (:d . "f64.load"))))

(defparameter *wa-store*
  '((:storeb "i32.store8" . :w) (:storeh "i32.store16" . :w)
    (:storew "i32.store" . :w)  (:storel "i64.store" . :l)
    (:stores "f32.store" . :s)  (:stored "f64.store" . :d)))

(defun wa-emit-cmp (f i code ck)
  (let ((ty (wa-type ck)))
    (case code
      (16                                             ; co: (a==a) & (b==b)
       (wa-push f (ins-arg0 i) ck) (wa-push f (ins-arg0 i) ck)
       (wa-out f "~C~a.eq~%" #\Tab ty)
       (wa-push f (ins-arg1 i) ck) (wa-push f (ins-arg1 i) ck)
       (wa-out f "~C~a.eq~%" #\Tab ty)
       (wa-out f "~Ci32.and~%" #\Tab))
      (17                                             ; cuo: (a!=a) | (b!=b)
       (wa-push f (ins-arg0 i) ck) (wa-push f (ins-arg0 i) ck)
       (wa-out f "~C~a.ne~%" #\Tab ty)
       (wa-push f (ins-arg1 i) ck) (wa-push f (ins-arg1 i) ck)
       (wa-out f "~C~a.ne~%" #\Tab ty)
       (wa-out f "~Ci32.or~%" #\Tab))
      (t
       (wa-push f (ins-arg0 i) ck)
       (wa-push f (ins-arg1 i) ck)
       (wa-out f "~C~a.~a~%" #\Tab ty (aref *wa-cmp-suffix* code)))))
  ;; the result is an i32; widen when the instruction produces an l
  (when (eq (ins-cls i) :l) (wa-out f "~Ci64.extend_i32_u~%" #\Tab)))

(defun wa-emit-ext (f i)
  "The ext family: byte/half extends via i32/i64.extend8/16_s or masks,
word extends via i64.extend_i32_s/u."
  (let ((op (ins-op i)) (cls (wa-cls (ins-cls i))))
    (case op
      ((:extsw :extuw)
       (wa-push f (ins-arg0 i) :w)
       (wa-out f "~Ci64.extend_i32_~a~%" #\Tab (if (eq op :extsw) "s" "u")))
      (t
       ;; sub-word: compute in i32, then widen to l if needed
       (wa-push f (ins-arg0 i) :w)
       (ecase op
         (:extsb (wa-out f "~Ci32.extend8_s~%" #\Tab))
         (:extsh (wa-out f "~Ci32.extend16_s~%" #\Tab))
         (:extub (wa-out f "~Ci32.const~C255~%~Ci32.and~%" #\Tab #\Tab #\Tab))
         (:extuh (wa-out f "~Ci32.const~C65535~%~Ci32.and~%" #\Tab #\Tab #\Tab)))
       (when (eq cls :l)
         (wa-out f "~Ci64.extend_i32_~a~%" #\Tab
                 (if (member op '(:extsb :extsh)) "s" "u")))))))

(defun wa-restore-sp (f)
  (when (waf-sp-save f)
    (wa-out f "~Clocal.get~C~d~%~Cglobal.set~C__stack_pointer~%"
            #\Tab #\Tab (waf-sp-save f) #\Tab #\Tab)))

(defun wa-emit-call (f args call)
  "Direct scalar call: push ARGS in order, call, set the result local."
  (let ((target (ins-arg0 call)))
    (unless (and (con-p target) (eq (con-kind target) :addr)
                 (zerop (con-off target)) (null (con-symtype target)))
      (wa-unsupported "indirect or decorated call target"))
    (when (ins-arg1 call) (wa-unsupported "aggregate return"))
    (let ((params '()))
      (dolist (a args)
        (case (ins-op a)
          (:arg (wa-push f (ins-arg0 a) (ins-cls a))
                (push (wa-cls (ins-cls a)) params))
          ((:argsb :argub :argsh :arguh)
           (wa-push f (ins-arg0 a) :w)
           (push :w params))
          (t (wa-unsupported (format nil "call arg op ~a" (ins-op a))))))
      (push (list (con-symname target) (nreverse params)
                  (and (ins-to call) (wa-cls (ins-cls call))))
            (waf-calls f)))
    (wa-out f "~Ccall~C~a~%" #\Tab #\Tab (con-symname target))
    (when (ins-to call) (wa-set f (ins-to call)))))

(defun wa-emit-ins (f i vec k)
  "Emit instruction I (position K in VEC).  Returns the next position to
process (call sites consume their preceding arg run in one go)."
  (let ((op (ins-op i)) (cls (wa-cls (ins-cls i))))
    (cond
      ((wa-par-op-p op))                              ; params are locals
      ((arg-op-p op))                                 ; consumed by their call
      ((eq op :nop))
      ((eq op :dbgloc))
      ((eq op :call)
       (let ((i0 k))
         (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0)))))
               do (decf i0))
         (wa-emit-call f (coerce (subseq vec i0 k) 'list) i)))
      ((eq op :copy)
       (wa-push f (ins-arg0 i) cls) (wa-set f (ins-to i)))
      ((assoc op *wa-binop*)
       (destructuring-bind (iop . fop) (cdr (assoc op *wa-binop*))
         (wa-push f (ins-arg0 i) cls)
         (wa-push f (ins-arg1 i) cls)
         (let ((suffix (if (= (cls-base cls) 0) iop
                           (or fop (wa-unsupported (format nil "float ~a" op))))))
           (wa-out f "~C~a.~a~%" #\Tab (wa-type cls) suffix))
         (wa-set f (ins-to i))))
      ((assoc op *wa-shift*)
       (wa-push f (ins-arg0 i) cls)
       (wa-push f (ins-arg1 i) :w)                    ; shift count is Kw
       (when (eq cls :l) (wa-out f "~Ci64.extend_i32_u~%" #\Tab))
       (wa-out f "~C~a.~a~%" #\Tab (wa-type cls) (cdr (assoc op *wa-shift*)))
       (wa-set f (ins-to i)))
      ((eq op :neg)
       (if (= (cls-base cls) 0)
           (progn (wa-out f "~C~a.const~C0~%" #\Tab (wa-type cls) #\Tab)
                  (wa-push f (ins-arg0 i) cls)
                  (wa-out f "~C~a.sub~%" #\Tab (wa-type cls)))
           (progn (wa-push f (ins-arg0 i) cls)
                  (wa-out f "~C~a.neg~%" #\Tab (wa-type cls))))
       (wa-set f (ins-to i)))
      ((iscmp op)
       (multiple-value-bind (code ck) (iscmp op)
         (wa-emit-cmp f i code ck))
       (wa-set f (ins-to i)))
      ((assoc op *wa-load*)
       (wa-push f (ins-arg0 i) :l)                    ; the address
       (let ((instr (cdr (assoc cls (cdr (assoc op *wa-load*))))))
         (unless instr (wa-unsupported (format nil "~a at ~a" op cls)))
         (wa-out f "~C~a~C0~%" #\Tab instr #\Tab))
       (wa-set f (ins-to i)))
      ((assoc op *wa-store*)
       (destructuring-bind (instr . vcls) (cdr (assoc op *wa-store*))
         (wa-push f (ins-arg1 i) :l)                  ; address first,
         (wa-push f (ins-arg0 i) vcls)                ; then the value
         (wa-out f "~C~a~C0~%" #\Tab instr #\Tab)))
      ((member op '(:extsb :extub :extsh :extuh :extsw :extuw))
       (wa-emit-ext f i) (wa-set f (ins-to i)))
      ((eq op :exts)
       (wa-push f (ins-arg0 i) :s)
       (wa-out f "~Cf64.promote_f32~%" #\Tab) (wa-set f (ins-to i)))
      ((eq op :truncd)
       (wa-push f (ins-arg0 i) :d)
       (wa-out f "~Cf32.demote_f64~%" #\Tab) (wa-set f (ins-to i)))
      ((member op '(:stosi :stoui :dtosi :dtoui))
       (let ((from (if (member op '(:stosi :stoui)) :s :d))
             (sgn (if (member op '(:stosi :dtosi)) "s" "u")))
         (wa-push f (ins-arg0 i) from)
         ;; trunc_sat: saturating like the fcvt.rtz of real hardware, no trap
         (wa-out f "~C~a.trunc_sat_~a_~a~%" #\Tab (wa-type cls)
                 (wa-type from) sgn))
       (wa-set f (ins-to i)))
      ((member op '(:swtof :uwtof :sltof :ultof))
       (let ((from (if (member op '(:swtof :uwtof)) :w :l))
             (sgn (if (member op '(:swtof :sltof)) "s" "u")))
         (wa-push f (ins-arg0 i) from)
         (wa-out f "~C~a.convert_~a_~a~%" #\Tab (wa-type cls)
                 (wa-type from) sgn))
       (wa-set f (ins-to i)))
      ((eq op :cast)
       (let ((from (ecase cls (:w :s) (:l :d) (:s :w) (:d :l))))
         (wa-push f (ins-arg0 i) from)
         (wa-out f "~C~a.reinterpret_~a~%" #\Tab (wa-type cls) (wa-type from)))
       (wa-set f (ins-to i)))
      ((member op '(:alloc4 :alloc8 :alloc16))
       (unless (con-p (ins-arg0 i)) (wa-unsupported "dynamic alloc size"))
       (let ((sz (logand (+ (con-value (ins-arg0 i)) 15) -16)))
         (wa-out f "~Cglobal.get~C__stack_pointer~%" #\Tab #\Tab)
         (wa-out f "~Ci64.const~C~d~%~Ci64.sub~%" #\Tab #\Tab sz #\Tab)
         (wa-out f "~Clocal.tee~C~d~%" #\Tab #\Tab (car (wa-tmp-entry f (ins-to i))))
         (wa-out f "~Cglobal.set~C__stack_pointer~%" #\Tab #\Tab)))
      ((eq op :blit0)
       ;; blit0 (src, dst) + blit1 (len) -> memory.copy [dst, src, len]
       (let ((b1 (aref vec (1+ k))))
         (assert (eq (ins-op b1) :blit1))
         (wa-push f (ins-arg1 i) :l)
         (wa-push f (ins-arg0 i) :l)
         (wa-out f "~Ci64.const~C~d~%~Cmemory.copy~C0, 0~%"
                 #\Tab #\Tab (abs (ins-arg0 b1)) #\Tab #\Tab)))
      ((eq op :blit1))                                ; handled with blit0
      (t (wa-unsupported (format nil "op ~a" op))))
    (1+ k)))

;;; ------------------------------------------------------------ control flow
(defun wa-emit-edge (f b s)
  "Move S's phi arguments for predecessor B (2-phase through staging locals,
safe against parallel-copy hazards)."
  (let ((phis (blk-phis s)))
    (dolist (p phis)
      (wa-push f (cdr (assoc b (phi-args p) :test #'eq)) (phi-cls p))
      (wa-out f "~Clocal.set~C~d~%" #\Tab #\Tab (gethash p (waf-staging f))))
    (dolist (p phis)
      (wa-out f "~Clocal.get~C~d~%" #\Tab #\Tab (gethash p (waf-staging f)))
      (wa-set f (phi-to p)))))

(defun wa-goto (f b s loop-depth)
  "Edge copies for B->S, set the selector to S's index, branch to the loop."
  (wa-emit-edge f b s)
  (when (waf-label-local f)
    (wa-out f "~Ci32.const~C~d~%~Clocal.set~C~d~%" #\Tab #\Tab
            (gethash s (waf-blk-index f)) #\Tab #\Tab (waf-label-local f)))
  (wa-out f "~Cbr~C~d~%" #\Tab #\Tab loop-depth))

(defun wa-emit-terminator (f b loop-depth)
  (let ((jt (blk-jmp-type b)))
    (case jt
      (:hlt (wa-out f "~Cunreachable~%" #\Tab))
      ((:ret0 :retw :retl :rets :retd :retsb :retub :retsh :retuh)
       (wa-restore-sp f)
       (unless (eq jt :ret0)
         (wa-push f (blk-jmp-arg b)
                  (case jt (:retl :l) (:rets :s) (:retd :d) (t :w))))
       (wa-out f "~Creturn~%" #\Tab))
      (:jmp (wa-goto f b (blk-s1 b) loop-depth))
      (:jnz
       (wa-push f (blk-jmp-arg b) :w)
       (wa-out f "~Cif~%" #\Tab)
       (wa-goto f b (blk-s1 b) (1+ loop-depth))
       (wa-out f "~Celse~%" #\Tab)
       (wa-goto f b (blk-s2 b) (1+ loop-depth))
       (wa-out f "~Cend_if~%" #\Tab))
      (t (wa-unsupported (format nil "terminator ~a" jt))))))

(defun wa-emit-blk (f b loop-depth)
  (let ((vec (coerce (blk-ins b) 'vector)) (k 0))
    (loop while (< k (length vec))
          do (setf k (wa-emit-ins f (aref vec k) vec k)))
    (wa-emit-terminator f b loop-depth)))

;;; -------------------------------------------------------------- functions
(defun wa-functype (params ret)
  (format nil "(~{~a~^, ~}) -> (~@[~a~])"
          (mapcar #'wa-type params) (and ret (wa-type ret))))

(defun wa-fn-signature (f)
  "The function's own functype from its par run and return class."
  (let* ((fn (waf-fn f))
         (params (loop for i in (blk-ins (fn-start fn))
                       while (wa-par-op-p (ins-op i))
                       collect (if (eq (ins-op i) :par)
                                   (wa-cls (ins-cls i)) :w)))
         (rc (fn-retclass fn)))
    (when (fn-rettyp fn) (wa-unsupported "aggregate return type"))
    (wa-functype params
                 (case rc ((:0) nil) ((:w :l :s :d) rc) (t :w)))))

(defun wa-emit-fn (fn stream)
  "Emit one function; returns the call-site signatures it referenced."
  (let ((f (make-waf :fn fn :stream stream)))
    (wa-layout f)
    (let ((sig (wa-fn-signature f)))
      ;; NB: no .p2align here -- code "alignment" padding would corrupt the
      ;; code section (function entries are length-prefixed, not addressed)
      (when (fn-export fn) (wa-out f ".globl~C~a~%" #\Tab (fn-name fn)))
      (wa-out f "~a:~%" (fn-name fn))
      (wa-out f "~C.functype~C~a ~a~%" #\Tab #\Tab (fn-name fn) sig))
    (let ((extra (nreverse (waf-locals f))))
      (when extra
        (wa-out f "~C.local~C~{~a~^, ~}~%" #\Tab #\Tab (mapcar #'wa-type extra))))
    (when (waf-has-alloc f)
      (wa-out f "~Cglobal.get~C__stack_pointer~%~Clocal.set~C~d~%"
              #\Tab #\Tab #\Tab #\Tab (waf-sp-save f)))
    (let* ((blocks (fn-blocks fn)) (n (length blocks)))
      (if (= n 1)
          (wa-emit-blk f (car blocks) 0)
          (progn
            ;; the dispatcher: loop + N blocks + br_table on the selector,
            ;; each body at its block's end; L=k jumps to depth k.
            (wa-out f "~Cloop~%" #\Tab)
            (dotimes (k n) (declare (ignorable k)) (wa-out f "~Cblock~%" #\Tab))
            (wa-out f "~Clocal.get~C~d~%" #\Tab #\Tab (waf-label-local f))
            (wa-out f "~Cbr_table~C{~{~d~^, ~}}~%" #\Tab #\Tab
                    (append (loop for k below n collect k) (list (1- n))))
            (loop for b in blocks for k from 0 do
              (wa-out f "~Cend_block~%" #\Tab)
              (wa-emit-blk f b (- n 1 k)))
            (wa-out f "~Cend_loop~%" #\Tab)
            (wa-out f "~Cunreachable~%" #\Tab))))
    (wa-out f "~Cend_function~%" #\Tab)
    (waf-calls f)))

;;; -------------------------------------------------------------------- data
(defun wa-str-bytes (quoted)
  "Assembled byte length of a quoted .ascii string, honoring the gas escapes
the assembler will expand (\\n, \\ooo, \\xhh, ...)."
  (let ((s (subseq quoted 1 (1- (length quoted)))) (i 0) (n 0))
    (loop while (< i (length s)) do
      (if (char= (char s i) #\\)
          (let ((c (char s (1+ i))))
            (incf n)
            (cond
              ((digit-char-p c 8)                     ; \ooo: up to 3 octal digits
               (incf i)
               (loop repeat 3
                     while (and (< i (length s)) (digit-char-p (char s i) 8))
                     do (incf i)))
              ((char-equal c #\x)                     ; \xhh...: hex digits
               (incf i 2)
               (loop while (and (< i (length s))
                                (digit-char-p (char s i) 16))
                     do (incf i)))
              (t (incf i 2))))
          (progn
            (incf n (length (sb-ext:string-to-octets (string (char s i))
                                                     :external-format :utf-8)))
            (incf i))))
    n))

(defun wa-data-size (d)
  (loop for it in (dat-items d)
        sum (ecase (first it)
              (:int (second it))
              (:str (wa-str-bytes (second it)))
              (:ref (second it))
              (:zero (second it)))))

(defun wa-emit-data (d stream)
  (format stream "~C.section~C.data.~a,\"\",@~%" #\Tab #\Tab (dat-name d))
  (format stream "~C.p2align~C~d~%" #\Tab #\Tab
          (integer-length (1- (max 1 (dat-align d)))))
  (when (dat-export d) (format stream ".globl~C~a~%" #\Tab (dat-name d)))
  (when (dat-thread d) (wa-unsupported "thread-local data"))
  (format stream "~a:~%" (dat-name d))
  (dolist (it (dat-items d))
    (ecase (first it)
      (:int (destructuring-bind (size value) (rest it)
              (format stream "~C.int~d~C~d~%" #\Tab (* 8 size) #\Tab
                      (if (= size 8) (norm-i64 value)
                          (logand value (1- (ash 1 (* 8 size))))))))
      (:str (format stream "~C.ascii~C~a~%" #\Tab #\Tab (second it)))
      (:ref (destructuring-bind (size name off) (rest it)
              (unless (= size 8) (wa-unsupported "non-8-byte data ref"))
              (format stream "~C.int64~C~a~@[~a~]~%" #\Tab #\Tab name
                      (unless (zerop off) (format nil "+~d" off)))))
      (:zero (format stream "~C.skip~C~d~%" #\Tab #\Tab (second it)))))
  ;; the wasm object writer refuses data symbols without an explicit size
  (format stream "~C.size~C~a, ~d~%~%" #\Tab #\Tab (dat-name d) (wa-data-size d)))

;;; ------------------------------------------------------------------ module
(defun wa-emit-module (module &optional (stream nil))
  "Emit MODULE as LLVM wasm64 assembly; returns the string when STREAM is NIL."
  (let ((s (or stream (make-string-output-stream)))
        (calls '()) (defined '()))
    (format s "~C.text~%" #\Tab)
    (format s "~C.globaltype~C__stack_pointer, i64~%" #\Tab #\Tab)
    (dolist (fn (module-funcs module))
      (push (fn-name fn) defined)
      (setf calls (append (wa-emit-fn fn s) calls)))
    (dolist (d (module-data module)) (wa-emit-data d s))
    ;; .functype declarations for everything called but not defined here
    (let ((seen (make-hash-table :test 'equal)))
      (dolist (c calls)
        (destructuring-bind (name params ret) c
          (when (and (not (member name defined :test #'string=))
                     (not (gethash name seen)))
            (setf (gethash name seen) t)
            (format s "~C.functype~C~a ~a~%" #\Tab #\Tab name
                    (wa-functype params ret))))))
    (unless stream (get-output-stream-string s))))
