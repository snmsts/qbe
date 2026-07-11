;;;; minic-e2e.lisp --- M5+: run real C programs compiled by QBE's `minic`.
;;;;
;;;; The test/minic/*.ssa files are QBE IL emitted by minic (QBE's sample C
;;;; compiler, minic/minic.y) from its own test C programs; each *.out holds the
;;;; program's reference stdout (from cc'ing the original C directly).  We run
;;;; the IL through our backend (be-emit-module -> cc -> execute) and check the
;;;; output matches — validating the backend on non-hand-written, real-compiler
;;;; input.  (minic itself is not vendored; the .ssa are the frozen fixtures.)
;;;;
;;;; usage:  ros -Q run -- --script test/minic-e2e.lisp
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defvar *pass* 0) (defvar *fail* 0)

(defun minic-dir ()
  (merge-pathnames "test/minic/" (asdf:system-relative-pathname "qbe-cl" "")))

(defun run-one (ssa)
  (let* ((name (pathname-name ssa))
         (expect (uiop:read-file-string
                  (merge-pathnames (make-pathname :name name :type "out") (minic-dir)))))
    (handler-case
        (let* ((asm (qbe:be-emit-module (qbe:parse-file ssa)))
               (sf (uiop:tmpize-pathname #p"/tmp/minic.s"))
               (exe (uiop:tmpize-pathname #p"/tmp/minic.out")))
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
                (subseq (princ-to-string e) 0 (min 80 (length (princ-to-string e)))))))))

(dolist (ssa (sort (directory (merge-pathnames "*.ssa" (minic-dir)))
                   #'string< :key #'namestring))
  (run-one ssa))
(format t "~&=== minic e2e (real C via minic -> our backend) ===~%  ~d passed, ~d failed~%"
        *pass* *fail*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
