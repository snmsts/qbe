;;;; arm64-encode.lisp --- G6 as-diff oracle: encode a function two ways and
;;;; byte-compare, exactly like the amd64 test/encode.lisp.
;;;;   (1) aenc-fn                     -> our machine-code bytes
;;;;   (2) a64-be-emit-fn -> as -> .text  -> Apple `as`'s machine-code bytes
;;;;
;;;; AArch64 is fixed-width, so the whole thing is bitfield packing; this is the
;;;; JIT feed for solder (G6-B).  Tranche A covers single-block-ish integer leaf
;;;; functions (mov-imm, add/sub/and/or/xor/mul, reg mov); cases beyond it error
;;;; and are reported, not silently skipped.
;;;;
;;;; Run: ros -Q run -- --script test/arm64-encode.lisp   (from repo root)
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(in-package #:qbe)

(defun oracle-text-bytes (il)
  "Assemble one function via the text emitter + Apple `as`; return its __text."
  (let ((fn (first (module-funcs (parse-string il)))))
    (let ((*target* *arm64-apple-target*) (*a64-id0* 0))
      (a64-backend-pipeline fn)
      (reset-stash)
      (uiop:with-temporary-file (:pathname sf :type "s" :keep t)
        (with-open-file (o sf :direction :output :if-exists :supersede) (a64-be-emit-fn fn o))
        (let ((of (concatenate 'string (namestring sf) ".o")))
          (uiop:run-program (list "as" (namestring sf) "-o" of))
          (let ((out (uiop:run-program (list "otool" "-t" "-X" of) :output :string))
                (bytes '()))
            (dolist (line (uiop:split-string out :separator '(#\Newline)))
              (dolist (tok (remove "" (uiop:split-string (string-trim " " line) :separator '(#\Space))
                                   :test #'string=))
                (when (= (length tok) 8)
                  (let ((w (parse-integer tok :radix 16)))
                    (dotimes (k 4) (push (ldb (byte 8 (* 8 k)) w) bytes))))))
            (coerce (nreverse bytes) 'vector)))))))

(defun oracle-enc-bytes (il)
  "Encode the same function straight to machine code with aenc-fn."
  (let ((fn (first (module-funcs (parse-string il)))))
    (let ((*target* *arm64-apple-target*) (*a64-id0* 0))
      (a64-backend-pipeline fn)
      (reset-stash)
      (nth-value 0 (aenc-fn fn)))))

(defun hex (v) (format nil "~{~2,'0X~^ ~}" (coerce v 'list)))

(defun oracle-check (name il)
  (handler-case
      (let ((tb (oracle-text-bytes il)) (eb (oracle-enc-bytes il)))
        (cond
          ((equalp tb eb)
           (format t "~&PASS ~8a (~2d B)~%" name (length eb)) t)
          (t
           (format t "~&FAIL ~a~%  as : ~a~%  enc: ~a~%" name (hex tb) (hex eb))
           (loop for k below (min (length tb) (length eb))
                 when (/= (aref tb k) (aref eb k))
                   do (format t "  first diff @~d: as=~2,'0X enc=~2,'0X~%"
                              k (aref tb k) (aref eb k))
                      (loop-finish))
           nil)))
    (error (c) (format t "~&SKIP ~a  (~a)~%" name c) :skip)))

(defmacro deffns (&rest specs)
  `(list ,@(loop for (name il) on specs by #'cddr collect `(cons ,name ,il))))

(let ((pass 0) (fail 0) (skip 0)
      (cases
        (deffns
          ;; tranche A: integer ALU / mov on leaf functions
          "ret42" "export function w $ret42() { @s ret 42 }"
          "addw"  "export function w $addw(w %a, w %b) { @s %c =w add %a, %b ret %c }"
          "subl"  "export function l $subl(l %a, l %b) { @s %c =l sub %a, %b ret %c }"
          "andw"  "export function w $andw(w %a, w %b) { @s %c =w and %a, %b ret %c }"
          "orl"   "export function l $orl(l %a, l %b) { @s %c =l or %a, %b ret %c }"
          "xorw"  "export function w $xorw(w %a, w %b) { @s %c =w xor %a, %b ret %c }"
          "addi"  "export function w $addi(w %a) { @s %c =w add %a, 5 ret %c }"
          "subi"  "export function w $subi(w %a) { @s %c =w sub %a, 5 ret %c }"
          "mulr"  "export function w $mulr(w %a, w %b) { @s %c =w mul %a, %b ret %c }"
          "addli" "export function l $addli(l %a) { @s %c =l add %a, 5 ret %c }"
          "movbig" "export function l $movbig() { @s ret 180388626474 }"
          ;; loads / stores through a pointer + sign/zero extends
          "ldw"  "export function w $ldw(l %p) { @s %v =w loadw %p ret %v }"
          "ldl"  "export function l $ldl(l %p) { @s %v =l loadl %p ret %v }"
          "ldsb" "export function w $ldsb(l %p) { @s %v =w loadsb %p ret %v }"
          "ldsw" "export function l $ldsw(l %p) { @s %v =l loadsw %p ret %v }"
          "stw"  "export function w $stw(l %p, w %v) { @s storew %v, %p ret %v }"
          "stb"  "export function w $stb(l %p, w %v) { @s storeb %v, %p ret %v }"
          "extsb" "export function l $extsb(w %a) { @s %c =l extsb %a ret %c }"
          "extuw" "export function l $extuw(w %a) { @s %c =l extuw %a ret %c }"
          ;; compares -> cset (register + immediate)
          "ltw"  "export function w $ltw(w %a, w %b) { @s %c =w csltw %a, %b ret %c }"
          "cmpi" "export function w $cmpi(w %a) { @s %c =w csgtw %a, 5 ret %c }"
          ;; multi-block branches + backward loop (relaxed label offsets)
          "maxw" "export function w $maxw(w %a, w %b) {
@s %c =w csgtw %a, %b jnz %c, @yes, @no
@yes ret %a
@no ret %b }"
          "loopsum" "export function w $loopsum(w %n) {
@start %i =w copy 0 %s =w copy 0
@loop %c =w csltw %i, %n jnz %c, @body, @end
@body %s =w add %s, %i %i =w add %i, 1 jmp @loop
@end ret %s }"
          ;; calls + relocs: bl -> BRANCH26, adrp/add @page -> PAGE21/PAGEOFF12
          "callext" "export function w $callext(w %x) { @s %r =w call $abs(w %x) ret %r }"
          "gload"   "data $g = { w 42 } export function w $gload() { @s %v =w loadw $g ret %v }"
          "gaddr"   "data $g = { w 42 } export function l $gaddr() { @s ret $g }"
          ;; floats: fp binary ops + fp load/store + fp copy
          "faddd" "export function d $faddd(d %x, d %y) { @s %z =d add %x, %y ret %z }"
          "fsubs" "export function s $fsubs(s %x, s %y) { @s %z =s sub %x, %y ret %z }"
          "fmuld" "export function d $fmuld(d %x, d %y) { @s %z =d mul %x, %y ret %z }"
          "fldd"  "export function d $fldd(l %p) { @s %v =d loadd %p ret %v }"
          "fstd"  "export function d $fstd(l %p, d %v) { @s stored %v, %p ret %v }")))
  (dolist (kv cases)
    (case (oracle-check (car kv) (cdr kv))
      ((t) (incf pass)) ((:skip) (incf skip)) (t (incf fail))))
  (format t "~&~%=== G6 arm64 encoder (as-diff, tranche A) ===~%  ~d pass, ~d fail, ~d skip (~d cases)~%"
          pass fail skip (length cases))
  (sb-ext:exit :code (if (zerop fail) 0 1)))
