;;;; M3b as-diff oracle: encode a function two ways and byte-compare.
;;;;   (1) enc-fn                 -> our machine-code bytes
;;;;   (2) be-emit-fn -> as -> .text  -> `as`'s machine-code bytes
;;;; Same IR philosophy as qbe-cl's `-d` byte-exact harness, applied to codegen.
;;;;
;;;; Run: ros -Q run --non-interactive --load test/encode.lisp   (from repo root)

(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(ql:quickload :qbe-cl :silent t)              ; amd64-encode is part of the system

(in-package #:qbe)

(defun oracle-read-octets (path)
  (with-open-file (s path :element-type '(unsigned-byte 8))
    (let ((v (make-array (file-length s) :element-type '(unsigned-byte 8))))
      (read-sequence v s) v)))

(defun oracle-run (&rest argv)
  (uiop:run-program argv :error-output :string))

(defun oracle-text-bytes (il)
  "Assemble one function via the text emitter + system `as`, return its .text."
  (let ((fn (first (module-funcs (parse-string il)))))
    (be-backend-pipeline fn)
    (reset-stash)
    (let ((asm (with-output-to-string (s)
                 (be-emit-fn fn s 0)
                 (format s ".section .note.GNU-stack,\"\",@progbits~%"))))
      (uiop:with-temporary-file (:pathname sf :type "s" :keep t)
        (with-open-file (o sf :direction :output :if-exists :supersede) (write-string asm o))
        (let ((of (concatenate 'string (namestring sf) ".o"))
              (bf (concatenate 'string (namestring sf) ".bin")))
          (oracle-run "as" (namestring sf) "-o" of)
          (oracle-run "objcopy" "--only-section=.text" "-O" "binary" of bf)
          (oracle-read-octets bf))))))

(defun oracle-enc-bytes (il)
  "Encode the same function straight to machine code with enc-fn."
  (let ((fn (first (module-funcs (parse-string il)))))
    (be-backend-pipeline fn)
    (nth-value 0 (enc-fn fn))))

(defun hex (v) (format nil "~{~2,'0X~^ ~}" (coerce v 'list)))

(defun oracle-check (name il)
  (handler-case
      (let ((tb (oracle-text-bytes il)) (eb (oracle-enc-bytes il)))
        (cond
          ((equalp tb eb)
           (format t "~&PASS ~8a (~2d B)  ~a~%" name (length eb) (hex eb)) t)
          (t
           (format t "~&FAIL ~a~%  as : ~a~%  enc: ~a~%" name (hex tb) (hex eb))
           (loop for k below (min (length tb) (length eb))
                 when (/= (aref tb k) (aref eb k))
                   do (format t "  first diff @~d: as=~2,'0X enc=~2,'0X~%"
                              k (aref tb k) (aref eb k))
                      (loop-finish))
           nil)))
    (error (c) (format t "~&FAIL ~a  (~a)~%" name c) nil)))

(defmacro deffns (&rest specs)
  `(list ,@(loop for (name il) on specs by #'cddr collect `(cons ,name ,il))))

(let ((ok t)
      (cases
        (deffns
          "ret42" "export function w $ret42() { @s ret 42 }"
          "addw"  "export function w $addw(w %a, w %b) { @s %c =w add %a, %b ret %c }"
          "subl"  "export function l $subl(l %a, l %b) { @s %c =l sub %a, %b ret %c }"
          "andw"  "export function w $andw(w %a, w %b) { @s %c =w and %a, %b ret %c }"
          "xorl"  "export function l $xorl(l %a, l %b) { @s %c =l xor %a, %b ret %c }"
          ;; immediate ALU
          "addi"  "export function w $addi(w %a) { @s %c =w add %a, 5 ret %c }"
          "subi"  "export function w $subi(w %a) { @s %c =w sub %a, 5 ret %c }"
          "andi"  "export function w $andi(w %a) { @s %c =w and %a, 12 ret %c }"
          "ori"   "export function w $ori(w %a) { @s %c =w or %a, 12 ret %c }"
          "xori"  "export function w $xori(w %a) { @s %c =w xor %a, 12 ret %c }"
          "addli" "export function l $addli(l %a) { @s %c =l add %a, 5 ret %c }"
          ;; shifts
          "shli"  "export function w $shli(w %a) { @s %c =w shl %a, 3 ret %c }"
          "shri"  "export function w $shri(w %a) { @s %c =w shr %a, 3 ret %c }"
          "sari"  "export function w $sari(w %a) { @s %c =w sar %a, 3 ret %c }"
          ;; mul
          "mulr"  "export function w $mulr(w %a, w %b) { @s %c =w mul %a, %b ret %c }"
          "muli"  "export function w $muli(w %a) { @s %c =w mul %a, 6 ret %c }"
          ;; neg
          "negw"  "export function w $negw(w %a) { @s %c =w neg %a ret %c }"
          ;; compare -> bool (cmp + setcc + movzx)
          "ltw"   "export function w $ltw(w %a, w %b) { @s %c =w csltw %a, %b ret %c }"
          "eqw"   "export function w $eqw(w %a, w %b) { @s %c =w ceqw %a, %b ret %c }"
          "gel"   "export function w $gel(l %a, l %b) { @s %c =w csgel %a, %b ret %c }"
          ;; sign/zero extend
          "extsw" "export function l $extsw(w %a) { @s %c =l extsw %a ret %c }"
          "extuw" "export function l $extuw(w %a) { @s %c =l extuw %a ret %c }"
          ;; frames + calls + relocs (tranche A)
          "callext" "export function w $callext(w %x) { @s %r =w call $abs(w %x) ret %r }"
          "callone" "export function w $callone(w %x) { @s %r =w call $triple(w %x) ret %r }"
          "addcall" "export function w $addcall(w %x, w %y) {
@s %a =w call $triple(w %x) %b =w call $triple(w %y) %c =w add %a, %b ret %c }"
          ;; multi-block: real jmp/jcc + branch relaxation (tranche B)
          "maxw" "export function w $maxw(w %a, w %b) {
@s %c =w csgtw %a, %b jnz %c, @yes, @no
@yes ret %a
@no ret %b }"
          "minl" "export function l $minl(l %a, l %b) {
@s %c =l csltl %a, %b jnz %c, @yes, @no
@yes ret %a
@no ret %b }"
          "eqbr" "export function w $eqbr(w %a, w %b) {
@s %c =w ceqw %a, %b jnz %c, @t, @f
@t ret 1
@f ret 0 }"
          ;; loop: backward jcc/jmp + .p2align 4 NOP fill at the loop header
          "loopsum" "export function w $loopsum(w %n) {
@start %i =w copy 0 %s =w copy 0
@loop %c =w csltw %i, %n jnz %c, @body, @end
@body %s =w add %s, %i %i =w add %i, 1 jmp @loop
@end ret %s }"
          ;; memory operands: loads/stores through a pointer (tranche C1)
          "ldw"  "export function w $ldw(l %p) { @s %v =w loadw %p ret %v }"
          "ldl"  "export function l $ldl(l %p) { @s %v =l loadl %p ret %v }"
          "ldub" "export function w $ldub(l %p) { @s %v =w loadub %p ret %v }"
          "ldsb" "export function w $ldsb(l %p) { @s %v =w loadsb %p ret %v }"
          "lduh" "export function w $lduh(l %p) { @s %v =w loaduh %p ret %v }"
          "stw"  "export function w $stw(l %p, w %v) { @s storew %v, %p ret %v }"
          "stl"  "export function l $stl(l %p, l %v) { @s storel %v, %p ret %v }"
          "stb"  "export function w $stb(l %p, w %v) { @s storeb %v, %p ret %v }"
          "sth"  "export function w $sth(l %p, w %v) { @s storeh %v, %p ret %v }"
          "stsi" "export function w $stsi(w %v) { @s storew %v, $g ret %v }"
          "ldoff" "export function l $ldoff(l %p) { @s %q =l add %p, 8 %v =l loadl %q ret %v }"
          ;; RIP-relative global: load + address-of (PC32 fixup, field 0)
          "gload" "data $g = { w 42 } export function w $gload() { @s %v =w loadw $g ret %v }"
          "gaddr" "data $g = { w 42 } export function l $gaddr() { @s ret $g }"
          ;; real stack slot: alloc + store-to-slot + lea-of-slot passed to a call
          "slotp" "export function w $slotp(w %v) {
@s %p =l alloc4 4 storew %v, %p %r =w call $use(l %p) ret %r }"
          ;; cmov: a diamond-phi that isel fuses to cmovCC (tranche C2)
          "absw" "export function w $absw(w %a) {
@s %c =w csltw %a, 0 jnz %c, @neg, @done
@neg %n =w sub 0, %a jmp @done
@done %r =w phi @s %a, @neg %n ret %r }"
          "minsel" "export function l $minsel(l %a, l %b) {
@s %c =l csltl %a, %b jnz %c, @ta, @tb
@ta jmp @done
@tb jmp @done
@done %r =l phi @ta %a, @tb %b ret %r }"
          ;; floats / SSE (tranche C3)
          "faddd" "export function d $faddd(d %x, d %y) { @s %z =d add %x, %y ret %z }"
          "fsubs" "export function s $fsubs(s %x, s %y) { @s %z =s sub %x, %y ret %z }"
          "fmuld" "export function d $fmuld(d %x, d %y) { @s %z =d mul %x, %y ret %z }"
          "fdivs" "export function s $fdivs(s %x, s %y) { @s %z =s div %x, %y ret %z }"
          "i2d"   "export function d $i2d(w %x) { @s %z =d swtof %x ret %z }"
          "l2s"   "export function s $l2s(l %x) { @s %z =s sltof %x ret %z }"
          "d2i"   "export function w $d2i(d %x) { @s %z =w dtosi %x ret %z }"
          "s2l"   "export function l $s2l(s %x) { @s %z =l stosi %x ret %z }"
          "s2d"   "export function d $s2d(s %x) { @s %z =d exts %x ret %z }"
          "d2s"   "export function s $d2s(d %x) { @s %z =s truncd %x ret %z }"
          "fltd"  "export function w $fltd(d %a, d %b) { @s %c =w cltd %a, %b ret %c }"
          "castl" "export function l $castl(d %x) { @s %z =l cast %x ret %z }"
          "castd" "export function d $castd(l %x) { @s %z =d cast %x ret %z }"
          "fldd"  "export function d $fldd(l %p) { @s %v =d loadd %p ret %v }"
          "fstd"  "export function d $fstd(l %p, d %v) { @s stored %v, %p ret %v }"
          "fconst" "export function d $fconst() { @s ret d_1.5 }"
          ;; integer division: cltd/cqto + idiv/div (tranche C, integer subset)
          "divw" "export function w $divw(w %a, w %b) { @s %q =w div %a, %b ret %q }"
          "remw" "export function w $remw(w %a, w %b) { @s %q =w rem %a, %b ret %q }"
          "divl" "export function l $divl(l %a, l %b) { @s %q =l div %a, %b ret %q }"
          "udivw" "export function w $udivw(w %a, w %b) { @s %q =w udiv %a, %b ret %q }"
          ;; varargs: the 176-byte register-save prologue (movq regs + movaps xmm)
          "vararg" "export function w $va(w %n, ...) { @s ret %n }"
          "vararg2" "export function l $va2(l %a, l %b, ...) { @s %c =l add %a, %b ret %c }"
          ;; aggregates + blit already lower to slot/mem load/stores (mem operands)
          "structarg" "type :pt = { w, w }
export function w $sa(:pt %p) { @s %a =w loadw %p ret %a }"
          "blit16" "export function $cp(l %d, l %s) { @s blit %s, %d, 16 ret }"
          ;; store immediate to memory (movl $imm, mem  -> C7 /0)
          "stimm"  "export function w $stimm(l %p) { @s storew 7, %p storel 9, %p ret 0 }"
          "stbimm" "export function w $stbimm(l %p) { @s storeb 65, %p ret 0 }"
          ;; full vararg: vastart + vaarg dispatch (store-imm, branches, va area)
          "va2sum" "export function w $va2sum(w %n, ...) {
@s %ap =l alloc8 24 vastart %ap %a =w vaarg %ap %b =w vaarg %ap %c =w add %a, %b ret %c }"
          ;; wide-value materialization: movl / movq $imm32 (sign-ext) / movabs
          "ksmall" "export function l $ksmall() { @s ret 42 }"
          "kneg"   "export function l $kneg() { @s ret -1988 }"
          "kbig"   "export function l $kbig() { @s ret 180388626474 }"
          "kwsat"  "export function l $kwsat() { @s ret 9223372036854775807 }"
          ;; sub where the result reg is the subtrahend -> neg + add (no clobber)
          "rsubl"  "export function l $rsubl(l %x) { @s %r =l sub 100, %x ret %r }"
          ;; shift by 1 -> the short D1 /digit form
          "shl1"   "export function w $shl1(w %a) { @s %r =w shl %a, 1 ret %r }")))
  (dolist (kv cases)
    (unless (oracle-check (car kv) (cdr kv)) (setf ok nil)))
  (format t "~&~%~a  (~d cases)~%" (if ok "=== ALL PASS ===" "=== SOME FAIL ===")
          (length cases))
  (uiop:quit (if ok 0 1)))
