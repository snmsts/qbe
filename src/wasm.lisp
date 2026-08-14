;;;; wasm.lisp --- naive code generator for WebAssembly (wasm64, LLVM .s).
;;;;
;;;; W1 was the walking skeleton (see the arm64 G1 precedent): straight from
;;;; the parsed IL, no mid-end, no target record.  Unlike the register machines
;;;; the "naive" scheme is close to the real thing here -- wasm has no
;;;; registers to allocate (engines do that), so every temp simply becomes a
;;;; typed local.  W2 adds the wasm C ABI so real programs fit through it.
;;;;
;;;; What wasm does NOT have is goto, and that is one of the two actual
;;;; porting problems:
;;;;
;;;;   * control flow uses the universal dispatcher pattern: one `loop`
;;;;     wrapping N nested `block`s and a `br_table` on a label local; every
;;;;     block body ends with `return` or set-label + `br` back to the loop.
;;;;     Correct for ANY CFG, structured or not, at a branch-overhead cost.
;;;;     W4 will replace it with a real stackifier (LLVM CFGStackify-style
;;;;     nesting derived from the dominator tree).
;;;;
;;;; The other is that wasm call signatures are CHECKED: a caller must name
;;;; the callee's exact type, where a register machine just doesn't read the
;;;; result register.  IL discards results syntactically (`call $printf(...)`),
;;;; so the module is emitted in two passes: a pre-scan collects every
;;;; function's signature -- a definition is authoritative, call sites are
;;;; merged (a site that binds the result beats one that discards it) -- and
;;;; emission then inserts `drop` where the IL ignores a value the callee
;;;; does return.
;;;;
;;;; The wasm C ABI here follows tool-conventions BasicCABI (clang is the
;;;; dialect oracle, verified against wasi-sdk in the corpus e2e):
;;;;   * scalars pass directly; an aggregate that is recursively a single
;;;;     scalar field ("singleton") unwraps to that scalar; anything else
;;;;     passes indirectly -- the CALLER copies it to a shadow-stack blob and
;;;;     passes the pointer.
;;;;   * singleton returns unwrap; other aggregate returns go through a
;;;;     leading sret pointer parameter and the function returns void.
;;;;   * varargs: the caller packs the post-`...` arguments into 8-byte slots
;;;;     of a shadow-stack buffer and passes its address as one trailing
;;;;     parameter; va_list is a bare pointer; va_arg walks 8-byte slots.
;;;;   * the env parameter (upstream: a scratch register outside the C ABI --
;;;;     a luxury wasm does not have) becomes a trailing parameter between
;;;;     the named ones and the vararg buffer; both ends of an env call are
;;;;     IL, so the convention only has to be self-consistent.
;;;;   * function "pointers" are table indices: `i64.const f` relocates to
;;;;     the index, call_indirect (with the index wrapped to i32) applies it.
;;;;
;;;; Canonical parameter order: [sret] named... [env] [vararg-buffer].
;;;;
;;;; Target dialect: wasm64 (memory64) -- QBE IL is LP64 (`l` pointers), and
;;;; so are the corpus C drivers, so wasm32's ILP32 would break both
;;;; signatures and semantics.  Output is LLVM wasm assembly (.functype /
;;;; local.get / end_function), NOT wat: `clang --target=wasm64 -c` turns it
;;;; into a relocatable object that `wasm-ld -mwasm64` links, later against
;;;; wasi-libc.  The shadow-stack global `__stack_pointer` (i64 here) is
;;;; declared via .globaltype and synthesized by the linker.
;;;;
;;;; Assembler lessons (each cost a debug cycle): loads/stores REQUIRE an
;;;; explicit memarg offset; sign-ext / trunc-sat / bulk-memory need their -m
;;;; flags at assemble time; data symbols are fatal without `.size`; and
;;;; never emit `.p2align` before a function label -- the padding lands
;;;; INSIDE the length-prefixed code section and corrupts the object.
;;;;
;;;; Still out of scope (error): TLS, extern symbol addresses with offsets.

(in-package #:qbe)

;;; ------------------------------------------------------------------- types
(defun wa-type (cls)
  (ecase cls ((:w) "i32") ((:l :m) "i64") (:s "f32") (:d "f64")))

(defun wa-cls (cls) (if (eq cls :m) :l cls))

(defun wa-round16 (n) (logand (+ n 15) -16))

(defun wa-unsupported (what)
  (error "qbe wasm (W2): unsupported ~a" what))

;;; --------------------------------------------------- aggregate classification
(defun wa-singleton (ty)
  "The scalar class of TY when it is recursively a single scalar field
(clang's isSingleElementStruct), else NIL."
  (when (or (typ-isdark ty) (typ-isunion ty) (/= (typ-nunion ty) 1))
    (return-from wa-singleton nil))
  (let ((found nil))
    (loop for f across (aref (typ-fields ty) 0) do
      (let ((ftype (car f)) (len (cdr f)))
        (unless (eq ftype :pad)
          (when found (return-from wa-singleton nil))
          (setf found
                (case ftype
                  ((:b :h :w) :w) (:l :l) (:s :s) (:d :d)
                  (:typ (or (wa-singleton len) (return-from wa-singleton nil)))
                  (t (return-from wa-singleton nil)))))))
    found))

(defun wa-typclass (ty)
  "(values :direct cls) when TY unwraps to a scalar, else (values :indirect)."
  (let ((s (and (plusp (typ-size ty)) (wa-singleton ty))))
    (if s (values :direct s) (values :indirect nil))))

;;; ------------------------------------------------------------ signatures
;;; A signature is (params . ret): params a list of cls in canonical order
;;; ([sret] named [env] [vb]), ret a cls or NIL.

(defun wa-ret-cls (cls) (case cls ((:w :l :s :d) cls) (t :w)))

(defun wa-callsite-parts (args call)
  "Split a call's arg run.  Returns (values fixed varargs env variadic-p)."
  (let ((fixed '()) (varargs '()) (env nil) (va nil))
    (dolist (a args)
      (case (ins-op a)
        (:argv (setf va t))
        (:arge (setf env a))
        (t (if va (push a varargs) (push a fixed)))))
    (values (nreverse fixed) (nreverse varargs) env va)))

(defun wa-arg-cls (a)
  "The wasm class one fixed argument contributes to the signature."
  (case (ins-op a)
    (:arg (wa-cls (ins-cls a)))
    ((:argsb :argub :argsh :arguh) :w)
    (:argc (multiple-value-bind (kind cls) (wa-typclass (ins-arg0 a))
             (if (eq kind :direct) cls :l)))
    (t (wa-unsupported (format nil "call arg op ~a" (ins-op a))))))

(defstruct (wa-sig (:constructor make-wa-sig (fixed ret sret env va)))
  fixed          ; classes of the named parameters
  ret            ; result class, or NIL (void / sret)
  sret env va)   ; leading sret pointer / trailing env / trailing vararg buffer

(defun wa-callsite-sig (args call)
  "The signature this call site implies for its callee.  NB env is NOT
recorded: only a DEFINITION owns an env parameter (QBE allows passing env to
a regular function, where it is silently ignored)."
  (multiple-value-bind (fixed varargs env va) (wa-callsite-parts args call)
    (declare (ignore varargs env))
    (let* ((rett (ins-arg1 call))
           (sret (and rett (eq (wa-typclass rett) :indirect)))
           (ret (cond (sret nil)
                      (rett (nth-value 1 (wa-typclass rett)))
                      ((ins-to call) (wa-ret-cls (ins-cls call)))
                      (t nil))))
      (make-wa-sig (mapcar #'wa-arg-cls fixed) ret sret nil va))))

;;; IL carries no extern declarations, so the result type of an undefined
;;; callee is guesswork: a site that binds the result claims one, but QBE IL
;;; happily binds the "result" of a void C function too (the value is a
;;; garbage register upstream).  When the guess is wrong the link makes the
;;; call an unreachable stub, so a harness that KNOWS the C prototype can
;;; record it here: name -> :void or a result class.  Checked after the
;;; libc table, for undefined callees only.
(defvar *wa-extern-rets* nil
  "Alist name -> (:void | cls): declared result types for extern functions.")

(defun wa-fn-plan (fn)
  "Analyze FN's header.  Returns (values named env-ins sret-p ret sig) where
NAMED is a list of (kind cls ins), kind :scalar | :parc-direct | :parc-indirect."
  (let ((named '()) (env nil))
    (dolist (i (blk-ins (fn-start fn)))
      (case (ins-op i)
        (:par (push (list :scalar (wa-cls (ins-cls i)) i) named))
        ((:parsb :parub :parsh :paruh) (push (list :scalar :w i) named))
        (:parc
         (multiple-value-bind (kind cls) (wa-typclass (ins-arg0 i))
           (push (if (eq kind :direct)
                     (list :parc-direct cls i)
                     (list :parc-indirect :l i))
                 named)))
        (:pare (setf env i))
        (t (return))))
    (setf named (nreverse named))
    (let* ((rett (fn-rettyp fn))
           (sret (and rett (eq (wa-typclass rett) :indirect)))
           (ret (cond (sret nil)
                      (rett (nth-value 1 (wa-typclass rett)))
                      ((eq (fn-retclass fn) :0) nil)
                      (t (wa-ret-cls (fn-retclass fn)))))
           ;; clang promotes C main to (i32, i64) -> i32 on wasm (ignored
           ;; argc/argv, forced int result); the runtime calls it that way,
           ;; so an IL main gets the same treatment
           (pad (when (string= (fn-name fn) "main")
                  (setf ret (or ret :w))
                  (nthcdr (length named) '(:w :l))))
           (sig (make-wa-sig (append (mapcar #'second named) pad) ret sret
                             (and env t) (and (fn-vararg fn) t))))
      (values named env sret ret sig pad))))

(defun wa-functype (sig)
  (format nil "(~{~a~^, ~}) -> (~@[~a~])"
          (mapcar #'wa-type
                  (append (when (wa-sig-sret sig) '(:l))
                          (wa-sig-fixed sig)
                          (when (wa-sig-env sig) '(:l))
                          (when (wa-sig-va sig) '(:l))))
          (and (wa-sig-ret sig) (wa-type (wa-sig-ret sig)))))

;;; The libc functions the corpus reaches.  IL usually discards their results,
;;; and wasm imports are signature-checked, so the true C signatures have to
;;; come from somewhere; a register machine never had this problem.
(defparameter *wa-libc-sigs*
  (let ((h (make-hash-table :test 'equal)))
    (loop for (name fixed ret va) in
          '(("printf" (:l) :w t) ("fprintf" (:l :l) :w t)
            ("sprintf" (:l :l) :w t) ("snprintf" (:l :l :l) :w t)
            ("sscanf" (:l :l) :w t) ("scanf" (:l) :w t)
            ("vprintf" (:l :l) :w nil)
            ("puts" (:l) :w nil) ("putchar" (:w) :w nil)
            ("getchar" () :w nil) ("getenv" (:l) :l nil)
            ("malloc" (:l) :l nil) ("calloc" (:l :l) :l nil)
            ("realloc" (:l :l) :l nil) ("free" (:l) nil nil)
            ("exit" (:w) nil nil) ("abort" () nil nil)
            ("memcpy" (:l :l :l) :l nil) ("memmove" (:l :l :l) :l nil)
            ("memset" (:l :w :l) :l nil) ("memcmp" (:l :l :l) :w nil)
            ("strlen" (:l) :l nil) ("strcmp" (:l :l) :w nil)
            ("strncmp" (:l :l :l) :w nil) ("strcpy" (:l :l) :l nil)
            ("strchr" (:l :w) :l nil) ("strstr" (:l :l) :l nil)
            ("labs" (:l) :l nil) ("abs" (:w) :w nil)
            ("atoi" (:l) :w nil) ("atol" (:l) :l nil)
            ("rand" () :w nil) ("srand" (:w) nil nil))
          do (setf (gethash name h) (make-wa-sig fixed ret nil nil va)))
    h))

;;; --------------------------------------------------------- module pre-scan
(defun wa-scan-signatures (module)
  "Hash: callee name -> (sig . authoritative-p).  Definitions win; among call
sites a result-binding one beats a discarding one."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (fn (module-funcs module))
      (setf (gethash (fn-name fn) table)
            (cons (nth-value 4 (wa-fn-plan fn)) t)))
    (dolist (fn (module-funcs module))
      (dolist (b (fn-blocks fn))
        (let ((vec (coerce (blk-ins b) 'vector)))
          (loop for k below (length vec)
                for i = (aref vec k)
                when (eq (ins-op i) :call) do
            (let ((target (ins-arg0 i)))
              (when (and (con-p target) (eq (con-kind target) :addr))
                (let ((i0 k))
                  (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0)))))
                        do (decf i0))
                  (let* ((name (con-symname target))
                         (sig (wa-callsite-sig (coerce (subseq vec i0 k) 'list) i))
                         (old (gethash name table)))
                    (cond
                      ((null old) (setf (gethash name table) (cons sig nil)))
                      ((cdr old))                 ; a definition is authoritative
                      (t
                       ;; merge sites: a bound result beats a discarded one,
                       ;; and any variadic site marks the callee variadic
                       (let ((osig (car old)))
                         (when (and (null (wa-sig-ret osig)) (wa-sig-ret sig))
                           (setf (wa-sig-ret osig) (wa-sig-ret sig)))
                         (when (wa-sig-va sig)
                           (setf (wa-sig-va osig) t)))))))))))))
    ;; known libc signatures override site guesses for UNDEFINED callees
    (maphash (lambda (name entry)
               (unless (cdr entry)
                 (let ((libc (gethash name *wa-libc-sigs*)))
                   (when libc
                     (setf (gethash name table) (cons libc nil))))
                 (let ((decl (assoc name *wa-extern-rets* :test #'string=)))
                   (when decl
                     (setf (wa-sig-ret (car (gethash name table)))
                           (unless (eq (cdr decl) :void) (cdr decl)))))))
             table)
    table))

;;; ---------------------------------------------------------------- fn state
(defstruct (waf (:conc-name waf-))
  fn stream sigs
  (tmp-local (make-hash-table :test 'eq))   ; tmp -> (index . cls)
  (staging (make-hash-table :test 'eq))     ; phi -> staging local index
  (blk-index (make-hash-table :test 'eq))   ; blk -> dispatcher index
  (scratch (make-hash-table :test 'eq))     ; purpose -> local index
  (nparams 0)
  (locals '())                              ; extra locals, reversed (cls list)
  (nlocals 0)
  label-local
  sp-save
  has-alloc
  sret-param                                ; leading sret pointer, or NIL
  env-param                                 ; trailing env pointer, or NIL
  vb-param                                  ; trailing vararg buffer, or NIL
  parc-blobs                                ; ((param-idx cls to-tmp) ...)
  (npad 0)                                  ; ignored params of a promoted main
  ret0-zero)                                ; promoted main: ret0 returns 0

(defun wa-out (f fmt &rest args) (apply #'format (waf-stream f) fmt args))

(defun wa-new-local (f cls)
  (push cls (waf-locals f))
  (prog1 (waf-nlocals f) (incf (waf-nlocals f))))

(defun wa-scratch (f key)
  "A lazily-allocated i64 scratch local for KEY (:blob / :vb / :cur)."
  (or (gethash key (waf-scratch f))
      (setf (gethash key (waf-scratch f)) (wa-new-local f :l))))

(defun wa-tmp-entry (f r)
  (or (gethash r (waf-tmp-local f))
      (error "wasm: undefined temp ~s" (tmp-name r))))

;;; ------------------------------------------------------------ local layout
(defun wa-par-op-p (op) (member op '(:par :parsb :parub :parsh :paruh :parc :pare)))

(defun wa-layout (f)
  "Assign wasm locals: canonical params ([sret] named [env] [vb]), then every
defined temp, phi staging, the dispatcher selector, and the sp save slot."
  (let ((fn (waf-fn f)))
    (multiple-value-bind (named env sret ret sig pad) (wa-fn-plan fn)
      (declare (ignore sig))
      ;; a promoted main: extra ignored params, and ret0 must yield 0
      (when pad (incf (waf-npad f) (length pad)))
      (when (and (string= (fn-name fn) "main") (eq (fn-retclass fn) :0) ret)
        (setf (waf-ret0-zero f) t))
      (when sret
        (setf (waf-sret-param f) (waf-nlocals f))
        (incf (waf-nlocals f)))
      (let ((direct '()))
        (dolist (spec named)
          (destructuring-bind (kind cls i) spec
            (ecase kind
              ((:scalar :parc-indirect)
               (setf (gethash (ins-to i) (waf-tmp-local f))
                     (cons (waf-nlocals f) (if (eq kind :scalar) cls :l))))
              (:parc-direct
               (push (list (waf-nlocals f) cls (ins-to i)) direct)))
            (incf (waf-nlocals f))))
        (incf (waf-nlocals f) (waf-npad f))          ; ignored main params
        (when env
          (setf (waf-env-param f) (waf-nlocals f))
          (setf (gethash (ins-to env) (waf-tmp-local f))
                (cons (waf-nlocals f) :l))
          (incf (waf-nlocals f)))
        (when (fn-vararg fn)
          (setf (waf-vb-param f) (waf-nlocals f))
          (incf (waf-nlocals f)))
        (setf (waf-nparams f) (waf-nlocals f))
        ;; unwrapped struct params get respilled to a blob; the IL temp is
        ;; the blob's address, a fresh (non-param) local
        (dolist (d (nreverse direct))
          (setf (gethash (third d) (waf-tmp-local f))
                (cons (wa-new-local f :l) :l))
          (setf (waf-has-alloc f) t))
        (setf (waf-parc-blobs f) (nreverse direct))))
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
            (claim (ins-to i)
                   (if (ins-arg1 i)                  ; aggregate-returning call
                       (if (eq (ins-op i) :call) :l (wa-cls (ins-cls i)))
                       (wa-cls (ins-cls i)))))
          (case (ins-op i)
            ((:alloc4 :alloc8 :alloc16) (setf (waf-has-alloc f) t))
            (:argv (setf (waf-has-alloc f) t))
            (:argc (when (eq (wa-typclass (ins-arg0 i)) :indirect)
                     (setf (waf-has-alloc f) t)))
            (:call (when (ins-arg1 i) (setf (waf-has-alloc f) t)))))))
    (let ((blocks (fn-blocks (waf-fn f))))
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
         (pad (mod (- 4 (mod mbits 4)) 4))
         (digits (ceiling (+ mbits pad) 4))
         (frac (format nil "~v,'0x" digits (ash m pad))))
    (cond
      ((= e (1- (ash 1 ebits)))
       (if (zerop m) (format nil "~ainf" sign)
           (format nil "~anan:0x~x" sign m)))
      ((and (zerop e) (zerop m)) (format nil "~a0x0p0" sign))
      ((zerop e) (format nil "~a0x0.~ap~d" sign frac (- 2 bias)))
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
  (wa-out f "~Clocal.set~C~d~%" #\Tab #\Tab (car (wa-tmp-entry f r))))

(defun wa-get-local (f idx) (wa-out f "~Clocal.get~C~d~%" #\Tab #\Tab idx))

(defparameter *wa-store-op*
  '((:w . "i32.store") (:l . "i64.store") (:s . "f32.store") (:d . "f64.store")))
(defparameter *wa-load-op*
  '((:w . "i32.load") (:l . "i64.load") (:s . "f32.load") (:d . "f64.load")))

(defun wa-alloc-shadow (f size local-idx)
  "Take SIZE (16-rounded) bytes off the shadow stack; LOCAL-IDX = new sp."
  (wa-out f "~Cglobal.get~C__stack_pointer~%" #\Tab #\Tab)
  (wa-out f "~Ci64.const~C~d~%~Ci64.sub~%" #\Tab #\Tab (wa-round16 size) #\Tab)
  (wa-out f "~Clocal.tee~C~d~%" #\Tab #\Tab local-idx)
  (wa-out f "~Cglobal.set~C__stack_pointer~%" #\Tab #\Tab))

;;; ------------------------------------------------------------ instructions
(defparameter *wa-binop*
  '((:add "add" . "add") (:sub "sub" . "sub") (:mul "mul" . "mul")
    (:div "div_s" . "div") (:udiv "div_u" . nil)
    (:rem "rem_s" . nil) (:urem "rem_u" . nil)
    (:and "and" . nil) (:or "or" . nil) (:xor "xor" . nil)))

(defparameter *wa-shift* '((:shl . "shl") (:shr . "shr_u") (:sar . "shr_s")))

(defparameter *wa-cmp-suffix*
  #("eq" "ne" "ge_s" "gt_s" "le_s" "lt_s" "ge_u" "gt_u" "le_u" "lt_u"
    "eq" "ge" "gt" "le" "lt" "ne" nil nil))

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
      (16
       (wa-push f (ins-arg0 i) ck) (wa-push f (ins-arg0 i) ck)
       (wa-out f "~C~a.eq~%" #\Tab ty)
       (wa-push f (ins-arg1 i) ck) (wa-push f (ins-arg1 i) ck)
       (wa-out f "~C~a.eq~%" #\Tab ty)
       (wa-out f "~Ci32.and~%" #\Tab))
      (17
       (wa-push f (ins-arg0 i) ck) (wa-push f (ins-arg0 i) ck)
       (wa-out f "~C~a.ne~%" #\Tab ty)
       (wa-push f (ins-arg1 i) ck) (wa-push f (ins-arg1 i) ck)
       (wa-out f "~C~a.ne~%" #\Tab ty)
       (wa-out f "~Ci32.or~%" #\Tab))
      (t
       (wa-push f (ins-arg0 i) ck)
       (wa-push f (ins-arg1 i) ck)
       (wa-out f "~C~a.~a~%" #\Tab ty (aref *wa-cmp-suffix* code)))))
  (when (eq (ins-cls i) :l) (wa-out f "~Ci64.extend_i32_u~%" #\Tab)))

(defun wa-emit-ext (f i)
  (let ((op (ins-op i)) (cls (wa-cls (ins-cls i))))
    (case op
      ((:extsw :extuw)
       (wa-push f (ins-arg0 i) :w)
       (wa-out f "~Ci64.extend_i32_~a~%" #\Tab (if (eq op :extsw) "s" "u")))
      (t
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

;;; ------------------------------------------------------------------- calls
(defun wa-push-fixed-arg (f a)
  "Push one fixed argument per the C ABI."
  (case (ins-op a)
    (:arg (wa-push f (ins-arg0 a) (ins-cls a)))
    ((:argsb :argub :argsh :arguh) (wa-push f (ins-arg0 a) :w))
    (:argc
     (multiple-value-bind (kind cls) (wa-typclass (ins-arg0 a))
       (if (eq kind :direct)
           (progn                          ; unwrap: load the scalar
             (wa-push f (ins-arg1 a) :l)
             (wa-out f "~C~a~C0~%" #\Tab (cdr (assoc cls *wa-load-op*)) #\Tab))
           (let ((blob (wa-scratch f :blob))     ; caller-copy, pass pointer
                 (sz (typ-size (ins-arg0 a))))
             (wa-alloc-shadow f sz blob)
             (wa-get-local f blob)
             (wa-push f (ins-arg1 a) :l)
             (wa-out f "~Ci64.const~C~d~%~Ccall~C__qbe_blit~%"
                     #\Tab #\Tab sz #\Tab #\Tab)
             (wa-get-local f blob)))))))

;;; clang wasm64 lays the vararg buffer out with NATURAL slots, not fixed
;;; 8-byte ones (verified against wasm64-unknown-emscripten codegen): each
;;; argument is placed at its alignment and advances by its size -- i32/f32
;;; take 4 bytes, i64/f64 8 -- and va_arg aligns the cursor the same way.
(defun wa-vararg-slot (a)
  "(values size store-cls) for one variadic argument (indirect aggregates
travel as pointers)."
  (case (ins-op a)
    (:arg (if (kwide (ins-cls a)) (values 8 (wa-cls (ins-cls a)))
              (values 4 (wa-cls (ins-cls a)))))
    ((:argsb :argub :argsh :arguh) (values 4 :w))
    (:argc (multiple-value-bind (kind cls) (wa-typclass (ins-arg0 a))
             (if (and (eq kind :direct) (not (kwide cls)))
                 (values 4 cls)
                 (values 8 (if (eq kind :direct) cls :l)))))
    (t (wa-unsupported (format nil "vararg op ~a" (ins-op a))))))

(defun wa-fill-vararg-buffer (f varargs)
  "Pack VARARGS into naturally-aligned slots of a fresh shadow-stack buffer;
returns the scratch local holding its address."
  (let ((vb (wa-scratch f :vb)) (offsets '()) (off 0))
    (dolist (a varargs)
      (let ((size (wa-vararg-slot a)))
        (setf off (logand (+ off (1- size)) (- size)))
        (push off offsets)
        (incf off size)))
    (setf offsets (nreverse offsets))
    (wa-alloc-shadow f (max 16 off) vb)
    (loop for a in varargs for slot in offsets do
      (multiple-value-bind (size cls) (wa-vararg-slot a)
        (declare (ignore size))
        (case (ins-op a)
          (:arg
           (wa-get-local f vb)
           (wa-push f (ins-arg0 a) (ins-cls a))
           (wa-out f "~C~a~C~d~%" #\Tab (cdr (assoc cls *wa-store-op*)) #\Tab slot))
          ((:argsb :argub :argsh :arguh)
           (wa-get-local f vb)
           (wa-push f (ins-arg0 a) :w)
           (wa-out f "~Ci32.store~C~d~%" #\Tab #\Tab slot))
          (:argc
           (if (eq (wa-typclass (ins-arg0 a)) :direct)
               (progn
                 (wa-get-local f vb)
                 (wa-push f (ins-arg1 a) :l)
                 (wa-out f "~C~a~C0~%" #\Tab (cdr (assoc cls *wa-load-op*)) #\Tab)
                 (wa-out f "~C~a~C~d~%" #\Tab (cdr (assoc cls *wa-store-op*))
                         #\Tab slot))
               (let ((blob (wa-scratch f :blob))
                     (sz (typ-size (ins-arg0 a))))
                 (wa-alloc-shadow f sz blob)
                 (wa-get-local f blob)
                 (wa-push f (ins-arg1 a) :l)
                 (wa-out f "~Ci64.const~C~d~%~Ccall~C__qbe_blit~%"
                         #\Tab #\Tab sz #\Tab #\Tab)
                 (wa-get-local f vb)
                 (wa-get-local f blob)
                 (wa-out f "~Ci64.store~C~d~%" #\Tab #\Tab slot)))))))
    vb))

(defun wa-resolved-sig (f name site-sig)
  "The signature to call NAME with: the module table's (authoritative or
merged) entry when present, else the site's own."
  (let ((e (and name (gethash name (waf-sigs f)))))
    (if e (car e) site-sig)))

(defun wa-emit-call (f args call)
  (multiple-value-bind (fixed varargs env va) (wa-callsite-parts args call)
    (let* ((target (ins-arg0 call))
           (direct (and (con-p target) (eq (con-kind target) :addr)))
           (name (and direct (con-symname target)))
           (site-sig (wa-callsite-sig args call))
           (sig (wa-resolved-sig f name site-sig))
           (rett (ins-arg1 call))
           (retkind (and rett (wa-typclass rett)))
           (vb nil))
      (when (and direct (con-symtype target))
        (wa-unsupported "extern-decorated call target"))
      (when (and direct (/= (con-off target) 0))
        (wa-unsupported "call target with offset"))
      ;; the vararg buffer is packed before anything lands on the wasm stack
      (when (and va (wa-sig-va sig)) (setf vb (wa-fill-vararg-buffer f varargs)))
      (cond
        ((eq retkind :indirect)
         ;; sret: blob into the call's to-temp, its address leads the args
         (wa-alloc-shadow f (typ-size rett) (car (wa-tmp-entry f (ins-to call))))
         (wa-get-local f (car (wa-tmp-entry f (ins-to call)))))
        ((eq retkind :direct)
         ;; unwrapped return: blob address goes UNDER the args so the store
         ;; finds [addr, value] on the stack after the call returns
         (wa-alloc-shadow f 16 (car (wa-tmp-entry f (ins-to call))))
         (wa-get-local f (car (wa-tmp-entry f (ins-to call))))))
      (dolist (a fixed) (wa-push-fixed-arg f a))
      ;; env travels only when the DEFINITION has it (a regular callee
      ;; silently ignores a passed env, so the site's is dropped; an env
      ;; callee called without one gets an undefined -- zero -- env)
      (when (wa-sig-env sig)
        (if env (wa-push f (ins-arg0 env) :l)
            (wa-out f "~Ci64.const~C0~%" #\Tab #\Tab)))
      ;; likewise a variadic callee always receives its buffer parameter
      (when (wa-sig-va sig)
        (if vb (wa-get-local f vb)
            (wa-out f "~Ci64.const~C0~%" #\Tab #\Tab)))
      (if direct
          (wa-out f "~Ccall~C~a~%" #\Tab #\Tab name)
          (progn                                     ; function pointer: table
            (wa-push f target :l)
            (wa-out f "~Ci32.wrap_i64~%" #\Tab)
            (wa-out f "~Ccall_indirect~C~a~%" #\Tab #\Tab (wa-functype sig))))
      ;; result handling against the RESOLVED signature
      (cond
        ((eq retkind :indirect))                     ; to already holds the blob
        ((eq retkind :direct)                        ; store scalar into blob
         (wa-out f "~C~a~C0~%" #\Tab
                 (cdr (assoc (nth-value 1 (wa-typclass rett)) *wa-store-op*)) #\Tab))
        ((and (ins-to call) (wa-sig-ret sig)) (wa-set f (ins-to call)))
        ((ins-to call)
         ;; QBE allows binding the "result" of a void callee; the value is
         ;; undefined, and zero is as good an undefined value as any
         (let ((cls (wa-cls (ins-cls call))))
           (wa-out f "~C~a.const~C0~%" #\Tab (wa-type cls) #\Tab)
           (wa-set f (ins-to call))))
        ((wa-sig-ret sig) (wa-out f "~Cdrop~%" #\Tab))))))

;;; ------------------------------------------------------------------ varargs
(defun wa-emit-vastart (f i)
  (unless (waf-vb-param f) (wa-unsupported "vastart outside a variadic function"))
  (wa-push f (ins-arg0 i) :l)
  (wa-get-local f (waf-vb-param f))
  (wa-out f "~Ci64.store~C0~%" #\Tab #\Tab))

(defun wa-emit-vaarg (f i)
  (let* ((cur (wa-scratch f :cur)) (cls (wa-cls (ins-cls i)))
         (size (if (kwide cls) 8 4)))
    (wa-push f (ins-arg0 i) :l)                      ; cur = align(*ap, size)
    (wa-out f "~Ci64.load~C0~%" #\Tab #\Tab)
    (wa-out f "~Ci64.const~C~d~%~Ci64.add~%~Ci64.const~C~d~%~Ci64.and~%"
            #\Tab #\Tab (1- size) #\Tab #\Tab #\Tab (- size) #\Tab)
    (wa-out f "~Clocal.set~C~d~%" #\Tab #\Tab cur)
    (wa-get-local f cur)                             ; to = *(cls*)cur
    (wa-out f "~C~a~C0~%" #\Tab (cdr (assoc cls *wa-load-op*)) #\Tab)
    (wa-set f (ins-to i))
    (wa-push f (ins-arg0 i) :l)                      ; *ap = cur + size
    (wa-get-local f cur)
    (wa-out f "~Ci64.const~C~d~%~Ci64.add~%~Ci64.store~C0~%"
            #\Tab #\Tab size #\Tab #\Tab #\Tab)))

;;; ------------------------------------------------------------ instructions
(defun wa-emit-ins (f i vec k)
  "Emit instruction I (position K in VEC).  Returns the next position."
  (let ((op (ins-op i)) (cls (wa-cls (ins-cls i))))
    (cond
      ((wa-par-op-p op))
      ((arg-op-p op))
      ((eq op :nop))
      ((eq op :dbgloc))
      ((eq op :call)
       (let ((i0 k))
         (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0)))))
               do (decf i0))
         (wa-emit-call f (coerce (subseq vec i0 k) 'list) i)))
      ((eq op :vastart) (wa-emit-vastart f i))
      ((eq op :vaarg) (wa-emit-vaarg f i))
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
       (wa-push f (ins-arg1 i) :w)
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
       (wa-push f (ins-arg0 i) :l)
       (let ((instr (cdr (assoc cls (cdr (assoc op *wa-load*))))))
         (unless instr (wa-unsupported (format nil "~a at ~a" op cls)))
         (wa-out f "~C~a~C0~%" #\Tab instr #\Tab))
       (wa-set f (ins-to i)))
      ((assoc op *wa-store*)
       (destructuring-bind (instr . vcls) (cdr (assoc op *wa-store*))
         (wa-push f (ins-arg1 i) :l)
         (wa-push f (ins-arg0 i) vcls)
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
       (wa-out f "~Cglobal.get~C__stack_pointer~%" #\Tab #\Tab)
       (if (con-p (ins-arg0 i))
           (wa-out f "~Ci64.const~C~d~%" #\Tab #\Tab
                   (wa-round16 (con-value (ins-arg0 i))))
           (progn                                    ; dynamic size: round it
             (wa-push f (ins-arg0 i) :l)
             (wa-out f "~Ci64.const~C15~%~Ci64.add~%~Ci64.const~C-16~%~Ci64.and~%"
                     #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)))
       (wa-out f "~Ci64.sub~%" #\Tab)
       (wa-out f "~Clocal.tee~C~d~%" #\Tab #\Tab (car (wa-tmp-entry f (ins-to i))))
       (wa-out f "~Cglobal.set~C__stack_pointer~%" #\Tab #\Tab))
      ((eq op :blit0)
       (let ((b1 (aref vec (1+ k))))
         (assert (eq (ins-op b1) :blit1))
         (wa-push f (ins-arg1 i) :l)
         (wa-push f (ins-arg0 i) :l)
         (wa-out f "~Ci64.const~C~d~%~Ccall~C__qbe_blit~%"
                 #\Tab #\Tab (abs (ins-arg0 b1)) #\Tab #\Tab)))
      ((eq op :blit1))
      (t (wa-unsupported (format nil "op ~a" op))))
    (1+ k)))

;;; ------------------------------------------------------------ control flow
(defun wa-emit-edge (f b s)
  (let ((phis (blk-phis s)))
    (dolist (p phis)
      (wa-push f (cdr (assoc b (phi-args p) :test #'eq)) (phi-cls p))
      (wa-out f "~Clocal.set~C~d~%" #\Tab #\Tab (gethash p (waf-staging f))))
    (dolist (p phis)
      (wa-out f "~Clocal.get~C~d~%" #\Tab #\Tab (gethash p (waf-staging f)))
      (wa-set f (phi-to p)))))

(defun wa-goto (f b s loop-depth)
  (wa-emit-edge f b s)
  (when (waf-label-local f)
    (wa-out f "~Ci32.const~C~d~%~Clocal.set~C~d~%" #\Tab #\Tab
            (gethash s (waf-blk-index f)) #\Tab #\Tab (waf-label-local f)))
  (wa-out f "~Cbr~C~d~%" #\Tab #\Tab loop-depth))

(defun wa-emit-terminator (f b loop-depth)
  (let ((jt (blk-jmp-type b)) (fn (waf-fn f)))
    (case jt
      (:hlt (wa-out f "~Cunreachable~%" #\Tab))
      (:retc
       (multiple-value-bind (kind cls) (wa-typclass (fn-rettyp fn))
         (if (eq kind :direct)
             (progn                                  ; unwrap: return the scalar
               (wa-push f (blk-jmp-arg b) :l)
               (wa-out f "~C~a~C0~%" #\Tab (cdr (assoc cls *wa-load-op*)) #\Tab)
               (wa-restore-sp f)
               (wa-out f "~Creturn~%" #\Tab))
             (progn                                  ; copy into the sret blob
               (wa-get-local f (waf-sret-param f))
               (wa-push f (blk-jmp-arg b) :l)
               (wa-out f "~Ci64.const~C~d~%~Ccall~C__qbe_blit~%"
                       #\Tab #\Tab (typ-size (fn-rettyp fn)) #\Tab #\Tab)
               (wa-restore-sp f)
               (wa-out f "~Creturn~%" #\Tab)))))
      ((:ret0 :retw :retl :rets :retd :retsb :retub :retsh :retuh)
       (wa-restore-sp f)
       (cond
         ((not (eq jt :ret0))
          (wa-push f (blk-jmp-arg b)
                   (case jt (:retl :l) (:rets :s) (:retd :d) (t :w))))
         ((waf-ret0-zero f)                          ; promoted void main
          (wa-out f "~Ci32.const~C0~%" #\Tab #\Tab)))
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
(defun wa-emit-fn (fn stream sigs)
  "Emit one function (module signature table SIGS in hand)."
  (let* ((body (make-string-output-stream))
         (f (make-waf :fn fn :stream body :sigs sigs)))
    (wa-layout f)
    ;; body first (into a buffer): scratch locals are allocated lazily and
    ;; the .local line must precede the code
    (when (waf-sp-save f)
      (wa-out f "~Cglobal.get~C__stack_pointer~%~Clocal.set~C~d~%"
              #\Tab #\Tab #\Tab #\Tab (waf-sp-save f)))
    ;; unwrapped struct params: respill into a blob, the temp is its address
    (dolist (d (waf-parc-blobs f))
      (destructuring-bind (pidx cls to) d
        (wa-alloc-shadow f 16 (car (wa-tmp-entry f to)))
        (wa-get-local f (car (wa-tmp-entry f to)))
        (wa-get-local f pidx)
        (wa-out f "~C~a~C0~%" #\Tab (cdr (assoc cls *wa-store-op*)) #\Tab)))
    (let* ((blocks (fn-blocks fn)) (n (length blocks)))
      (if (= n 1)
          (wa-emit-blk f (car blocks) 0)
          (progn
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
    ;; header + locals + buffered body
    (let* ((sig (car (gethash (fn-name fn) sigs)))
           (sym (fn-name fn)))
      ;; NB: no .p2align here -- code "alignment" padding would corrupt the
      ;; code section (function entries are length-prefixed, not addressed)
      (when (fn-export fn) (format stream ".globl~C~a~%" #\Tab sym))
      (format stream "~a:~%" sym)
      (format stream "~C.functype~C~a ~a~%" #\Tab #\Tab sym
              (wa-functype sig)))
    (let ((extra (nreverse (waf-locals f))))
      (when extra
        (format stream "~C.local~C~{~a~^, ~}~%" #\Tab #\Tab
                (mapcar #'wa-type extra))))
    (write-string (get-output-stream-string body) stream)
    (format stream "~Cend_function~%" #\Tab)))

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
              ((digit-char-p c 8)
               (incf i)
               (loop repeat 3
                     while (and (< i (length s)) (digit-char-p (char s i) 8))
                     do (incf i)))
              ((char-equal c #\x)
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
(defun wa-emit-blit-helper (s)
  "The byte-copy helper every aggregate copy and blit calls.  A plain loop
instead of memory.copy: LLVM 14's assembler still types bulk-memory operands
as i32 under memory64, so the portable spelling is our own function."
  (format s "__qbe_blit:~%~C.functype~C__qbe_blit (i64, i64, i64) -> ()~%"
          #\Tab #\Tab)
  (format s "~Cblock~%~Cloop~%" #\Tab #\Tab)
  (format s "~Clocal.get~C2~%~Ci64.eqz~%~Cbr_if~C1~%" #\Tab #\Tab #\Tab #\Tab #\Tab)
  (format s "~Clocal.get~C0~%~Clocal.get~C1~%~Ci32.load8_u~C0~%~Ci32.store8~C0~%"
          #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)
  (format s "~Clocal.get~C0~%~Ci64.const~C1~%~Ci64.add~%~Clocal.set~C0~%"
          #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)
  (format s "~Clocal.get~C1~%~Ci64.const~C1~%~Ci64.add~%~Clocal.set~C1~%"
          #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)
  (format s "~Clocal.get~C2~%~Ci64.const~C-1~%~Ci64.add~%~Clocal.set~C2~%"
          #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)
  (format s "~Cbr~C0~%~Cend_loop~%~Cend_block~%~Cend_function~%"
          #\Tab #\Tab #\Tab #\Tab #\Tab))

(defun wa-emit-module (module &optional (stream nil))
  "Emit MODULE as LLVM wasm64 assembly; returns the string when STREAM is NIL."
  (let ((s (or stream (make-string-output-stream)))
        (sigs (wa-scan-signatures module))
        (defined (mapcar #'fn-name (module-funcs module))))
    (format s "~C.text~%" #\Tab)
    (format s "~C.globaltype~C__stack_pointer, i64~%" #\Tab #\Tab)
    ;; .functype declarations up front: the parser must know a callee's type
    ;; before the first `call` that references it
    (format s "~C.functype~C__qbe_blit (i64, i64, i64) -> ()~%" #\Tab #\Tab)
    (maphash (lambda (name entry)
               (unless (member name defined :test #'string=)
                 (format s "~C.functype~C~a ~a~%" #\Tab #\Tab name
                         (wa-functype (car entry)))))
             sigs)
    (dolist (fn (module-funcs module))
      (wa-emit-fn fn s sigs))
    (wa-emit-blit-helper s)
    (dolist (d (module-data module)) (wa-emit-data d s))
    (unless stream (get-output-stream-string s))))
