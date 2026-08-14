;;;; arm64-elf.lisp --- the arm64 (ELF/Linux) target: assembler dialect, the
;;;; AAPCS64 rules that distinguish it from Apple/Windows, and end-to-end
;;;; native execution inside a linux/arm64 container.
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-elf.lisp
;;;;
;;;; test/arm64-abi.lisp pins the shared lowering against `qbe -t arm64_apple
;;;; -dA` and test/arm64-elf-corpus-e2e.lisp runs the corpus on Linux.  What
;;;; this file covers:
;;;;
;;;;   1. the assembler dialect -- no `_` prefix, `.L` locals, `.balign 16`,
;;;;      `.type`/`.size` footers, the GNU-stack note, `.rodata` literals.
;;;;      Each check has an Apple twin so the mach-o side cannot be
;;;;      refactored away with it.
;;;;   2. the ELF relocations -- extern addresses through `:got:`/`:got_lo12:`
;;;;      and local-exec TLS through tpidr_el0 + `:tprel_hi12:`/`:tprel_lo12_nc:`.
;;;;   3. elimsb -- sub-word call args degrade to word ops instead of growing
;;;;      Apple's explicit extensions.
;;;;   4. the AAPCS64 vararg machinery -- the 192-byte register save area
;;;;      pushed ahead of the frame and the 4-field va_list walking it.
;;;;   5. that all of it runs and agrees with the platform C compiler, inside
;;;;      a linux/arm64 container (native on Apple Silicon; self-skips
;;;;      without docker).
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(defpackage #:qbe-arm64-elf (:use #:cl)) (in-package #:qbe-arm64-elf)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

(defun ok (name &rest args)
  (incf *pass*) (format t "~&  ok   ~a~@[ => ~a~]~%" name (car args)))
(defun bad (name fmt &rest args)
  (incf *fail*) (format t "~&  FAIL ~a: ~?~%" name fmt args))

(defun elf-asm (src)
  (qbe:a64-be-emit-module (qbe:parse-string src) qbe:*arm64-elf-target*))
(defun apple-asm (src)
  (qbe:a64-be-emit-module (qbe:parse-string src) qbe:*arm64-apple-target*))

;;; --------------------------------------------------------------- fixtures
(defparameter *loop-sum* "
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
")

(defparameter *addmul* "
export function w $addmul(w %a, w %b, w %c) {
@start
	%t =w add %a, %b
	%r =w mul %t, %c
	ret %r
}
")

(defparameter *fp-pool* "
export function w $scale(d %x) {
@start
	%a =d mul %x, d_10.0
	%b =d add %a, d_2.5
	%i =w dtosi %b
	ret %i
}
")

(defparameter *extern-ref* "
export function l $get_addr() {
@start
	%p =l copy extern $myglobal
	ret %p
}
export function w $get_val() {
@start
	%p =l copy extern $myglobal
	%v =w loadw %p
	ret %v
}
")

(defparameter *thread-var* "
export thread data $tvar = align 4 {w 77}

export function l $tls_addr() {
@start
	%p =l copy thread $tvar
	ret %p
}
export function w $tls_val() {
@start
	%v =w loadw thread $tvar
	ret %v
}
")

(defparameter *subword-call* "
export function w $caller(w %x) {
@start
	%r =w call $callee(sb %x)
	ret %r
}
")

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

;; doubles walk the vr half of the save area, ints the gr half -- the check
;; that the two cursors are independent.
(defparameter *vararg-mixed* "
export function d $sumd(w %n, ...) {
@start
	%ap =l alloc8 32
	vastart %ap
	%s =d copy d_0
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

(defparameter *vararg-call* "
data $fmt = { b \"got %d and %d\", b 10, b 0 }

export function w $prints() {
@start
	call $printf(l $fmt, ..., w 42, w 7)
	ret 0
}
")

(defparameter *structs* "
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

export function l $call2(l %x, l %y) {
@start
	%s =l alloc8 16
	storel %x, %s
	%p =l add %s, 8
	storel %y, %p
	%r =l call $ctake2(:two %s)
	ret %r
}
")

;;; ============================================ 1. assembler dialect (any host)
(format t "~&--- 1. assembler dialect ---~%")

(let ((elf (elf-asm *loop-sum*)) (mac (apple-asm *loop-sum*)))
  (if (and (search ".globl loopsum" elf) (not (search "_loopsum" elf)))
      (ok "no `_` prefix")
      (bad "no `_` prefix" "not in:~%~a" elf))
  (if (search "_loopsum:" mac) (ok "apple still `_`-prefixed")
      (bad "apple still `_`-prefixed" "not in:~%~a" mac))
  (if (and (search ".L" elf) (not (search "~aLbb" elf)))
      (ok "`.L` local labels")
      (bad "`.L` local labels" "not in:~%~a" elf))
  (if (search ".balign 16" elf)
      (ok "functions .balign 16")
      (bad "functions .balign 16" "not in:~%~a" elf))
  (if (search ".balign 4" mac) (ok "apple still .balign 4")
      (bad "apple still .balign 4" "not in:~%~a" mac))
  (if (and (search ".type loopsum, @function" elf)
           (search ".size loopsum, .-loopsum" elf)
           (search ".note.GNU-stack" elf))
      (ok ".type/.size footer + GNU-stack note")
      (bad ".type/.size footer + GNU-stack note" "not in:~%~a" elf))
  (if (or (search ".type" mac) (search ".note.GNU-stack" mac))
      (bad "apple still footer-free" "present in:~%~a" mac)
      (ok "apple still footer-free")))

(let ((elf (elf-asm *fp-pool*)) (mac (apple-asm *fp-pool*)))
  (if (and (search "\".Lfp0\"" elf) (search ".section .rodata" elf))
      (ok "fp pool .rodata/.Lfp0")
      (bad "fp pool .rodata/.Lfp0" "not in:~%~a" elf))
  (if (search ".section __TEXT,__literal8,8byte_literals" mac)
      (ok "apple fp pool still __TEXT,__literal8")
      (bad "apple fp pool still __TEXT,__literal8" "not in:~%~a" mac)))

;;; ================================================= 2. ELF relocations
(format t "~&--- 2. ELF relocations ---~%")

(let ((elf (elf-asm *extern-ref*)) (mac (apple-asm *extern-ref*)))
  (if (and (search "adrp" elf) (search ":got:myglobal" elf)
           (search "#:got_lo12:myglobal" elf))
      (ok "extern through :got:/:got_lo12:")
      (bad "extern through :got:/:got_lo12:" "not in:~%~a" elf))
  (if (search "_myglobal@gotpage" mac)
      (ok "apple extern still @gotpage")
      (bad "apple extern still @gotpage" "not in:~%~a" mac)))

(let ((elf (elf-asm *thread-var*)) (mac (apple-asm *thread-var*)))
  (if (and (search "mrs" elf) (search "tpidr_el0" elf)
           (search "#:tprel_hi12:tvar, lsl #12" elf)
           (search "#:tprel_lo12_nc:tvar" elf))
      (ok "TLS via tpidr_el0 + tprel")
      (bad "TLS via tpidr_el0 + tprel" "not in:~%~a" elf))
  (if (search ".section .tdata,\"awT\"" elf)
      (ok "thread data in .tdata")
      (bad "thread data in .tdata" "not in:~%~a" elf))
  (if (and (search "_tvar@tlvppage" mac) (search "__thread_vars" mac))
      (ok "apple TLS still @tlvppage + __thread_vars")
      (bad "apple TLS still @tlvppage + __thread_vars" "not in:~%~a" mac)))

;;; ====================================================== 3. elimsb (abi0)
(format t "~&--- 3. elimsb ---~%")

(let ((elf (elf-asm *subword-call*)) (mac (apple-asm *subword-call*)))
  (if (search "sxtb" mac) (ok "apple still extends an `sb` arg (sxtb)")
      (bad "apple still extends an `sb` arg (sxtb)" "not in:~%~a" mac))
  (if (search "sxtb" elf)
      (bad "elimsb: no extension on ELF" "sxtb present in:~%~a" elf)
      (ok "elimsb: no extension on ELF")))

;;; ============================================== 4. AAPCS64 vararg machinery
(format t "~&--- 4. AAPCS64 varargs ---~%")

(let ((elf (elf-asm *vararg-callee*)) (mac (apple-asm *vararg-callee*)))
  (if (and (search "str	q7, [sp, -16]!" elf)
           (search "stp	x0, x1, [sp, -16]!" elf))
      (ok "prologue pushes the 192-byte save area")
      (bad "prologue pushes the 192-byte save area" "not in:~%~a" elf))
  (if (or (search "str	q7" mac) (search "stp	x0, x1, [sp, -16]!" mac))
      (bad "apple still has no save area" "present in:~%~a" mac)
      (ok "apple still has no save area")))

;;; ======================== 5. native execution (linux/arm64 container)
(format t "~&--- 5. native execution ---~%")

(defparameter *image* (or (uiop:getenv "DOCKER_IMAGE") "gcc:14"))

(defun docker-arm64-p ()
  (zerop (nth-value 2 (uiop:run-program
                       (list "docker" "run" "--rm" "--platform" "linux/arm64"
                             *image* "true")
                       :ignore-error-status t))))

(defparameter *work*
  (merge-pathnames (format nil "qbe-a64elf-t-~d/" (random (expt 36 6) (make-random-state t)))
                   (uiop:temporary-directory)))

(defparameter *checks* '())

(defun stage (name src expect driver)
  "Stage one native check: NAME.{s,c,expect} under *work*."
  (with-open-file (s (merge-pathnames (format nil "~a.s" name) *work*)
                     :direction :output :if-exists :supersede)
    (write-string (elf-asm src) s))
  (with-open-file (s (merge-pathnames (format nil "~a.c" name) *work*)
                     :direction :output :if-exists :supersede)
    (write-string driver s))
  (with-open-file (s (merge-pathnames (format nil "~a.expect" name) *work*)
                     :direction :output :if-exists :supersede)
    (write-line expect s))
  (push name *checks*))

(defparameter *runner* "#!/bin/sh
cd /w
for s in *.s; do
  n=${s%.s}
  if ! cc $n.s $n.c -o $n.bin -lpthread -lm 2>$n.ccerr; then
    echo \"FAIL $n: link: $(head -c 120 $n.ccerr | tr '\\n' ' ')\"
    continue
  fi
  ./$n.bin >$n.got 2>/dev/null
  if diff -q $n.got $n.expect >/dev/null 2>&1; then echo \"ok $n\"
  else echo \"FAIL $n: got [$(cat $n.got)] want [$(cat $n.expect)]\"; fi
done
")

(cond
  ((not (docker-arm64-p))
   (incf *skip* 7)
   (format t "~&  skip (no docker/linux-arm64)~%"))
  (t
   (ensure-directories-exist *work*)
   (stage "addmul" *addmul* "20"
          "#include <stdio.h>
int addmul(int, int, int);
int main(void) { printf(\"%d\\n\", addmul(2, 3, 4)); return 0; }
")
   (stage "fppool" *fp-pool* "42"
          "#include <stdio.h>
int scale(double);
int main(void) { printf(\"%d\\n\", scale(4.0)); return 0; }
")
   (stage "structs" *structs* "7 30 300"
          "#include <stdio.h>
struct one { long long a; };
struct two { long long a, b; };
long long take1(struct one);
long long take2(struct two);
long long call2(long long, long long);
long long ctake2(struct two s) { return s.a * 100 + s.b; }
int main(void) {
  struct one o = {7};
  struct two t = {10, 20};
  printf(\"%lld %lld %lld\\n\", take1(o), take2(t), call2(2, 100));
  return 0;
}
")
   ;; sumn(9, ...) drains the 8 GPR slots of the save area and crosses into
   ;; the stack half -- the seam va_list has to survive.
   (stage "varargint" *vararg-callee* "60 0 45"
          "#include <stdio.h>
int sumn(int, ...);
int main(void) {
  printf(\"%d %d %d\\n\", sumn(3,10,20,30), sumn(0), sumn(9,1,2,3,4,5,6,7,8,9));
  return 0;
}
")
   ;; sumd(9, ...) does the same to the 8 FPR slots; gr/vr cursors must not mix.
   (stage "varargfp" *vararg-mixed* "60.0 0.0 4.5"
          "#include <stdio.h>
double sumd(int, ...);
int main(void) {
  printf(\"%.1f %.1f %.1f\\n\", sumd(3,10.0,20.0,30.0), sumd(0),
         sumd(9,.1,.2,.3,.4,.5,.6,.7,.8,.9));
  return 0;
}
")
   (stage "varargcall" *vararg-call* "got 42 and 7"
          "int prints(void);
int main(void) { return prints(); }
")
   (stage "externgot" *extern-ref* "same 1234"
          "#include <stdio.h>
int myglobal = 1234;
void *get_addr(void);
int get_val(void);
int main(void) {
  void *ours = get_addr(), *theirs = (void *)&myglobal;
  printf(\"%s %d\\n\", ours == theirs ? \"same\" : \"DIFFERENT\", get_val());
  return 0;
}
")
   (stage "tls" *thread-var* "same 77"
          "#include <stdio.h>
extern __thread int tvar;
void *tls_addr(void);
int tls_val(void);
int main(void) {
  printf(\"%s %d\\n\", tls_addr() == &tvar ? \"same\" : \"DIFFERENT\", tls_val());
  return 0;
}
")
   (with-open-file (s (merge-pathnames "runner.sh" *work*)
                      :direction :output :if-exists :supersede)
     (write-string *runner* s))
   (let ((out (uiop:run-program
               (list "docker" "run" "--rm" "--platform" "linux/arm64"
                     "-v" (format nil "~a:/w" (namestring *work*))
                     *image* "sh" "/w/runner.sh")
               :output :string :error-output :string :ignore-error-status t)))
     (dolist (l (uiop:split-string out :separator '(#\Newline)))
       (cond ((uiop:string-prefix-p "ok " l)
              (incf *pass*) (format t "~&  ok   ~a (native)~%" (subseq l 3)))
             ((uiop:string-prefix-p "FAIL " l)
              (incf *fail*) (format t "~&  ~a~%" l)))))
   (uiop:delete-directory-tree *work* :validate t :if-does-not-exist :ignore)))

;;; ------------------------------------------------------------------ verdict
(format t "~&=== arm64 ELF (dialect + AAPCS64 + native e2e) ===~%  ~
          ~d passed, ~d failed, ~d skipped~%" *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
