;;;; arm64-jit-smoke.lisp --- G6: prove aenc-fn's bytes execute natively.
;;;;
;;;; The vertical slice IL -> aenc-fn (machine-code bytes) -> exec page ->
;;;; foreign call, run on Apple Silicon.  This is qbe-cl's self-contained JIT
;;;; smoke; the full loader/linker (symbol + reloc resolution, data pages) is
;;;; solder's job — solder consumes the same bytes+fixups aenc-fn emits, and its
;;;; scripts/ hold the qbe-cl<->solder bridge.  Here we only need leaf functions
;;;; (no fixups), so we can place the code and call it without a loader.
;;;;
;;;; Darwin/arm64 note: we mmap the page RW, copy the code, then mprotect it to
;;;; R+X and invalidate the i-cache.  (MAP_JIT + pthread_jit_write_protect_np
;;;; conflicts with SBCL's mprotect guard on this host; the RW->RX path doesn't.)
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-jit-smoke.lisp
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(in-package #:qbe)

(sb-alien:define-alien-routine ("mmap" %mmap) sb-alien:system-area-pointer
  (addr sb-alien:system-area-pointer) (len sb-alien:unsigned-long)
  (prot sb-alien:int) (flags sb-alien:int) (fd sb-alien:int) (off sb-alien:long))
(sb-alien:define-alien-routine ("mprotect" %mprotect) sb-alien:int
  (addr sb-alien:system-area-pointer) (len sb-alien:unsigned-long) (prot sb-alien:int))
(sb-alien:define-alien-routine ("sys_icache_invalidate" %icache) sb-alien:void
  (start sb-alien:system-area-pointer) (len sb-alien:unsigned-long))

(defconstant +prot-rw+ 3) (defconstant +prot-rx+ 5)
(defconstant +map-private+ 2) (defconstant +map-anon+ #x1000)

(defun jit-load (code)
  "Place CODE octets in a fresh executable page; return its callable SAP."
  (let* ((len (length code)) (msz (* 4096 (ceiling (max len 1) 4096)))
         (sap (%mmap (sb-sys:int-sap 0) msz +prot-rw+ (logior +map-private+ +map-anon+) -1 0)))
    (when (= (sb-sys:sap-int sap) (ldb (byte 64 0) -1)) (error "mmap failed"))
    (dotimes (i len) (setf (sb-sys:sap-ref-8 sap i) (aref code i)))
    (unless (zerop (%mprotect sap msz +prot-rx+)) (error "mprotect RX failed"))
    (%icache sap len)
    sap))

(defun jit-fn (il)
  "Backend-compile the single function in IL and JIT it (leaf-only: no fixups)."
  (let ((fn (first (module-funcs (parse-string il)))))
    (let ((*target* *arm64-apple-target*) (*a64-id0* 0))
      (a64-backend-pipeline fn)
      (multiple-value-bind (code syms fixups) (aenc-fn fn)
        (declare (ignore syms))
        (when fixups (error "jit smoke: leaf functions only (got fixups ~a)" fixups))
        (jit-load code)))))

(defmacro call2 (sap a b)
  `(sb-alien:alien-funcall
    (sb-alien:sap-alien ,sap (function sb-alien:int sb-alien:int sb-alien:int)) ,a ,b))

(let ((pass 0) (fail 0))
  (flet ((chk (name got want)
           (if (= got want) (progn (incf pass) (format t "~&  ok   ~a = ~d~%" name got))
               (progn (incf fail) (format t "~&  FAIL ~a = ~d (want ~d)~%" name got want)))))
    (let ((addmul (jit-fn "export function w $f(w %a, w %b) {
@s %s =w add %a, %b %r =w add %s, %s ret %r }"))
          (submul (jit-fn "export function w $g(w %a, w %b) {
@s %d =w sub %a, %b %m =w mul %d, %d ret %m }"))
          (maxfn  (jit-fn "export function w $h(w %a, w %b) {
@s %c =w csgtw %a, %b jnz %c, @y, @n
@y ret %a
@n ret %b }"))
          (andor  (jit-fn "export function w $k(w %a, w %b) {
@s %x =w and %a, %b %y =w or %a, %b %z =w add %x, %y ret %z }")))
      (chk "(3+4)*2"      (call2 addmul 3 4)     14)
      (chk "(100-50)*2"   (call2 addmul 100 -50) 100)
      (chk "(10-3)^2"     (call2 submul 10 3)    49)
      (chk "max(7,3)"     (call2 maxfn 7 3)      7)
      (chk "max(2,9)"     (call2 maxfn 2 9)      9)
      (chk "and+or(12,10)"(call2 andor 12 10)    (+ (logand 12 10) (logior 12 10)))))
  (format t "~&=== G6 arm64 JIT smoke (aenc-fn -> exec page -> native call) ===~%  ~d passed, ~d failed~%"
          pass fail)
  (sb-ext:exit :code (if (zerop fail) 0 1)))
