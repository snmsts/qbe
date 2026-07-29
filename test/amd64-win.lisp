;;;; amd64-win.lisp --- the amd64_win target: assembler dialect, the Win64 rules
;;;; that distinguish it from SysV, and (given an x86_64 Windows cc) end-to-end
;;;; native execution.
;;;;
;;;; usage:  ros -Q run -- --script test/amd64-win.lisp
;;;;
;;;; test/winabi.lisp already pins the ABI lowering down against
;;;; `qbe -t amd64_win -dA` (180/180 functions), and
;;;; test/amd64-win-corpus-e2e.lisp runs the corpus.  What neither of them
;;;; covers is what this file is for:
;;;;
;;;;   1. the assembler dialect -- bare `L` local labels, no ELF symbol-size
;;;;      footer, no GNU-stack note, no `@plt`.  Each check has a SysV twin so
;;;;      the ELF side cannot be refactored away with it.
;;;;   2. the Win64 vararg prologue -- the argument registers are spilled into
;;;;      the CALLER's shadow space, before the frame is even pushed.
;;;;   3. extern symbol addresses through a COFF `.refptr` COMDAT.  QBE itself
;;;;      dies here for amd64_win; the corpus therefore cannot measure it, and
;;;;      neither can the -dA oracle (it dumps a pass that runs before isel).
;;;;   4. that the aggregate rules -- 8 bytes in a register, anything else
;;;;      copied and passed by pointer -- agree with a real C compiler, and that
;;;;      the result runs.
;;;;
;;;; 1-3 are textual and run on any host.  4 needs an x86_64 Windows cc (set
;;;; AMD64_CC; on an ARM64 host both it and its output go through the OS's x64
;;;; emulation) and self-skips without one.
(require :asdf)
(require :sb-posix)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(defpackage #:qbe-amd64-win (:use #:cl)) (in-package #:qbe-amd64-win)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

(defun ok (name &rest args)
  (incf *pass*) (format t "~&  ok   ~a~@[ => ~a~]~%" name (car args)))
(defun bad (name fmt &rest args)
  (incf *fail*) (format t "~&  FAIL ~a: ~?~%" name fmt args))

(defun win-asm (src)
  (qbe:be-emit-module (qbe:parse-string src) qbe:*amd64-win-target*))
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

;; three integer args: RCX/RDX/R8 on Windows, RDI/RSI/RDX on SysV -- the same
;; function is a boundary test for both conventions.
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

(defparameter *extern-thread* "
export function l $get_tls() {
@start
	%p =l copy thread $tlsvar
	ret %p
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

;; The Win64 aggregate rule, both sizes of it.  An 8-byte struct travels in
;; RCX by value; a 16-byte one is copied by the caller and RCX holds a pointer
;; to the copy.  Same IL either way -- the ABI pass decides -- so agreeing with
;; the C compiler on both is the whole test.
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

(let ((win (win-asm *loop-sum*)) (elf (sysv-asm *loop-sum*)))
  ;; T_amd64_win.asloc is bare "L"
  (if (and (search "Lbb" win) (not (search ".Lbb" win)))
      (ok "bare `L` local labels")
      (bad "bare `L` local labels" "not in:~%~a" win))
  (if (search ".Lbb" elf) (ok "sysv still uses `.Lbb`")
      (bad "sysv still uses `.Lbb`" "not in:~%~a" elf))
  ;; amd64_winabi_emitfn calls no elf_emitfnfin, and pe_emitfin adds no note
  (if (or (search ".type" win) (search ".size" win))
      (bad "no .type/.size footer" "still present in:~%~a" win)
      (ok "no .type/.size footer"))
  (if (search ".note.GNU-stack" win)
      (bad "no .note.GNU-stack" "still present in:~%~a" win)
      (ok "no .note.GNU-stack"))
  (if (and (search ".type" elf) (search ".note.GNU-stack" elf))
      (ok "sysv still emits the ELF footer + note")
      (bad "sysv still emits the ELF footer + note" "not in:~%~a" elf))
  ;; and the loop header alignment the SysV emitter adds is absent
  (if (search ".p2align 4" win)
      (bad "no loop-header .p2align" "still present in:~%~a" win)
      (ok "no loop-header .p2align"))
  (if (search ".p2align 4" elf) (ok "sysv still aligns loop headers")
      (bad "sysv still aligns loop headers" "not in:~%~a" elf)))

;; the fp-const pool label follows asloc too, so it is `Lfp0` here
(let ((win (win-asm *fp-pool*)) (elf (sysv-asm *fp-pool*)))
  (if (and (search "\"Lfp0\"" win) (not (search ".Lfp0" win)))
      (ok "fp pool labelled Lfp0")
      (bad "fp pool labelled Lfp0" "not in:~%~a" win))
  (if (search ".Lfp0" elf) (ok "sysv fp pool still .Lfp0")
      (bad "sysv fp pool still .Lfp0" "not in:~%~a" elf)))

;; `@plt` is an ELF decoration; COFF resolves a direct callq (and synthesises
;; an import thunk if the target turns out to be imported).
(let ((src "
export function w $c() {
@start
	%r =w call extern $extfn()
	ret %r
}
"))
  (let ((win (win-asm src)) (elf (sysv-asm src)))
    (if (search "@plt" win)
        (bad "no @plt on COFF" "still present in:~%~a" win)
        (ok "no @plt on COFF"))
    (if (search "@plt" elf) (ok "sysv still emits @plt")
        (bad "sysv still emits @plt" "not in:~%~a" elf))))

;;; ============================================== 2. Win64 vararg prologue
(format t "~&--- 2. Win64 vararg prologue ---~%")

(let* ((win (win-asm *vararg-callee*))
       (spill (search "movq %rcx, 0x8(%rsp)" win))
       (push  (search "pushq %rbp" win)))
  (cond
    ((not spill) (bad "vararg spills rcx-r9 to shadow space" "not in:~%~a" win))
    ((not (search "movq %r9, 0x20(%rsp)" win))
     (bad "vararg spills rcx-r9 to shadow space" "r9 missing in:~%~a" win))
    (t (ok "vararg spills rcx-r9 to shadow space")))
  ;; it has to happen before the frame is pushed: the shadow space belongs to
  ;; the caller and is addressed off the incoming rsp.
  (if (and spill push (< spill push))
      (ok "the spill precedes pushq %rbp")
      (bad "the spill precedes pushq %rbp" "wrong order in:~%~a" win))
  ;; no 176-byte SysV register-save area, so no movaps of the xmm half
  (if (search "movaps" win)
      (bad "no 176-byte SysV save area" "still present in:~%~a" win)
      (ok "no 176-byte SysV save area")))

(let ((elf (sysv-asm *vararg-callee*)))
  (if (and (search "movaps %xmm0" elf) (search "-176(%rbp)" elf))
      (ok "sysv still builds the 176-byte save area")
      (bad "sysv still builds the 176-byte save area" "not in:~%~a" elf)))

;; the caller side must lower, not raise
(handler-case (progn (win-asm *vararg-call*) (ok "win lowers variadic calls"))
  (error (e) (bad "win lowers variadic calls" "~a" e)))

;;; ==================================== 3. extern addresses via COFF .refptr
(format t "~&--- 3. extern symbol addresses ---~%")

(let ((win (win-asm *extern-ref*)))
  (if (search "movq .refptr.myglobal(%rip)" win)
      (ok "extern goes through .refptr")
      (bad "extern goes through .refptr" "not in:~%~a" win))
  ;; ... and the COMDAT that holds the address is defined in this object.  The
  ;; x86 PE assembler spells the COMDAT as a separate `.linkonce`, unlike the
  ;; aarch64 one (see emit-refptrs).
  (if (and (search ".section	.rdata$.refptr.myglobal,\"dr\"" win)
           (search ".linkonce	discard" win)
           (search ".quad	myglobal" win))
      (ok "the .refptr COMDAT is defined")
      (bad "the .refptr COMDAT is defined" "not in:~%~a" win))
  ;; one COMDAT even though two functions reference it
  (let ((n (loop with i = 0 with c = 0
                 for p = (search ".refptr.myglobal:" win :start2 i)
                 while p do (incf c) (setf i (1+ p)) finally (return c))))
    (if (= n 1) (ok "defined once for two references")
        (bad "defined once for two references" "found ~d definitions" n))))

;; SysV must still take the GOT, not the COMDAT.
(let ((elf (sysv-asm *extern-ref*)))
  (if (and (search "@gotpcrel(%rip)" elf) (not (search ".refptr" elf)))
      (ok "sysv extern still uses the GOT")
      (bad "sysv extern still uses the GOT" "not in:~%~a" elf)))

;; TLS has no Win64 lowering in QBE and none here; it must refuse rather than
;; emit something that mislinks.
(handler-case (progn (win-asm *extern-thread*)
                     (bad "win refuses thread-local data" "emitted silently"))
  (error (e)
    (if (search "thread" (string-downcase (princ-to-string e)))
        (ok "win refuses thread-local data")
        (bad "win refuses thread-local data" "unexpected error: ~a" e))))

;;; ================================ 4. native execution (x86_64 Windows cc)
(format t "~&--- 4. native execution ---~%")

(defun triple-of (cc)
  (ignore-errors
   (string-trim '(#\Newline #\Return #\Space)
                (uiop:run-program (list cc "-dumpmachine") :output :string))))

(defun amd64-windows-cc-p (triple)
  (and triple (search "x86_64" triple)
       (or (search "windows" triple) (search "mingw" triple))))

(defun find-amd64-cc ()
  "AMD64_CC if it is an x86_64 Windows cc, else `cc`, else MSYS2's UCRT64 gcc.
A mingw gcc loads libisl/libmpc from its own bin directory, so it cannot even
start unless that directory is on PATH -- it exits 1 with no message at all."
  (dolist (cand (remove nil (list (uiop:getenv "AMD64_CC") "cc"
                                  "C:/msys64/ucrt64/bin/gcc.exe")))
    (when (amd64-windows-cc-p (triple-of cand))
      (let ((dir (directory-namestring (or (ignore-errors (truename cand)) cand))))
        (when (and (plusp (length dir)) (not (search dir (uiop:getenv "PATH"))))
          (sb-posix:putenv (format nil "PATH=~a;~a"
                                   (substitute #\\ #\/ dir) (uiop:getenv "PATH")))))
      (return cand))))

(defvar *cc* nil)

(defun tmp (name) (uiop:tmpize-pathname (merge-pathnames name (uiop:temporary-directory))))

(defun build (asm &optional driver)
  "Assemble ASM (+ optional C DRIVER) with *cc*; return the executable path."
  (let ((sf (tmp "qbe-x64win.s")) (exe (tmp "qbe-x64win.exe"))
        (args '()))
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (setf args (list *cc* (uiop:native-namestring sf)))
    (when driver
      (let ((cf (tmp "qbe-x64win.c")))
        (with-open-file (s cf :direction :output :if-exists :supersede)
          (write-string driver s))
        (setf args (append args (list (uiop:native-namestring cf))))))
    (uiop:run-program (append args (list "-o" (uiop:native-namestring exe)))
                      :error-output :string)
    exe))

(defun run-out (exe)
  (string-trim '(#\Newline #\Return #\Space)
               (uiop:run-program (list (uiop:native-namestring exe)) :output :string
                                 :ignore-error-status t :external-format :latin-1)))

(defun check (name src expect &key driver)
  (handler-case
      (let ((got (run-out (build (win-asm src) driver))))
        (if (equal got expect) (ok name got) (bad name "got ~s want ~s" got expect)))
    (error (e) (bad name "~a" e))))

(setf *cc* (find-amd64-cc))
(cond
  ((not *cc*)
   (incf *skip* 6)
   (format t "~&  skip (no x86_64 Windows cc; set AMD64_CC)~%"))
  (t
   ;; (2+3)*4 = 20, through RCX/RDX/R8
   (check "addmul (Win64 arg registers across a C boundary)" *addmul* "20"
          :driver "#include <stdio.h>
int addmul(int, int, int);
int main(void) { printf(\"%d\\n\", addmul(2, 3, 4)); return 0; }
")
   ;; 4.0 * 10.0 + 2.5 = 42.5 -> 42, both constants read from the Lfp pool
   (check "fp pool (.rodata constants, double arg)" *fp-pool* "42"
          :driver "#include <stdio.h>
int scale(double);
int main(void) { printf(\"%d\\n\", scale(4.0)); return 0; }
")
   ;; the aggregate rule both ways: 8 bytes by value in RCX, 16 by pointer.
   ;; call2 also exercises the CALLER side of the by-pointer case.
   (check "aggregates (8 bytes in a register, 16 by pointer)" *structs*
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
   ;; sumn(9, 1..9) needs more slots than the four argument registers, so it
   ;; walks off the shadow space and into the incoming stack arguments -- the
   ;; check that the two halves are contiguous.
   (check "variadic callee (incl. walking past the shadow space)" *vararg-callee*
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
   ;; the payoff: the .refptr has to land on the very address the C side sees
   (check "extern via .refptr resolves to the C address" *extern-ref*
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
")))

;;; ------------------------------------------------------------------ verdict
(format t "~&=== amd64_win (dialect + Win64 rules + native e2e) ===~%  ~
          ~d passed, ~d failed, ~d skipped~%" *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
