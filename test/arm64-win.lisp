;;;; arm64-win.lisp --- the arm64_win target: assembler dialect, vararg guard,
;;;; and (on a Windows ARM64 host) end-to-end native execution.
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-win.lisp
;;;;
;;;; Windows on ARM64 documents its non-variadic ABI as plain AAPCS64, so
;;;; *arm64-win-target* shares the register model / isel / abi1 / emit passes
;;;; with Apple verbatim.  Only three things differ, and this file pins all of
;;;; them down:
;;;;
;;;;   1. assembler dialect -- no `_` symbol prefix, `.L` locals, and
;;;;      `adrp X, sym` + `add X, X, #:lo12:sym` instead of mach-o's
;;;;      `@page` / `@pageoff`.  (Checked textually: runs on any host.)
;;;;   2. varargs -- Windows uses neither Apple's all-on-the-stack rule nor
;;;;      AAPCS64's 192-byte save area, so it is deliberately UNIMPLEMENTED and
;;;;      must raise rather than silently miscompile.  (Any host.)
;;;;   3. that the result actually runs.  (Windows ARM64 host only; skipped
;;;;      elsewhere, detected via `cc -dumpmachine`.)
;;;;
;;;; Sections 1 and 2 are pure computation and belong in the host-agnostic CI
;;;; group; section 3 is the `windows` group.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(defpackage #:qbe-arm64-win (:use #:cl)) (in-package #:qbe-arm64-win)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

(defun ok (name &rest args)
  (incf *pass*) (format t "~&  ok   ~a~@[ => ~a~]~%" name (car args)))
(defun bad (name fmt &rest args)
  (incf *fail*) (format t "~&  FAIL ~a: ~?~%" name fmt args))

(defun win-asm (src)
  (qbe:a64-be-emit-module (qbe:parse-string src) qbe:*arm64-win-target*))

;;; --------------------------------------------------------------- fixtures
(defparameter *loop-sum* "
export function w $main() {
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
")

(defparameter *puts-data* "
data $str = { b \"hello from qbe-cl on Windows ARM64\", b 0 }

export function w $main() {
@start
	%r =w call $puts(l $str)
	ret 0
}
")

;; three integer args in w0/w1/w2, result in w0 -- exercises AAPCS64 both ways
;; across a boundary the C compiler owns.
(defparameter *addmul* "
export function w $addmul(w %a, w %b, w %c) {
@start
	%t =w add %a, %b
	%r =w mul %t, %c
	ret %r
}
")

;; the fp constants must survive GVN, so they have to meet a non-constant
;; operand -- hence the double parameter and the C driver.
(defparameter *fp-pool* "
export function w $scale(d %x) {
@start
	%a =d mul %x, d_10.0
	%b =d add %a, d_2.5
	%i =w dtosi %b
	ret %i
}
")

;; the CALLER side of varargs.  Apple puts everything after `...` on the stack;
;; Windows keeps walking the GPR sequence (x0-x7 ARE the first 64 bytes of the
;; imaginary stack), so the Apple rule here assembles, links, runs, and prints
;; garbage -- these two pin the Windows rule down by running it.
(defparameter *vararg-call* "
data $fmt = { b \"got %d and %d\", b 10, b 0 }

export function w $main() {
@start
	call $printf(l $fmt, ..., w 42, w 7)
	ret 0
}
")

;; SIMD registers are never used for variadic args, so a double travels in a GPR
;; as raw bits (`fmov x1, d0`).  %x is a parameter so it cannot be folded away.
(defparameter *vararg-float* "
data $fmt = { b \"f=%.1f i=%d\", b 10, b 0 }

export function w $show(d %x, w %n) {
@start
	call $printf(l $fmt, ..., d %x, w %n)
	ret 0
}
")

(defparameter *vararg-fn* "
export function w $f(w %n, ...) {
@start
	%ap =l alloc8 32
	vastart %ap
	%v =w vaarg %ap
	ret %v
}
")

;;; ============================================ 1. assembler dialect (any host)
(format t "~&--- 1. assembler dialect ---~%")

(let ((asm (win-asm *puts-data*)))
  (flet ((has (needle) (search needle asm)))
    ;; mach-o relocation syntax must be gone ...
    (if (or (has "@page") (has "@pageoff"))
        (bad "no mach-o @page/@pageoff" "still present in:~%~a" asm)
        (ok "no mach-o @page/@pageoff"))
    ;; ... replaced by the GNU/ELF form clang's integrated assembler wants
    (if (and (has "adrp") (has "#:lo12:"))
        (ok "uses adrp + #:lo12:")
        (bad "uses adrp + #:lo12:" "missing in:~%~a" asm))
    ;; no leading underscore on globals or externs
    (if (or (has "_main") (has "_str") (has "_puts"))
        (bad "no underscore prefix" "found one in:~%~a" asm)
        (ok "no underscore prefix"))
    (if (and (has "main:") (has "str:") (has "bl	puts"))
        (ok "bare symbol names")
        (bad "bare symbol names" "missing in:~%~a" asm))))

(let ((asm (win-asm *loop-sum*)))
  (if (search ".L" asm)
      (ok "`.L` local labels")
      (bad "`.L` local labels" "missing in:~%~a" asm)))

;; the fp constant pool: mach-o's size-classed __literal4/8/16 sections do not
;; exist on COFF; everything read-only goes to .rdata.
(let ((asm (win-asm *fp-pool*)))
  (cond
    ((search "__literal" asm) (bad "fp pool in .rdata" "still mach-o:~%~a" asm))
    ((not (search ".section .rdata" asm))
     (bad "fp pool in .rdata" "no .rdata section in:~%~a" asm))
    (t (ok "fp pool in .rdata"))))

;; ... and the mach-o side must not have been refactored away with it.
(let ((asm (qbe:a64-be-emit-module (qbe:parse-string *fp-pool*)
                                   qbe:*arm64-apple-target*)))
  (if (search "__TEXT,__literal8" asm)
      (ok "apple fp pool still mach-o")
      (bad "apple fp pool still mach-o" "no __literal8 section in:~%~a" asm)))

;;; ============================================== 2. vararg guard (any host)
(format t "~&--- 2. vararg guard ---~%")

;; Apple keeps working ...
(handler-case (progn (qbe:a64-be-emit-module (qbe:parse-string *vararg-fn*)
                                             qbe:*arm64-apple-target*)
                     (ok "apple target still emits varargs"))
  (error (e) (bad "apple target still emits varargs" "~a" e)))

;; ... while the Windows CALLEE side is still missing its prologue spill, so it
;; must refuse rather than hand out a va_list into a save area nobody filled.
(handler-case (progn (win-asm *vararg-fn*)
                     (bad "win rejects callee-side varargs" "emitted silently"))
  (error (e)
    (if (search "not implemented" (princ-to-string e))
        (ok "win rejects callee-side varargs")
        (bad "win rejects callee-side varargs" "unexpected error: ~a" e))))

;; the caller side IS implemented: a variadic call must lower, not raise.
(handler-case (progn (win-asm *vararg-call*) (ok "win lowers variadic calls"))
  (error (e) (bad "win lowers variadic calls" "~a" e)))

;; and the float must reach a GPR through a cast, not a SIMD parameter register.
(let ((asm (win-asm *vararg-float*)))
  (if (search "fmov	x" asm)
      (ok "variadic double casts into a GPR (fmov x, d)")
      (bad "variadic double casts into a GPR (fmov x, d)" "not in:~%~a" asm)))

;; and Apple must still lower a variadic call rather than raise with it.
(handler-case (progn (qbe:a64-be-emit-module (qbe:parse-string *vararg-call*)
                                             qbe:*arm64-apple-target*)
                     (ok "apple target still emits variadic calls"))
  (error (e) (bad "apple target still emits variadic calls" "~a" e)))

;;; ================================ 3. native execution (Windows ARM64 only)
(format t "~&--- 3. native execution ---~%")

(defun cc-triple ()
  "The target triple of `cc`, or NIL if it cannot be run."
  (ignore-errors
   (string-trim '(#\Newline #\Return #\Space)
                (uiop:run-program (list "cc" "-dumpmachine") :output :string))))

(defun windows-arm64-cc-p (triple)
  (and triple (search "aarch64" triple) (search "windows" triple)))

(defun tmp (name) (uiop:tmpize-pathname (merge-pathnames name (uiop:temporary-directory))))

(defun build (asm &optional driver)
  "Assemble ASM (+ optional C DRIVER) with `cc`; return the executable path."
  (let ((sf (tmp "qbe-a64win.s")) (exe (tmp "qbe-a64win.exe")))
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (let ((args (list "cc" (namestring sf))))
      (when driver
        (let ((cf (tmp "qbe-a64win.c")))
          (with-open-file (s cf :direction :output :if-exists :supersede)
            (write-string driver s))
          (setf args (append args (list (namestring cf))))))
      (uiop:run-program (append args (list "-o" (namestring exe))) :error-output :string))
    exe))

(defun run-exit (exe) (nth-value 2 (uiop:run-program (list (namestring exe))
                                                     :ignore-error-status t)))
(defun run-out (exe) (string-trim '(#\Newline #\Return #\Space)
                                  (uiop:run-program (list (namestring exe))
                                                    :output :string
                                                    :ignore-error-status t)))

(defun check (name src expect &key driver (reader #'run-exit))
  (handler-case
      (let ((got (funcall reader (build (win-asm src) driver))))
        (if (equal got expect)
            (ok name got)
            (bad name "got ~s want ~s" got expect)))
    (error (e) (bad name "~a" e))))

(let ((triple (cc-triple)))
  (cond
    ((not (windows-arm64-cc-p triple))
     (incf *skip* 6)
     (format t "~&  skip (cc is ~a, need an aarch64-*-windows cc)~%"
             (or triple "unavailable")))
    (t
     (check "loop-sum" *loop-sum* 45)
     (check "puts-data" *puts-data* "hello from qbe-cl on Windows ARM64"
            :reader #'run-out)
     (check "addmul (AAPCS64 args across a C boundary)" *addmul* "20"
            :driver "#include <stdio.h>
int addmul(int, int, int);
int main(void) { printf(\"%d\\n\", addmul(2, 3, 4)); return 0; }
"
            :reader #'run-out)
     ;; 4.0 * 10.0 + 2.5 = 42.5 -> 42, with both constants read from .rdata
     (check "fp pool (.rdata constants, double arg/return)" *fp-pool* "42"
            :driver "#include <stdio.h>
int scale(double);
int main(void) { printf(\"%d\\n\", scale(4.0)); return 0; }
"
            :reader #'run-out)
     ;; the payoff: printf actually reads x1/x2 and finds what we put there.
     (check "variadic call (ints in x1/x2)" *vararg-call* "got 42 and 7"
            :reader #'run-out)
     (check "variadic call (double via fmov into a GPR)" *vararg-float*
            "f=2.5 i=9"
            :driver "int show(double, int);
int main(void) { show(2.5, 9); return 0; }
"
            :reader #'run-out))))

;;; ------------------------------------------------------------------ verdict
(format t "~&=== arm64_win (dialect + vararg guard + native e2e) ===~%  ~
          ~d passed, ~d failed, ~d skipped~%" *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
