;;;; m1.lisp --- M1 walking-skeleton end-to-end tests (amd64).
;;;; Compiles tiny IL programs to a native executable via `cc`, runs them, and
;;;; checks the exit code.  Needs a working host C toolchain (cc); no qbe oracle.
;;;; usage: ros -Q run -- --script test/m1.lisp
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))

(defpackage #:qbe-m1 (:use #:cl))
(in-package #:qbe-m1)

(defvar *pass* 0)
(defvar *fail* 0)

(defun run-exe (exe)
  (multiple-value-bind (out err code)
      (uiop:run-program (list (namestring exe)) :output :string :ignore-error-status t)
    (declare (ignore err out))
    code))

(defun check (name src expect)
  "Compile a self-contained IL program (defines $main) and check its exit code."
  (handler-case
      (multiple-value-bind (code out asm) (qbe:compile-and-run src)
        (declare (ignore out))
        (if (eql code expect)
            (progn (incf *pass*) (format t "~&  ok   ~a (~d)~%" name code))
            (progn (incf *fail*)
                   (format t "~&  FAIL ~a: got ~d want ~d~%~a~%" name code expect asm))))
    (error (e) (incf *fail*) (format t "~&  FAIL ~a: ~a~%" name e))))

(defun check-drv (name src cdrv expect)
  "Compile an IL function and link it with a C driver; check the exit code."
  (handler-case
      (let ((asm (qbe:module-asm-string (qbe:parse-string src))))
        (uiop:with-temporary-file (:pathname sf :type "s")
          (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
          (uiop:with-temporary-file (:pathname cf :type "c")
            (with-open-file (s cf :direction :output :if-exists :supersede) (write-string cdrv s))
            (uiop:with-temporary-file (:pathname exe :type "out")
              (uiop:run-program (list "cc" (namestring sf) (namestring cf) "-o" (namestring exe))
                                :error-output :string)
              (let ((code (run-exe exe)))
                (if (eql code expect)
                    (progn (incf *pass*) (format t "~&  ok   ~a (~d)~%" name code))
                    (progn (incf *fail*)
                           (format t "~&  FAIL ~a: got ~d want ~d~%~a~%" name code expect asm))))))))
    (error (e) (incf *fail*) (format t "~&  FAIL ~a: ~a~%" name e))))

(format t "~&M1 end-to-end (amd64):~%")

(check "add-const" "export function w $main() {
@start
	%a =w add 40, 2
	ret %a
}" 42)

(check "chain" "export function w $main() {
@start
	%a =w sub 7, 2
	%b =w mul %a, 9
	ret %b
}" 45)

(check "bitops" "export function w $main() {
@start
	%a =w or 240, 15
	%b =w xor %a, 255
	ret %b
}" 0)

(check "neg" "export function w $main() {
@start
	%a =w sub 0, 100
	%b =w neg %a
	ret %b
}" 100)

(check "long-trunc" "export function w $main() {
@start
	%a =l mul 1000, 1000
	%b =w copy %a
	ret %b
}" 64)

(check-drv "params3"
  "export function w $add3(w %a, w %b, w %c) {
@start
	%t =w add %a, %b
	%r =w add %t, %c
	ret %r
}"
  "extern int add3(int,int,int); int main(){return add3(10,20,12);}"
  42)

(check-drv "params-long"
  "export function l $m(l %a, l %b) {
@start
	%r =l mul %a, %b
	ret %r
}"
  "extern long m(long,long); int main(){return (int)m(6,7);}"
  42)

;; --- milestone B: control flow, comparisons, loops (phi), memory ---

(check "branch-max" "export function w $main() {
@start
	%a =w copy 17
	%b =w copy 42
	%c =w csgtw %a, %b
	jnz %c, @ta, @tb
@ta
	ret %a
@tb
	ret %b
}" 42)

(check "loop-sum" "export function w $main() {
@start
	jmp @loop
@loop
	%i =w phi @start 1, @loop %i1
	%s =w phi @start 0, @loop %s1
	%s1 =w add %s, %i
	%i1 =w add %i, 1
	%done =w csgtw %i1, 10
	jnz %done, @end, @loop
@end
	ret %s1
}" 55)

(check "loop-fact" "export function w $main() {
@start
	jmp @loop
@loop
	%i =w phi @start 1, @loop %i1
	%f =w phi @start 1, @loop %f1
	%f1 =w mul %f, %i
	%i1 =w add %i, 1
	%c =w csgtw %i1, 5
	jnz %c, @end, @loop
@end
	ret %f1
}" 120)

(check "mem-alloc-load" "export function w $main() {
@start
	%p =l alloc4 8
	storew 30, %p
	%q =l add %p, 4
	storew 12, %q
	%a =w loadw %p
	%b =w loadw %q
	%r =w add %a, %b
	ret %r
}" 42)

;; parallel phi swap hazard (a,b exchange each iteration)
(check "phi-swap" "export function w $main() {
@start
	jmp @loop
@loop
	%a =w phi @start 10, @loop %b
	%b =w phi @start 32, @loop %a
	%n =w phi @start 0, @loop %n1
	%n1 =w add %n, 1
	%c =w csgtw %n1, 2
	jnz %c, @end, @loop
@end
	%r =w add %a, %b
	ret %r
}" 42)

(format t "~&=== M1/B: ~d passed, ~d failed ===~%" *pass* *fail*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
