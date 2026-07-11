;;;; e2e.lisp --- M4 end-to-end: full backend -> assemble -> link -> run.
;;;;
;;;; usage:  ros -Q run -- --script test/e2e.lisp
;;;;
;;;; Exercises the whole amd64 backend (ssa..gvn..gcm..ifconvert..abi..isel..
;;;; spill..rega..simpljmp..emit) on self-contained programs and checks the exit
;;;; code / driver output.  Deliberately covers the patterns where rega's
;;;; register CHOICE diverges from QBE (phi-carried loop variables, multiple
;;;; live phis, param coalescing, nested control) to arbitrate that those
;;;; divergences are functionally correct, not miscompiles.
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(defpackage #:qbe-e2e (:use #:cl)) (in-package #:qbe-e2e)

(defvar *pass* 0) (defvar *fail* 0)

(defun asm-of (src) (qbe:be-emit-module (qbe:parse-string src)))

(defun build (asm &optional driver)
  "Assemble ASM (+ optional C DRIVER), return the executable pathname (kept)."
  (let ((sf (uiop:tmpize-pathname #p"/tmp/e2e.s"))
        (exe (uiop:tmpize-pathname #p"/tmp/e2e.out")))
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (let ((args (list "cc" (namestring sf))))
      (when driver
        (let ((cf (uiop:tmpize-pathname #p"/tmp/e2e.c")))
          (with-open-file (s cf :direction :output :if-exists :supersede) (write-string driver s))
          (setf args (append args (list (namestring cf))))))
      (uiop:run-program (append args (list "-o" (namestring exe))) :error-output :string))
    exe))

(defun run-exit (exe)
  (nth-value 2 (uiop:run-program (list (namestring exe)) :ignore-error-status t)))
(defun run-out (exe)
  (string-trim '(#\Newline #\Space)
               (uiop:run-program (list (namestring exe)) :output :string :ignore-error-status t)))

(defun check (name src expect &optional driver (reader #'run-exit))
  (handler-case
      (let* ((exe (build (asm-of src) driver)) (got (funcall reader exe)))
        (if (equal got expect)
            (progn (incf *pass*) (format t "~&  ok   ~a => ~a~%" name got))
            (progn (incf *fail*) (format t "~&  FAIL ~a: got ~a want ~a~%" name got expect))))
    (error (e) (incf *fail*) (format t "~&  FAIL ~a: ~a~%" name e))))

;; --- arithmetic / bitops ---
(check "arith" "export function w $main() {
@start
  %a =w mul 6, 7
  %b =w sub %a, 0
  %c =w and %b, 255
  ret %c
}" 42)

;; --- signed division / remainder ---
(check "sdiv" "export function w $main() {
@start
  %q =w div 100, 7
  %r =w rem 100, 7
  %x =w add %q, %r    # 14 + 2 = 16
  ret %x
}" 16)

;; --- unsigned compare + shift ---
(check "shift" "export function w $main() {
@start
  %a =w shl 1, 5      # 32
  %b =w shr %a, 2     # 8
  ret %b
}" 8)

;; --- single loop with phi (sum 1..9 = 45) ---
(check "loop-sum" "export function w $main() {
@start
  jmp @loop
@loop
  %s =w phi @start 0, @body %s2
  %i =w phi @start 0, @body %i2
  %c =w csltw %i, 9
  jnz %c, @body, @end
@body
  %i2 =w add %i, 1
  %s2 =w add %s, %i2
  jmp @loop
@end
  ret %s
}" 45)

;; --- multiple live phis (fib(10) = 55) ---
(check "fib" "export function w $main() {
@start
  jmp @loop
@loop
  %a =w phi @start 0, @body %b
  %b =w phi @start 1, @body %n
  %i =w phi @start 0, @body %i2
  %c =w csltw %i, 10
  jnz %c, @body, @end
@body
  %n =w add %a, %b
  %i2 =w add %i, 1
  jmp @loop
@end
  ret %a
}" 55)

;; --- if-conversion -> cmov (max) via driver over many inputs ---
(check "select-max" "export function w $maxw(w %a, w %b) {
@start
  %c =w csgtw %a, %b
  jnz %c, @ta, @tb
@ta
  jmp @end
@tb
  jmp @end
@end
  %m =w phi @ta %a, @tb %b
  ret %m
}"
  "77"
  "#include <stdio.h>
extern int maxw(int,int);
int main(){int s=0;int v[]={-3,5,5,-9,77,2};for(int i=0;i<6;i+=2){int m=maxw(v[i],v[i+1]);if(m>s)s=m;}printf(\"%d\",s);return 0;}"
  #'run-out)

;; --- recursion (factorial 5 = 120) exercises calls + callee-save ---
(check "fact" "export function w $fact(w %n) {
@start
  %c =w csgtw %n, 1
  jnz %c, @rec, @base
@base
  ret 1
@rec
  %n1 =w sub %n, 1
  %r =w call $fact(w %n1)
  %f =w mul %n, %r
  ret %f
}
export function w $main() {
@start
  %r =w call $fact(w 5)
  ret %r
}" 120)

;; --- nested loop (multiply via addition: 7*8 = 56) ---
(check "nested" "export function w $main() {
@start
  jmp @o
@o
  %i =w phi @start 0, @od %i1
  %acc =w phi @start 0, @od %acc2
  %co =w csltw %i, 8
  jnz %co, @ob, @done
@ob
  jmp @in
@in
  %j =w phi @ob 0, @ib %j1
  %acc1 =w phi @ob %acc, @ib %acc3
  %ci =w csltw %j, 7
  jnz %ci, @ib, @od
@ib
  %acc3 =w add %acc1, 1
  %j1 =w add %j, 1
  jmp @in
@od
  %acc2 =w copy %acc1
  %i1 =w add %i, 1
  jmp @o
@done
  ret %acc
}" 56)

;; --- slice d: a fast-local alloc + store + load ---
(check "local-mem" "export function w $main() {
@start
  %p =l alloc4 4
  storew 42, %p
  %v =w loadw %p
  ret %v
}" 42)

;; --- slice d: base + scale*index addressing over a summed local array ---
(check "array-sum" "export function w $main() {
@start
  %p =l alloc4 16
  storew 10, %p
  %p1 =l add %p, 4
  storew 20, %p1
  %p2 =l add %p, 8
  storew 30, %p2
  jmp @loop
@loop
  %i =w phi @start 0, @body %i2
  %s =w phi @start 0, @body %s2
  %c =w csltw %i, 3
  jnz %c, @body, @end
@body
  %io =l extsw %i
  %o =l mul %io, 4
  %e =l add %p, %o     # exercises [S0 + 4 * %io]
  %v =w loadw %e
  %s2 =w add %s, %v
  %i2 =w add %i, 1
  jmp @loop
@end
  ret %s
}" 60)

;; --- slice e-2b: float constants (stashed .Lfp slots) + dtosi ---
(check "float-arith" "export function w $main() {
@start
  %a =d add d_1.5, d_2.5    # 4.0
  %b =d mul %a, d_10.0      # 40.0
  %r =w dtosi %b            # 40
  ret %r
}" 40)

;; --- slice e-2b: float -> unsigned long (the magic-constant sequence) ---
(check "ftoui" "export function l $main() {
@start
  %a =d add d_0.0, d_100.0
  %r =l dtoui %a
  ret %r
}" 100)

;; --- abi B2: pass a 16-byte struct by value (2 integer eightbytes) ---
(check "struct-arg" "type :pair = { l, l }
export function l $sum(:pair %p) {
@start
  %a =l loadl %p
  %p8 =l add %p, 8
  %b =l loadl %p8
  %r =l add %a, %b
  ret %r
}
export function l $main() {
@start
  %s =l alloc8 16
  storel 30, %s
  %s8 =l add %s, 8
  storel 12, %s8
  %r =l call $sum(:pair %s)
  ret %r
}" 42)

;; --- abi B2: return a small struct by value (one integer eightbyte) ---
(check "struct-ret" "type :pt = { w, w }
export function :pt $mk(w %a, w %b) {
@start
  %p =l alloc4 8
  storew %a, %p
  %p4 =l add %p, 4
  storew %b, %p4
  ret %p
}
export function w $main() {
@start
  %r =:pt call $mk(w 30, w 12)
  %a =w loadw %r
  %r4 =l add %r, 4
  %b =w loadw %r4
  %s =w add %a, %b
  ret %s
}" 42)

;; --- abi B2: variadic call + va_start + va_arg ---
(check "vararg" "export function w $sum3(w %cnt, ...) {
@start
  %ap =l alloc8 24
  vastart %ap
  %a =w vaarg %ap
  %b =w vaarg %ap
  %c =w vaarg %ap
  %s1 =w add %a, %b
  %s =w add %s1, %c
  ret %s
}
export function w $main() {
@start
  %r =w call $sum3(w 3, ..., w 20, w 15, w 7)
  ret %r
}" 42)

(format t "~&=== M4 e2e (full backend -> run) ===~%  ~d passed, ~d failed~%" *pass* *fail*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
