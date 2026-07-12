;;;; arm64-minic-e2e.lisp --- G5: run real C programs (minic output) through the
;;;; arm64 (Apple) backend, natively on Apple Silicon.
;;;;
;;;; The test/minic/*.ssa fixtures are QBE IL that minic (QBE's sample C
;;;; compiler) emitted for the amd64 SysV target.  minic marks EVERY call site
;;;; with a trailing `...`; on amd64 that is harmless (varargs pass in registers
;;;; like fixed args), but on arm64_apple it is wrong: variadic args must pass on
;;;; the stack, so the reference qbe ALSO miscompiles these fixtures verbatim.
;;;;
;;;; We normalize each call to what an Apple-aware frontend would emit — for a
;;;; genuinely-variadic libc callee (printf/scanf/...) move `...` to just after
;;;; the format arg; for every other (fixed-signature) callee drop the spurious
;;;; `...` — then run through our backend.  With this Apple-correct IL both our
;;;; backend and the reference qbe produce the expected output.
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-minic-e2e.lisp
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defvar *pass* 0) (defvar *fail* 0)

(defun minic-dir ()
  (merge-pathnames "test/minic/" (asdf:system-relative-pathname "qbe-cl" "")))

(defparameter *variadic-callees*
  '("$printf" "$scanf" "$fprintf" "$sprintf" "$snprintf" "$fscanf" "$sscanf")
  "libc functions that are genuinely variadic (args after the format go on the
Apple stack).")

(defun split-args (s)
  "Split a call's argument list on top-level commas."
  (let ((out '()) (start 0))
    (dotimes (i (length s))
      (when (char= (char s i) #\,) (push (string-trim " " (subseq s start i)) out)
            (setf start (1+ i))))
    (push (string-trim " " (subseq s start)) out)
    (nreverse out)))

(defun applify-call (fn args)
  "Rewrite one call's ARGS (a trimmed string) for arm64_apple: printf-family ->
`fmt, ..., rest`; anything else with a trailing `...` -> drop it."
  (let* ((args (string-right-trim " " args)))
    (unless (and (>= (length args) 3)
                 (string= (subseq args (- (length args) 3)) "..."))
      (return-from applify-call (format nil "call ~a(~a)" fn args)))
    (let* ((base (string-right-trim " ," (subseq args 0 (- (length args) 3))))
           (parts (if (string= base "") '() (split-args base))))
      (cond
        ((and (member fn *variadic-callees* :test #'string=) parts)
         (format nil "call ~a(~a)" fn
                 (format nil "~a, ...~@[, ~a~]" (first parts)
                         (when (rest parts) (format nil "~{~a~^, ~}" (rest parts))))))
        (t (format nil "call ~a(~a)" fn (format nil "~{~a~^, ~}" parts)))))))

(defun applify-ssa (txt)
  "Normalize every `call $fn(...)` in an IL string for arm64_apple."
  (with-output-to-string (out)
    (let ((i 0) (n (length txt)))
      (loop while (< i n) do
        (let ((c (search "call $" txt :start2 i)))
          (if (null c)
              (progn (write-string (subseq txt i) out) (setf i n))
              (let* ((paren (position #\( txt :start c))
                     (close (position #\) txt :start paren))
                     (fn (string-trim " " (subseq txt (+ c 5) paren)))
                     (args (subseq txt (1+ paren) close)))
                (write-string (subseq txt i c) out)
                (write-string (applify-call fn args) out)
                (setf i (1+ close)))))))))

(defun run-one (ssa)
  (let* ((name (pathname-name ssa))
         (expect (uiop:read-file-string
                  (merge-pathnames (make-pathname :name name :type "out") (minic-dir))))
         (il (applify-ssa (uiop:read-file-string ssa))))
    (handler-case
        (let* ((asm (qbe:a64-be-emit-module (qbe:parse-string il)))
               (sf (uiop:tmpize-pathname #p"/tmp/a64minic.s"))
               (exe (uiop:tmpize-pathname #p"/tmp/a64minic.out")))
          (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
          (uiop:run-program (list "cc" (namestring sf) "-o" (namestring exe) "-lm")
                            :error-output :string)
          (let ((out (uiop:run-program (list (namestring exe)) :output :string
                                       :ignore-error-status t)))
            (if (string= out expect)
                (progn (incf *pass*) (format t "~&  ok   ~a~%" name))
                (progn (incf *fail*) (format t "~&  FAIL ~a: output differs~%" name)))))
      (error (e)
        (incf *fail*)
        (format t "~&  FAIL ~a: ~a~%" name
                (subseq (princ-to-string e) 0 (min 90 (length (princ-to-string e)))))))))

(dolist (ssa (sort (directory (merge-pathnames "*.ssa" (minic-dir)))
                   #'string< :key #'namestring))
  (run-one ssa))
(format t "~&=== G5 arm64 minic e2e (real C via minic -> our backend, native) ===~%  ~d passed, ~d failed~%"
        *pass* *fail*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
