;;;; emit.lisp --- M4 emit validation: assemble every supported corpus function.
;;;;
;;;; usage:  ros -Q run -- --script test/emit.lisp
;;;;
;;;; Runs the full backend (through simpljmp) + emit per function, then feeds the
;;;; .s to `cc -c` (assemble only).  A clean assemble proves the emitted syntax is
;;;; valid across the isel/rega-supported subset; functions that error in the
;;;; pipeline (structs/stack-args/varargs/loads) are counted unsupported.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun emit-one (fn)
  "Full backend + emit for FN as a standalone module; return the .s string."
  (qbe::be-backend-pipeline fn)
  (with-output-to-string (s)
    (format s ".text~%")
    (qbe::be-emit-fn fn s 0)
    (format s ".section .note.GNU-stack,\"\",@progbits~%")))

(defun assembles-p (asm)
  "T if ASM assembles cleanly with cc -c."
  (uiop:with-temporary-file (:pathname sf :type "s")
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (multiple-value-bind (out err code)
        (uiop:run-program (list "cc" "-c" (namestring sf) "-o" "/dev/null")
                          :output :string :error-output :string :ignore-error-status t)
      (declare (ignore out))
      (values (zerop code) err))))

(let ((ok 0) (bad 0) (sup 0) (unsup 0) (tot 0))
  (dolist (p (corpus-files))
    (let ((mod (handler-case (qbe:parse-file p) (error () nil))))
      (when mod
        (setf qbe::*tmp-counter* 0)
        (dolist (fn (qbe:module-funcs mod))
          (incf tot)
          (handler-case
              (let ((asm (emit-one fn)))
                (incf sup)
                (multiple-value-bind (good err) (assembles-p asm)
                  (if good (incf ok)
                      (progn (incf bad)
                             (format t "~&ASM-FAIL ~a/~a: ~a~%" (file-namestring p) (qbe:fn-name fn)
                                     (subseq err 0 (min 200 (length err))))))))
            (error () (incf unsup)))))))
  (format t "~&=== M4 emit (assemble supported subset) ===~%")
  (format t "  supported: ~d/~d functions~%" sup tot)
  (format t "  assembled clean: ~d/~d supported (~d failed)~%" ok sup bad)
  (sb-ext:exit :code (if (= ok sup) 0 1)))
