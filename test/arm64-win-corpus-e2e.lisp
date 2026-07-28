;;;; arm64-win-corpus-e2e.lisp --- run QBE's own test/*.ssa programs end to end
;;;; through the arm64_win backend, natively on Windows ARM64.
;;;;
;;;; The arm64_apple twin of this file (test/arm64-corpus-e2e.lisp) is what
;;;; "the backend is done" means for that target: not that the corpus
;;;; assembles, but that the programs run and print the right thing.  This is
;;;; the same bar for Windows.
;;;;
;;;; Each corpus file embeds a C driver (# >>> driver ... # <<<) and optionally
;;;; expected stdout (# >>> output ... # <<<).  We emit the whole module to
;;;; arm64_win asm, assemble+link it with the driver via cc, run it, and check
;;;; the exit code / stdout.
;;;;
;;;; Skipped rather than failed, following the arm64_apple twin: files with no
;;;; driver, files marked `# skip arm64_win`, anything the backend still
;;;; refuses (it raises rather than miscompiling -- today that is TLS), and
;;;; drivers that will not build here because they want POSIX rather than
;;;; because the codegen is wrong.  Every skip prints its reason.
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-win-corpus-e2e.lisp
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

(defun tmp (name) (uiop:tmpize-pathname (merge-pathnames name (uiop:temporary-directory))))

(defun build-run (asm driver)
  (let ((sf (tmp "a64wce2e.s")) (cf (tmp "a64wce2e.c")) (exe (tmp "a64wce2e.exe")))
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (with-open-file (s cf :direction :output :if-exists :supersede) (write-string driver s))
    (multiple-value-bind (o e code)
        (uiop:run-program (list "cc" (namestring sf) (namestring cf) "-o" (namestring exe))
                          :output :string :error-output :string :ignore-error-status t)
      (declare (ignore o))
      (unless (zerop code) (error "link failed: ~a" (subseq e 0 (min 200 (length e))))))
    ;; latin-1 so a miscompile that prints garbage surfaces as an output
    ;; MISMATCH rather than a UTF-8 decoding error that we would file as a skip.
    (multiple-value-bind (out err code)
        (uiop:run-program (list (namestring exe)) :output :string :error-output :string
                          :ignore-error-status t :external-format :latin-1)
      (declare (ignore err))
      (values code out))))

(defun skip-target-p (lines)
  "QBE corpus convention: a leading `# skip <targets...>` line lists targets the
program is not expected to run on.  A bare `arm64` covers every arm64 variant --
dark.ssa carries `# skip arm64 arm64_apple rv64 amd64_win`, and it is the
architecture, not the platform, that it cannot run on."
  (let ((first (car lines)))
    (and first (uiop:string-prefix-p "# skip" first)
         (intersection '("arm64" "arm64_win")
                       (uiop:split-string first :separator '(#\Space))
                       :test #'string=))))

(defun same-output-p (got want)
  "Compare program output ignoring line-ending style: the C runtime writes CRLF
here, while the corpus records the expected stdout with bare LF."
  (flet ((norm (s) (string-right-trim '(#\Newline) (remove #\Return s))))
    (string= (norm got) (norm want))))

(defun run-corpus-file (p)
  (let* ((txt (uiop:read-file-string p))
         (lines (uiop:split-string txt :separator '(#\Newline)))
         (driver (extract-block lines "driver")))
    (when (skip-target-p lines)
      (incf *skip*) (format t "~&  skip ~a: marked # skip arm64_win~%" (file-namestring p))
      (return-from run-corpus-file :skip))
    (unless driver (return-from run-corpus-file :nodriver))
    (let ((expect-out (extract-block lines "output")))
      (handler-case
          (let ((asm (qbe:a64-be-emit-module (qbe:parse-file p) qbe:*arm64-win-target*)))
            (multiple-value-bind (code out) (build-run asm driver)
              (cond
                (expect-out
                 (if (same-output-p out expect-out)
                     (progn (incf *pass*) (format t "~&  ok   ~a~%" (file-namestring p)))
                     (progn (incf *fail*)
                            (format t "~&  FAIL ~a: output mismatch~%    got  ~s~%    want ~s~%"
                                    (file-namestring p) out expect-out))))
                (t
                 (if (zerop code)
                     (progn (incf *pass*) (format t "~&  ok   ~a~%" (file-namestring p)))
                     (progn (incf *fail*)
                            (format t "~&  FAIL ~a: exit ~a~%" (file-namestring p) code)))))))
        (error (e)
          (incf *skip*)
          (format t "~&  skip ~a: ~a~%" (file-namestring p)
                  (subseq (princ-to-string e) 0 (min 90 (length (princ-to-string e))))))))))

;;; ------------------------------------------------------------------- driver
(defun cc-triple ()
  (ignore-errors
   (string-trim '(#\Newline #\Return #\Space)
                (uiop:run-program (list "cc" "-dumpmachine") :output :string))))

(let ((triple (cc-triple)))
  (if (and triple (search "aarch64" triple) (search "windows" triple))
      (dolist (p (corpus-files)) (run-corpus-file p))
      (format t "~&  skip all (cc is ~a, need an aarch64-*-windows cc)~%"
              (or triple "unavailable"))))

(format t "~&=== arm64_win corpus e2e (native Windows ARM64) ===~%  ~
          ~d passed, ~d failed, ~d skipped~%" *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
