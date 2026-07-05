;;;; driver.lisp --- M1 end-to-end: module -> amd64 asm -> cc -> run.

(in-package #:qbe)

(defun emit-module (module &optional (stream *standard-output*))
  "Emit amd64 assembly for every function in MODULE."
  (format stream "~a.text~%" #\Tab)
  (loop for fn in (module-funcs module) for id from 0
        do (emit-fn fn stream id))
  (values))

(defun module-asm-string (module)
  (with-output-to-string (s) (emit-module module s)))

(defun build-exe (module exe-path &key (cc "cc"))
  "Assemble+link MODULE into EXE-PATH via the C compiler driver."
  (uiop:with-temporary-file (:pathname asm :type "s" :keep nil)
    (with-open-file (s asm :direction :output :if-exists :supersede)
      (emit-module module s))
    (uiop:run-program (list cc (namestring asm) "-o" (namestring exe-path))
                      :error-output :string)
    exe-path))

(defun compile-and-run (source &key (cc "cc"))
  "Parse SOURCE (a pathname or an IL string), build an executable, run it, and
return (values exit-code stdout asm-string)."
  (let* ((module (if (stringp source) (parse-string source) (parse-file source)))
         (asm (module-asm-string module)))
    (uiop:with-temporary-file (:pathname exe :type "out" :keep nil)
      (uiop:with-temporary-file (:pathname asmf :type "s" :keep nil)
        (with-open-file (s asmf :direction :output :if-exists :supersede)
          (write-string asm s))
        (uiop:run-program (list cc (namestring asmf) "-o" (namestring exe))
                          :error-output :string))
      (multiple-value-bind (out err code)
          (uiop:run-program (list (namestring exe))
                            :output :string :ignore-error-status t)
        (declare (ignore err))
        (values code out asm)))))
