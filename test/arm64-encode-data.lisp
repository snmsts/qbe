;;;; arm64-encode-data.lisp --- unit oracle for aenc-data / aenc-stash.
;;;;
;;;; Unlike the instruction encoder (byte-exact vs Apple `as`), the data/fp-pool
;;;; encoders emit a flat bytes+fixups blob for solder rather than mach-o literal
;;;; sections, so `as` is not the oracle here.  These assertions pin the layout
;;;; directly: item bytes, `:ref` -> ABS64 fixups, and the LfpN pool offsets that
;;;; the adrp/add PAGE21/PAGEOFF12 fixups from aenc-fn resolve against.  The
;;;; end-to-end proof that these bytes run natively is solder/scripts/arm64-jit.lisp.
;;;;
;;;; Run: ros -Q run -- --script test/arm64-encode-data.lisp   (from repo root)
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(in-package #:qbe)

(defvar *pass* 0)
(defvar *fail* 0)
(defun expect= (label got want)
  (if (equalp got want)
      (progn (incf *pass*) (format t "~&PASS ~a~%" label))
      (progn (incf *fail*) (format t "~&FAIL ~a~%  got:  ~s~%  want: ~s~%" label got want))))

;;; Encode a module's data (and, after running the backend to fill the pool, its
;;; fp stash) with the arm64 target bound, returning both for assertion.
(defun enc-module-data (il)
  (let ((mod (parse-string il)) (*target* *arm64-apple-target*) (*a64-id0* 0)
        (datas '()) (stash nil))
    (setf *tmp-counter* 0)
    (reset-stash)
    (dolist (fn (module-funcs mod)) (a64-backend-pipeline fn) (aenc-fn fn))
    (dolist (d (module-data mod))
      (multiple-value-bind (bytes syms fixups writable) (aenc-data d)
        (push (list (dat-name d) (coerce bytes 'list) syms fixups writable) datas)))
    (multiple-value-bind (bytes syms) (aenc-stash)
      (setf stash (list (coerce bytes 'list) syms)))
    (values (nreverse datas) stash)))

(multiple-value-bind (datas stash)
    (enc-module-data "data $g = { w 42, w 7 }
data $arr = { l 10, l 20, l 30 }
data $pp = { l $arr+8 }
data $s = { b \"AB\", b 0 }
export function d $f(d %x) { @s %a =d add %x, d_0.5 %b =d add %a, d_1.5 ret %b }
export function s $q() { @s ret s_0.25 }")
  ;; --- integer globals: little-endian item bytes, writable, no fixups ---
  (destructuring-bind (name bytes syms fixups writable) (assoc "g" datas :test #'string=)
    (declare (ignore name))
    (expect= "g bytes"    bytes '(42 0 0 0 7 0 0 0))
    (expect= "g syms"     syms  '(("g" . 0)))
    (expect= "g fixups"   fixups '())
    (expect= "g writable" writable t))
  (destructuring-bind (name bytes syms fixups writable) (assoc "arr" datas :test #'string=)
    (declare (ignore name syms fixups writable))
    (expect= "arr bytes" bytes '(10 0 0 0 0 0 0 0  20 0 0 0 0 0 0 0  30 0 0 0 0 0 0 0)))
  ;; --- pointer global: :ref -> 8 zero bytes + an ABS64 fixup (prefixed name) ---
  (destructuring-bind (name bytes syms fixups writable) (assoc "pp" datas :test #'string=)
    (declare (ignore name syms writable))
    (expect= "pp bytes"  bytes '(0 0 0 0 0 0 0 0))
    (expect= "pp fixup"  fixups
            (list (list :offset 0 :symbol "_arr" :kind :abs64 :addend 8))))
  ;; --- string + byte items ---
  (destructuring-bind (name bytes syms fixups writable) (assoc "s" datas :test #'string=)
    (declare (ignore name syms fixups writable))
    (expect= "s bytes" bytes '(65 66 0)))                 ; "AB" + 0
  ;; --- fp pool: three size-aligned entries interned in first-seen order.  isel
  ;; interns 1.5 (Lfp0), 0.5 (Lfp1) as 8B doubles, then 0.25 (Lfp2) as a 4B single.
  (destructuring-bind (bytes syms) stash
    (expect= "stash bytes" bytes
            '(#x00 #x00 #x00 #x00 #x00 #x00 #xF8 #x3F     ; Lfp0 = 1.5d  (0x3FF8..)
              #x00 #x00 #x00 #x00 #x00 #x00 #xE0 #x3F     ; Lfp1 = 0.5d  (0x3FE0..)
              #x00 #x00 #x80 #x3E))                       ; Lfp2 = 0.25f (0x3E800000)
    (expect= "stash syms" syms '(("\"Lfp0\"" . 0) ("\"Lfp1\"" . 8) ("\"Lfp2\"" . 16)))))

(format t "~&~%=== G6-B arm64 data/stash encoder (unit) ===~%  ~d pass, ~d fail~%" *pass* *fail*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
