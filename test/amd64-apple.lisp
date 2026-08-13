;;;; amd64-apple.lisp --- the amd64_apple target: assembler dialect, mach-o TLS,
;;;; and end-to-end native execution through Rosetta 2 (or an Intel Mac).
;;;;
;;;; usage:  ros -Q run -- --script test/amd64-apple.lisp
;;;;
;;;; The ABI *is* SysV -- T_amd64_apple shares abi1/isel/registers with
;;;; T_amd64_sysv -- so test/abi.lisp already pins the lowering down and
;;;; test/amd64-apple-corpus-e2e.lisp runs the corpus.  What this file covers:
;;;;
;;;;   1. the assembler dialect -- `_`-prefixed globals, bare `L` local labels,
;;;;      no ELF symbol-size footer or GNU-stack note, no `@plt`, fp constants
;;;;      in `__TEXT,__literal*` sections.  Each check has a SysV twin so the
;;;;      ELF side cannot be refactored away with it.
;;;;   2. mach-o TLS -- the `@tlvp` access sequence isel builds (descriptor ->
;;;;      resolver call, rdi in, rax out) and the `__thread_vars` /
;;;;      `$tlv$init` / `__tlv_bootstrap` data machinery behind it.
;;;;   3. extern symbol addresses through the GOT -- shared with ELF, but the
;;;;      apple side must keep the `_` prefix on the @gotpcrel operand.
;;;;   4. that all of it runs and agrees with the platform C compiler: SysV
;;;;      argument registers across a C boundary, the fp pool, aggregates,
;;;;      varargs, the GOT address, and a C `__thread` variable seen from IL.
;;;;
;;;; 1-3 are textual and run on any host.  4 needs a cc that can target
;;;; x86_64 Mach-O and a host that can execute it (macOS: Rosetta makes
;;;; `cc -arch x86_64` + exec work transparently); it self-skips elsewhere.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(defpackage #:qbe-amd64-apple (:use #:cl)) (in-package #:qbe-amd64-apple)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

(defun ok (name &rest args)
  (incf *pass*) (format t "~&  ok   ~a~@[ => ~a~]~%" name (car args)))
(defun bad (name fmt &rest args)
  (incf *fail*) (format t "~&  FAIL ~a: ~?~%" name fmt args))

(defun apple-asm (src)
  (qbe:be-emit-module (qbe:parse-string src) qbe:*amd64-apple-target*))
(defun sysv-asm (src)
  (qbe:be-emit-module (qbe:parse-string src) qbe:*amd64-sysv-target*))

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

(defparameter *vararg-call* "
data $fmt = { b \"got %d and %d\", b 10, b 0 }

export function w $prints() {
@start
	call $printf(l $fmt, ..., w 42, w 7)
	ret 0
}
")

;; The SysV aggregate rule: both a one-quad and a two-quad struct travel in
;; registers (RDI / RDI+RSI); ctake2 checks the CALLER side agrees with cc.
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

(let ((mac (apple-asm *loop-sum*)) (elf (sysv-asm *loop-sum*)))
  ;; T_amd64_apple.assym is "_"
  (if (and (search ".globl _loopsum" mac) (search "_loopsum:" mac))
      (ok "`_` prefix on globals")
      (bad "`_` prefix on globals" "not in:~%~a" mac))
  (if (and (search ".globl loopsum" elf) (not (search "_loopsum" elf)))
      (ok "sysv still unprefixed")
      (bad "sysv still unprefixed" "not in:~%~a" elf))
  ;; T_amd64_apple.asloc is bare "L"
  (if (and (search "Lbb" mac) (not (search ".Lbb" mac)))
      (ok "bare `L` local labels")
      (bad "bare `L` local labels" "not in:~%~a" mac))
  (if (search ".Lbb" elf) (ok "sysv still uses `.Lbb`")
      (bad "sysv still uses `.Lbb`" "not in:~%~a" elf))
  ;; the shared emitfn skips elf_emitfnfin when T.apple, and macho_emitfin
  ;; appends no note
  (if (or (search ".type" mac) (search ".size" mac))
      (bad "no .type/.size footer" "still present in:~%~a" mac)
      (ok "no .type/.size footer"))
  (if (search ".note.GNU-stack" mac)
      (bad "no .note.GNU-stack" "still present in:~%~a" mac)
      (ok "no .note.GNU-stack"))
  (if (and (search ".type" elf) (search ".note.GNU-stack" elf))
      (ok "sysv still emits the ELF footer + note")
      (bad "sysv still emits the ELF footer + note" "not in:~%~a" elf))
  ;; unlike amd64_win, apple shares the SysV emitter's loop-header alignment
  (if (search ".p2align 4" mac)
      (ok "loop headers still .p2align 4 (shared emitfn)")
      (bad "loop headers still .p2align 4 (shared emitfn)" "not in:~%~a" mac)))

;; the fp-const pool: `Lfp` labels (quoted, so no `_` sneaks in) in the mach-o
;; literal sections instead of .rodata
(let ((mac (apple-asm *fp-pool*)) (elf (sysv-asm *fp-pool*)))
  (if (and (search "\"Lfp0\"" mac) (not (search ".Lfp0" mac)))
      (ok "fp pool labelled Lfp0")
      (bad "fp pool labelled Lfp0" "not in:~%~a" mac))
  (if (search ".section __TEXT,__literal8,8byte_literals" mac)
      (ok "fp pool in __TEXT,__literal8")
      (bad "fp pool in __TEXT,__literal8" "not in:~%~a" mac))
  (if (and (search "\".Lfp0\"" elf) (search ".section .rodata" elf))
      (ok "sysv fp pool still .rodata/.Lfp0")
      (bad "sysv fp pool still .rodata/.Lfp0" "not in:~%~a" elf)))

;; `@plt` is an ELF decoration; mach-o resolves through a linker-built stub.
(let ((src "
export function w $c() {
@start
	%r =w call extern $extfn()
	ret %r
}
"))
  (let ((mac (apple-asm src)) (elf (sysv-asm src)))
    (if (and (search "callq _extfn" mac) (not (search "@plt" mac)))
        (ok "callq _extfn, no @plt")
        (bad "callq _extfn, no @plt" "not in:~%~a" mac))
    (if (search "callq extfn@plt" elf) (ok "sysv still emits @plt")
        (bad "sysv still emits @plt" "not in:~%~a" elf))))

;; apple keeps the 176-byte SysV vararg register-save area (twin of the
;; amd64-win check that it is absent there)
(let ((mac (apple-asm *vararg-callee*)))
  (if (and (search "movaps %xmm0" mac) (search "-176(%rbp)" mac))
      (ok "vararg keeps the 176-byte SysV save area")
      (bad "vararg keeps the 176-byte SysV save area" "not in:~%~a" mac)))

;; data labels carry the prefix too
(let ((mac (apple-asm *vararg-call*)) (elf (sysv-asm *vararg-call*)))
  (if (and (search "_fmt:" mac) (search "leaq _fmt(%rip)" mac))
      (ok "`_` prefix on data + its uses")
      (bad "`_` prefix on data + its uses" "not in:~%~a" mac))
  (if (and (search "fmt:" elf) (not (search "_fmt" elf)))
      (ok "sysv data still unprefixed")
      (bad "sysv data still unprefixed" "not in:~%~a" elf)))

;;; ======================================================== 2. mach-o TLS
(format t "~&--- 2. mach-o TLS ---~%")

(let ((mac (apple-asm *thread-var*)))
  ;; the access sequence: descriptor address from @tlvp, resolver out of its
  ;; first quad, rdi = descriptor, result in rax (amd64/isel.c fixarg +
  ;; amd64/emit.c Oaddr)
  (if (search "movq _tvar@tlvp(%rip), %rdi" mac)
      (ok "@tlvp descriptor load into rdi")
      (bad "@tlvp descriptor load into rdi" "not in:~%~a" mac))
  (if (and (search "movq (%rdi), %rax" mac) (search "callq *%rax" mac))
      (ok "resolver call through the descriptor")
      (bad "resolver call through the descriptor" "not in:~%~a" mac))
  ;; the data machinery: a descriptor record in __thread_vars pointing the
  ;; bootstrap resolver at the $tlv$init template
  (if (search ".section __DATA,__thread_vars,thread_local_variables" mac)
      (ok "__thread_vars section")
      (bad "__thread_vars section" "not in:~%~a" mac))
  (if (and (search "_tvar:" mac)
           (search ".quad __tlv_bootstrap" mac)
           (search ".quad _tvar$tlv$init" mac))
      (ok "descriptor record: __tlv_bootstrap -> $tlv$init")
      (bad "descriptor record: __tlv_bootstrap -> $tlv$init" "not in:~%~a" mac))
  (if (and (search ".section __DATA,__thread_data,thread_local_regular" mac)
           (search "_tvar$tlv$init:" mac))
      (ok "template in __thread_data")
      (bad "template in __thread_data" "not in:~%~a" mac)))

;; SysV must still use the ELF .tdata section, untouched.
(let ((elf (sysv-asm "thread data $tvar = align 4 {w 77}")))
  (if (and (search ".section .tdata,\"awT\"" elf) (not (search "tlv" elf)))
      (ok "sysv thread data still .tdata")
      (bad "sysv thread data still .tdata" "not in:~%~a" elf)))

;;; ==================================== 3. extern addresses through the GOT
(format t "~&--- 3. extern symbol addresses ---~%")

(let ((mac (apple-asm *extern-ref*)) (elf (sysv-asm *extern-ref*)))
  (if (search "movq _myglobal@gotpcrel(%rip)" mac)
      (ok "extern through the GOT, `_`-prefixed")
      (bad "extern through the GOT, `_`-prefixed" "not in:~%~a" mac))
  (if (and (search "movq myglobal@gotpcrel(%rip)" elf)
           (not (search "_myglobal" elf)))
      (ok "sysv extern still unprefixed GOT")
      (bad "sysv extern still unprefixed GOT" "not in:~%~a" elf)))

;;; ============================= 4. native execution (x86_64 Mach-O, Rosetta)
(format t "~&--- 4. native execution ---~%")

(defun host-runs-x86-64-macho-p ()
  "Can this host both target x86_64 Mach-O and execute the result?"
  (and (uiop:os-macosx-p)
       (zerop (nth-value 2 (uiop:run-program '("arch" "-x86_64" "/usr/bin/true")
                                             :ignore-error-status t)))))

(defun tmp (name) (uiop:tmpize-pathname (merge-pathnames name (uiop:temporary-directory))))

(defun build (asm &optional driver)
  "cc -arch x86_64 ASM (+ optional C DRIVER); return the executable path."
  (let ((sf (tmp "qbe-x64mac.s")) (exe (tmp "qbe-x64mac.out"))
        (args (list "cc" "-arch" "x86_64")))
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (setf args (append args (list (uiop:native-namestring sf))))
    (when driver
      (let ((cf (tmp "qbe-x64mac.c")))
        (with-open-file (s cf :direction :output :if-exists :supersede)
          (write-string driver s))
        (setf args (append args (list (uiop:native-namestring cf))))))
    (uiop:run-program (append args (list "-o" (uiop:native-namestring exe)))
                      :error-output :string)
    exe))

(defun run-out (exe)
  (string-trim '(#\Newline #\Return #\Space)
               (uiop:run-program (list (uiop:native-namestring exe)) :output :string
                                 :ignore-error-status t)))

(defun check (name src expect &key driver)
  (handler-case
      (let ((got (run-out (build (apple-asm src) driver))))
        (if (equal got expect) (ok name got) (bad name "got ~s want ~s" got expect)))
    (error (e) (bad name "~a" e))))

(cond
  ((not (host-runs-x86-64-macho-p))
   (incf *skip* 6)
   (format t "~&  skip (host cannot run x86_64 Mach-O)~%"))
  (t
   ;; (2+3)*4 = 20, through RDI/RSI/RDX
   (check "addmul (SysV arg registers across a C boundary)" *addmul* "20"
          :driver "#include <stdio.h>
int addmul(int, int, int);
int main(void) { printf(\"%d\\n\", addmul(2, 3, 4)); return 0; }
")
   ;; 4.0 * 10.0 + 2.5 = 42.5 -> 42, both constants read from the Lfp pool
   (check "fp pool (__TEXT literal constants, double arg)" *fp-pool* "42"
          :driver "#include <stdio.h>
int scale(double);
int main(void) { printf(\"%d\\n\", scale(4.0)); return 0; }
")
   ;; the SysV aggregate rule: one and two quads in registers, both directions
   (check "aggregates (structs in registers, both directions)" *structs*
          "7 30 300"
          :driver "#include <stdio.h>
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
   ;; sumn(9, 1..9) walks out of the register-save area and into the incoming
   ;; stack arguments -- the check that va_list crosses that seam
   (check "variadic callee (past the register-save area)" *vararg-callee*
          "60 0 45"
          :driver "#include <stdio.h>
int sumn(int, ...);
int main(void) {
  printf(\"%d %d %d\\n\", sumn(3,10,20,30), sumn(0), sumn(9,1,2,3,4,5,6,7,8,9));
  return 0;
}
")
   ;; printf has to find 42 and 7 where we put them
   (check "variadic call (ints reach printf)" *vararg-call* "got 42 and 7"
          :driver "int prints(void);
int main(void) { return prints(); }
")
   ;; the GOT entry has to land on the very address the C side sees
   (check "extern via GOT resolves to the C address" *extern-ref*
          "same 1234"
          :driver "#include <stdio.h>
int myglobal = 1234;
void *get_addr(void);
int get_val(void);
int main(void) {
  void *ours = get_addr(), *theirs = (void *)&myglobal;
  printf(\"%s %d\\n\", ours == theirs ? \"same\" : \"DIFFERENT\", get_val());
  return 0;
}
")
   ;; and the payoff for TLS: our descriptor IS the C `__thread` variable
   (check "thread-local agrees with C __thread" *thread-var*
          "same 77"
          :driver "#include <stdio.h>
extern __thread int tvar;
void *tls_addr(void);
int tls_val(void);
int main(void) {
  printf(\"%s %d\\n\", tls_addr() == &tvar ? \"same\" : \"DIFFERENT\", tls_val());
  return 0;
}
")))

;;; ------------------------------------------------------------------ verdict
(format t "~&=== amd64_apple (dialect + mach-o TLS + native e2e) ===~%  ~
          ~d passed, ~d failed, ~d skipped~%" *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
