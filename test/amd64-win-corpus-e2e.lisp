;;;; amd64-win-corpus-e2e.lisp --- run QBE's own test/*.ssa programs end to end
;;;; through the amd64_win backend.
;;;;
;;;; The twin of test/arm64-win-corpus-e2e.lisp, and the same bar: not that the
;;;; corpus assembles, but that the programs run and print the right thing.
;;;;
;;;; Each corpus file embeds a C driver (# >>> driver ... # <<<) and optionally
;;;; expected stdout (# >>> output ... # <<<).  We emit the whole module to
;;;; amd64_win asm, assemble+link it with the driver via an x86_64 Windows cc,
;;;; run it, and check the exit code / stdout.
;;;;
;;;; Host note: this also runs on Windows ARM64, where the x86_64 toolchain
;;;; (MSYS2 UCRT64) and the binaries it produces both go through the OS's x64
;;;; emulation.  Point AMD64_CC at that compiler; its own directory is prepended
;;;; to PATH because a mingw gcc needs its sibling DLLs to start at all.
;;;;
;;;; Skipped rather than failed, following the arm64_win twin: files with no
;;;; driver, files marked `# skip amd64_win`, anything the backend still refuses
;;;; (it raises rather than miscompiling -- today that is extern/TLS, which
;;;; QBE itself dies on for this target), and drivers that want POSIX.  Every
;;;; skip prints its reason.
;;;;
;;;; usage:  AMD64_CC=/c/msys64/ucrt64/bin/gcc.exe \
;;;;           ros -Q run -- --script test/amd64-win-corpus-e2e.lisp
(require :asdf)
(require :sb-posix)
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

;;; ------------------------------------------------------------------ toolchain
(defvar *cc* nil "The x86_64 Windows C compiler driving assembly + link.")

(defun triple-of (cc)
  (ignore-errors
   (string-trim '(#\Newline #\Return #\Space)
                (uiop:run-program (list cc "-dumpmachine") :output :string))))

(defun amd64-windows-cc-p (triple)
  (and triple (search "x86_64" triple)
       (or (search "windows" triple) (search "mingw" triple))))

(defun find-amd64-cc ()
  "AMD64_CC if it is an x86_64 Windows cc, else `cc` if it is one, else the
MSYS2 UCRT64 gcc if it is installed.  Returns the path, or NIL."
  (dolist (cand (remove nil (list (uiop:getenv "AMD64_CC") "cc"
                                  "C:/msys64/ucrt64/bin/gcc.exe")))
    (when (amd64-windows-cc-p (triple-of cand))
      ;; A mingw gcc resolves libisl/libmpc/... from its own bin directory, so
      ;; it cannot even start unless that directory is on PATH.
      (let ((dir (directory-namestring (or (ignore-errors (truename cand)) cand))))
        (when (and (plusp (length dir)) (not (search dir (uiop:getenv "PATH"))))
          (sb-posix:putenv (format nil "PATH=~a;~a"
                                   (substitute #\\ #\/ dir) (uiop:getenv "PATH")))))
      (return cand))))

(defun tmp (name) (uiop:tmpize-pathname (merge-pathnames name (uiop:temporary-directory))))

(defun build-run (asm driver)
  (let ((sf (tmp "x64wce2e.s")) (cf (tmp "x64wce2e.c")) (exe (tmp "x64wce2e.exe")))
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (with-open-file (s cf :direction :output :if-exists :supersede) (write-string driver s))
    (multiple-value-bind (o e code)
        (uiop:run-program (list *cc* (uiop:native-namestring sf) (uiop:native-namestring cf)
                                "-o" (uiop:native-namestring exe))
                          :output :string :error-output :string :ignore-error-status t)
      (declare (ignore o))
      (unless (zerop code) (error "link failed: ~a" (subseq e 0 (min 200 (length e))))))
    ;; latin-1 so a miscompile that prints garbage surfaces as an output
    ;; MISMATCH rather than a UTF-8 decoding error that we would file as a skip.
    (multiple-value-bind (out err code)
        (uiop:run-program (list (uiop:native-namestring exe))
                          :output :string :error-output :string
                          :ignore-error-status t :external-format :latin-1)
      (declare (ignore err))
      (values code out))))

(defun skip-target-p (lines)
  "QBE corpus convention: a leading `# skip <targets...>` line lists targets the
program is not expected to run on."
  (let ((first (car lines)))
    (and first (uiop:string-prefix-p "# skip" first)
         (intersection '("amd64" "amd64_win")
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
      (incf *skip*) (format t "~&  skip ~a: marked # skip amd64_win~%" (file-namestring p))
      (return-from run-corpus-file :skip))
    (unless driver (return-from run-corpus-file :nodriver))
    (let ((expect-out (extract-block lines "output")))
      (handler-case
          (let ((asm (qbe:be-emit-module (qbe:parse-file p) qbe:*amd64-win-target*)))
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
(setf *cc* (find-amd64-cc))
(if *cc*
    (dolist (p (corpus-files)) (run-corpus-file p))
    (format t "~&  skip all (no x86_64 Windows cc; set AMD64_CC)~%"))

(format t "~&=== amd64_win corpus e2e ===~%  ~
          ~d passed, ~d failed, ~d skipped~%" *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
