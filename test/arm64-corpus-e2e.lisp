;;;; arm64-corpus-e2e.lisp --- G4/G5: run QBE's own test/*.ssa programs end to
;;;; end through the arm64 (Apple) backend, natively on Apple Silicon.
;;;;
;;;; Each corpus file embeds a C driver (# >>> driver ... # <<<) and optionally
;;;; expected stdout (# >>> output ... # <<<).  We emit the whole module to
;;;; arm64_apple asm via a64-be-emit-module, assemble+link with the driver via
;;;; cc, run it, and check the exit code / stdout.
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-corpus-e2e.lisp
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

(defun extract-block (lines start-tag)
  "Uncommented body of the `# >>> START-TAG ... # <<<` block, or NIL."
  (let ((in nil) (acc '()))
    (dolist (l lines)
      (let ((s (string-left-trim '(#\Space #\Tab) l)))
        (cond
          ((and (not in) (or (string= s (format nil "# >>> ~a" start-tag))
                             (string= s (format nil "#>>> ~a" start-tag))))
           (setf in t))
          ((and in (or (string= s "# <<<") (string= s "#<<<"))) (return))
          (in
           (let ((body (cond ((uiop:string-prefix-p "# " s) (subseq s 2))
                             ((uiop:string-prefix-p "#" s) (subseq s 1))
                             (t s))))
             (unless (uiop:string-prefix-p ">>> " body)
               (push body acc)))))))
    (when in (format nil "~{~A~%~}" (nreverse acc)))))

(defun build-run (asm driver)
  "cc ASM + DRIVER into an exe; return (values exit-code stdout) or signal."
  (let ((sf (uiop:tmpize-pathname #p"/tmp/a64ce2e.s"))
        (cf (uiop:tmpize-pathname #p"/tmp/a64ce2e.c"))
        (exe (uiop:tmpize-pathname #p"/tmp/a64ce2e.out")))
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (with-open-file (s cf :direction :output :if-exists :supersede) (write-string driver s))
    (multiple-value-bind (o e code)
        (uiop:run-program (list "cc" (namestring sf) (namestring cf) "-o" (namestring exe)
                                "-lpthread" "-lm")
                          :output :string :error-output :string :ignore-error-status t)
      (declare (ignore o))
      (unless (zerop code) (error "link failed: ~a" (subseq e 0 (min 200 (length e))))))
    (multiple-value-bind (out err code)
        (uiop:run-program (list (namestring exe)) :output :string :error-output :string
                          :ignore-error-status t)
      (declare (ignore err))
      (values code out))))

(defun skip-target-p (lines)
  "QBE corpus convention: a leading `# skip <targets...>` line lists targets the
program is not expected to run on."
  (let ((first (car lines)))
    (and first (uiop:string-prefix-p "# skip" first)
         (member "arm64_apple" (uiop:split-string first :separator '(#\Space))
                 :test #'string=))))

(defun run-corpus-file (p)
  (let* ((txt (uiop:read-file-string p))
         (lines (uiop:split-string txt :separator '(#\Newline)))
         (driver (extract-block lines "driver")))
    (when (skip-target-p lines)
      (incf *skip*) (format t "~&  skip ~a: marked # skip arm64_apple~%" (file-namestring p))
      (return-from run-corpus-file :skip))
    (unless driver (return-from run-corpus-file :nodriver))
    (let ((expect-out (extract-block lines "output")))
      (handler-case
          (let ((asm (qbe:a64-be-emit-module (qbe:parse-file p))))
            (multiple-value-bind (code out) (build-run asm driver)
              (cond
                (expect-out
                 (if (string= (string-right-trim '(#\Newline) out)
                              (string-right-trim '(#\Newline) expect-out))
                     (progn (incf *pass*) (format t "~&  ok   ~a~%" (file-namestring p)))
                     (progn (incf *fail*)
                            (format t "~&  FAIL ~a: output mismatch~%" (file-namestring p)))))
                (t
                 (if (zerop code)
                     (progn (incf *pass*) (format t "~&  ok   ~a~%" (file-namestring p)))
                     (progn (incf *fail*)
                            (format t "~&  FAIL ~a: exit ~a~%" (file-namestring p) code)))))))
        (error (e)
          (incf *skip*)
          (format t "~&  skip ~a: ~a~%" (file-namestring p)
                  (subseq (princ-to-string e) 0 (min 70 (length (princ-to-string e))))))))))

(dolist (p (corpus-files)) (run-corpus-file p))
(format t "~&=== G4/G5 arm64 corpus e2e (native Apple Silicon) ===~%  ~d passed, ~d failed, ~d skipped~%"
        *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
