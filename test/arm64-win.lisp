;;;; arm64-win.lisp --- the arm64_win target: assembler dialect, varargs, and
;;;; (on a Windows ARM64 host) end-to-end native execution.
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-win.lisp
;;;;
;;;; Windows on ARM64 documents its non-variadic ABI as plain AAPCS64, so
;;;; *arm64-win-target* shares the register model / isel / abi1 / emit passes
;;;; with Apple verbatim.  Only three things differ, and this file pins all of
;;;; them down:
;;;;
;;;;   1. assembler dialect -- no `_` symbol prefix, `.L` locals, mach-o's
;;;;      `@page` / `@pageoff` replaced by `adrp X, sym` + `#:lo12:sym`, and the
;;;;      fp pool in `.rdata` rather than __literal4/8/16.
;;;;   2. varargs -- neither Apple's all-on-the-stack rule nor AAPCS64's
;;;;      192-byte GPR+FPR save area.  One imaginary stack whose first 64 bytes
;;;;      are x0-x7, no SIMD register ever used, so a variadic double travels as
;;;;      raw bits through a GPR and the callee spills x0-x7 in its prologue.
;;;;   3. that the result actually runs.
;;;;
;;;; 1 and 2 are checked textually and run on any host -- they also guard the
;;;; Apple side against being refactored away.  3 needs a Windows ARM64 host and
;;;; self-skips elsewhere, detected via `cc -dumpmachine`.
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

;; the CALLEE side.  The prologue spills x0-x7 into the 64 bytes just below the
;; incoming stack arguments, so `sumn(9, 1..9)` -- 10 slots, one more than fits
;; in registers -- only adds up if that area and the stack half are contiguous.
(defparameter *vararg-callee* "
export function w $sumn(w %n, ...) {
@start
	%ap =l alloc8 32
	vastart %ap
	%s =w copy 0
	%i =w copy 0
	jmp @loop
@loop
	%c =w csltw %i, %n
	jnz %c, @body, @end
@body
	%v =w vaarg %ap
	%s =w add %s, %v
	%i =w add %i, 1
	jmp @loop
@end
	ret %s
}
")

;; a variadic double arrives as raw bits in a GPR slot, so `vaarg =d` has to
;; read those 8 bytes back as a double.
(defparameter *vararg-callee-d* "
export function d $sumd(w %n, ...) {
@start
	%ap =l alloc8 32
	vastart %ap
	%s =d copy d_0.0
	%i =w copy 0
	jmp @loop
@loop
	%c =w csltw %i, %n
	jnz %c, @body, @end
@body
	%v =d vaarg %ap
	%s =d add %s, %v
	%i =w add %i, 1
	jmp @loop
@end
	ret %s
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

;; ... and the Windows callee spills the argument registers in its prologue.
(let ((asm (win-asm *vararg-fn*)))
  (if (and (search "stp	x0, x1, [x29," asm) (search "stp	x6, x7, [x29," asm))
      (ok "win spills x0-x7 in the prologue")
      (bad "win spills x0-x7 in the prologue" "not in:~%~a" asm)))

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
     (incf *skip* 8)
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
            :reader #'run-out)
     ;; sumn(9, 1..9) needs 10 slots, so it walks off the register half and into
     ;; the incoming stack arguments -- the contiguity check.
     (check "variadic callee (ints, incl. spilling past x7)" *vararg-callee*
            "60 0 45"
            :driver "#include <stdio.h>
int sumn(int, ...);
int main(void) {
  printf(\"%d %d %d\\n\", sumn(3,10,20,30), sumn(0), sumn(9,1,2,3,4,5,6,7,8,9));
  return 0;
}
"
            :reader #'run-out)
     (check "variadic callee (doubles read back from GPR slots)" *vararg-callee-d*
            "7.0 0.2"
            :driver "#include <stdio.h>
double sumd(int, ...);
int main(void) { printf(\"%.1f %.1f\\n\", sumd(3,1.5,2.5,3.0), sumd(1,0.25)); return 0; }
"
            :reader #'run-out))))

;;; ------------------------------------------------------------------ verdict
(format t "~&=== arm64_win (dialect + vararg guard + native e2e) ===~%  ~
          ~d passed, ~d failed, ~d skipped~%" *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
