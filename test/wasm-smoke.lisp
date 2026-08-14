;;;; wasm-smoke.lisp --- W1 walking skeleton: QBE IL -> wasm64 LLVM .s ->
;;;; clang -> wasm-ld -> node, checking computed results.
;;;;
;;;; usage:  ros -Q run -- --script test/wasm-smoke.lisp
;;;;
;;;; Toolchain: any clang with a wasm64 target (brew llvm does), its wasm-ld,
;;;; and a node with memory64 (v23+).  Self-skips when they are missing.
;;;; i64 crosses the JS boundary as BigInt, i32/f32/f64 as Number.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(defpackage #:qbe-wasm-smoke (:use #:cl)) (in-package #:qbe-wasm-smoke)

(defvar *pass* 0) (defvar *fail* 0)
(defun ok (name) (incf *pass*) (format t "~&  ok   ~a~%" name))
(defun bad (name fmt &rest args)
  (incf *fail*) (format t "~&  FAIL ~a: ~?~%" name fmt args))

;;; ------------------------------------------------------------- toolchain
(defparameter *clang* (or (uiop:getenv "WASM_CC") "clang"))
(defun runs-p (argv &key input)
  (ignore-errors
   (zerop (nth-value 2 (uiop:run-program argv
                                         :input (and input (make-string-input-stream input))
                                         :output :string :error-output :string
                                         :ignore-error-status t)))))

(defparameter *wasm-ld*
  (or (uiop:getenv "WASM_LD")
      (dolist (c '("/opt/homebrew/opt/llvm/bin/wasm-ld"
                   "/opt/homebrew/opt/llvm@14/bin/wasm-ld" "wasm-ld"))
        (when (runs-p (list c "--version")) (return c)))))

(defun toolchain-p ()
  (and *wasm-ld*
       (runs-p (list *clang* "--target=wasm64" "-x" "assembler"
                     "-c" "-o" (uiop:native-namestring (uiop:null-device-pathname))
                     "-")
               :input "")
       (runs-p (list "node" "-e" "new WebAssembly.Memory({initial:1,index:'i64'})"))))

(unless (toolchain-p)
  (format t "~&=== wasm smoke: no wasm64 clang/wasm-ld/node; skipping ===~%")
  (sb-ext:exit :code 0))

;;; -------------------------------------------------------------- fixtures
(defparameter *il* "
export function w $addmul(w %a, w %b, w %c) {
@start
	%t =w add %a, %b
	%r =w mul %t, %c
	ret %r
}

export function w $loopsum() {
@start
	jmp @loop
@loop
	%i =w phi @start 0, @body %i1
	%s =w phi @start 0, @body %s1
	%c =w csltw %i, 10
	jnz %c, @body, @end
@body
	%s1 =w add %s, %i
	%i1 =w add %i, 1
	jmp @loop
@end
	ret %s
}

export function l $fact(l %n) {
@start
	%c =w csgtl %n, 1
	jnz %c, @rec, @base
@rec
	%n1 =l sub %n, 1
	%r =l call $fact(l %n1)
	%p =l mul %n, %r
	ret %p
@base
	ret 1
}

export function w $scale(d %x) {
@start
	%a =d mul %x, d_10.0
	%b =d add %a, d_2.5
	%i =w dtosi %b
	ret %i
}

export function w $memrt(w %v) {
@start
	%p =l alloc8 16
	storew %v, %p
	%q =l add %p, 8
	storew 7, %q
	%a =w loadw %p
	%b =w loadw %q
	%r =w add %a, %b
	ret %r
}

export function w $exts(w %x) {
@start
	%b =w extsb %x
	%h =w extsh %x
	%r =w add %b, %h
	ret %r
}

export function w $ucmp(w %a, w %b) {
@start
	%r =w cultw %a, %b
	ret %r
}

export function l $bits(d %x) {
@start
	%r =l cast %x
	ret %r
}

export function w $unord(d %a, d %b) {
@start
	%r =w cuod %a, %b
	ret %r
}

data $tab = align 4 { w 11, w 22, w 33 }

export function w $tabsum() {
@start
	%a =w loadw $tab
	%p =l add $tab, 4
	%b =w loadw %p
	%q =l add $tab, 8
	%c =w loadw %q
	%s =w add %a, %b
	%r =w add %s, %c
	ret %r
}

# ---- W2: the wasm C ABI ----
type :one = { l }
type :two = { l, l }

export function l $take1(:one %s) {
@start
	%a =l load %s
	ret %a
}
export function l $take2(:two %s) {
@start
	%a =l load %s
	%p =l add %s, 8
	%b =l load %p
	%r =l add %a, %b
	ret %r
}
export function :two $mk2(l %x, l %y) {
@start
	%s =l alloc8 16
	storel %x, %s
	%p =l add %s, 8
	storel %y, %p
	ret %s
}
export function :one $mk1(l %x) {
@start
	%s =l alloc8 8
	storel %x, %s
	ret %s
}
export function l $agg(l %x, l %y) {
@start
	%t =:two call $mk2(l %x, l %y)
	%a =l call $take2(:two %t)
	%o =:one call $mk1(l %a)
	%b =l call $take1(:one %o)
	ret %b
}

export function w $vsum(w %n, ...) {
@start
	%ap =l alloc8 8
	vastart %ap
	jmp @loop
@loop
	%i =w phi @start 0, @body %i1
	%s =w phi @start 0, @body %s1
	%c =w csltw %i, %n
	jnz %c, @body, @end
@body
	%v =w vaarg %ap
	%s1 =w add %s, %v
	%i1 =w add %i, 1
	jmp @loop
@end
	ret %s
}
export function d $vsumd(w %n, ...) {
@start
	%ap =l alloc8 8
	vastart %ap
	jmp @loop
@loop
	%i =w phi @start 0, @body %i1
	%s =d phi @start d_0, @body %s1
	%c =w csltw %i, %n
	jnz %c, @body, @end
@body
	%v =d vaarg %ap
	%s1 =d add %s, %v
	%i1 =w add %i, 1
	jmp @loop
@end
	ret %s
}
export function w $vcall() {
@start
	%r =w call $vsum(w 3, ..., w 10, w 20, w 30)
	ret %r
}
export function d $vcalld() {
@start
	%r =d call $vsumd(w 2, ..., d d_1.5, d d_2.25)
	ret %r
}

function w $inc(w %x) {
@start
	%r =w add %x, 1
	ret %r
}
export function w $apply(l %f, w %x) {
@start
	%r =w call %f(w %x)
	ret %r
}
export function w $indir(w %x) {
@start
	%p =l copy $inc
	%r =w call $apply(l %p, w %x)
	ret %r
}

function l $enved(env %e, l %x) {
@start
	%r =l add %e, %x
	ret %r
}
export function l $useenv() {
@start
	%r =l call $enved(env 7, l 35)
	ret %r
}

export function w $dyn(w %n) {
@start
	%sz =l extsw %n
	%p =l alloc8 %sz
	storew 42, %p
	%r =w loadw %p
	ret %r
}

export function w $dropper(w %x) {
@start
	call $inc(w %x)
	ret 5
}
")

;;; JS checks: name, argument list (JS syntax), expected (JS syntax).
(defparameter *checks*
  '(("addmul(2, 3, 4)" "20")
    ("loopsum()" "45")
    ("fact(10n)" "3628800n")
    ("scale(4.0)" "42")
    ("memrt(35)" "42")
    ("exts(0x1ff81)" "-126")               ; sb=-127 sh=-127+... (0xff81: sb 0x81=-127, sh 0xff81=-127) -> -254? computed below
    ("ucmp(1, -1 >>> 0 | 0)" "1")          ; 1 <u 0xffffffff
    ("bits(1.5)" "4609434218613702656n")
    ("unord(NaN, 1.0)" "1")
    ("unord(2.0, 1.0)" "0")
    ("tabsum()" "66")
    ;; W2: aggregates (direct + indirect + sret), varargs, call_indirect,
    ;; env, dynamic alloc, discarded-result drop
    ("take1(77n)" "77n")
    ("agg(30n, 12n)" "42n")
    ("vcall()" "60")
    ("vcalld()" "3.75")
    ("indir(41)" "42")
    ("useenv()" "42n")
    ("dyn(9)" "42")
    ("dropper(1)" "5")))

;;; exts(0x1ff81): low byte 0x81 -> -127; low half 0xff81 -> -127; sum -254.
(setf (second (assoc "exts(0x1ff81)" *checks* :test #'string=)) "-254")

;;; ------------------------------------------------------------------ build
(defparameter *work*
  (merge-pathnames (format nil "qbe-wasm-~d/" (random (expt 36 6) (make-random-state t)))
                   (uiop:temporary-directory)))
(ensure-directories-exist *work*)

(defun path (name) (uiop:native-namestring (merge-pathnames name *work*)))

(handler-case
    (let ((asm (qbe:wa-emit-module (qbe:parse-string *il*))))
      (with-open-file (s (path "t.s") :direction :output :if-exists :supersede)
        (write-string asm s)))
  (error (e) (format t "~&emit failed: ~a~%" e) (sb-ext:exit :code 1)))

(multiple-value-bind (out err code)
    (uiop:run-program (list *clang* "--target=wasm64" "-msign-ext"
                            "-mnontrapping-fptoint" "-mbulk-memory"
                            "-c" (path "t.s") "-o" (path "t.o"))
                      :output :string :error-output :string :ignore-error-status t)
  (declare (ignore out))
  (unless (zerop code)
    (format t "~&assemble failed:~%~a~%" err)
    (sb-ext:exit :code 1)))

(multiple-value-bind (out err code)
    (uiop:run-program (list *wasm-ld* "-mwasm64" "--no-entry" "--export-all"
                            "-z" "stack-size=1048576" (path "t.o")
                            "-o" (path "t.wasm"))
                      :output :string :error-output :string :ignore-error-status t)
  (declare (ignore out))
  (unless (zerop code)
    (format t "~&link failed:~%~a~%" err)
    (sb-ext:exit :code 1)))

;;; -------------------------------------------------------------------- run
(defparameter *js*
  (with-output-to-string (s)
    (format s "const fs = require('fs');~%")
    (format s "WebAssembly.instantiate(fs.readFileSync(process.argv[2])).then(m => {~%")
    (format s "  const e = m.instance.exports;~%")
    (dolist (c *checks*)
      (format s "  { const got = e.~a; const want = ~a;~%~
                 ~4Tconsole.log((got === want || (typeof got === 'number' && Math.abs(got - want) < 1e-9) ? 'ok ' : 'FAIL ') + ~s + ' got ' + got); }~%"
              (first c) (second c) (first c)))
    (format s "}).catch(err => { console.log('FAIL instantiate: ' + err); });~%")))

(with-open-file (s (path "run.js") :direction :output :if-exists :supersede)
  (write-string *js* s))

(multiple-value-bind (out err code)
    (uiop:run-program (list "node" (path "run.js") (path "t.wasm"))
                      :output :string :error-output :string :ignore-error-status t)
  (declare (ignore code))
  (dolist (l (uiop:split-string out :separator '(#\Newline)))
    (cond ((uiop:string-prefix-p "ok " l) (ok (subseq l 3)))
          ((uiop:string-prefix-p "FAIL " l) (bad "node" "~a" l))))
  (when (and (zerop *pass*) (zerop *fail*))
    (bad "node" "no output; stderr: ~a" err)))

(uiop:delete-directory-tree *work* :validate t :if-does-not-exist :ignore)

(format t "~&=== wasm smoke (W1 skeleton: .s -> clang -> wasm-ld -> node) ===~%  ~
          ~d passed, ~d failed~%" *pass* *fail*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
