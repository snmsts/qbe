;;;; harness.lisp --- M0 diff harness: parse->print vs QBE `-dP`.
;;;;
;;;; Two modes:
;;;;   * live   -- invoke the reference QBE binary for each file (needs qbe).
;;;;   * golden -- diff against captured *.dp dumps in test/golden/ (no qbe).
;;;; Capture goldens once (with qbe present); thereafter the suite is
;;;; self-contained.

(defpackage #:qbe-test
  (:use #:cl #:qbe)
  (:export #:*qbe-path* #:diff-file #:run-corpus #:capture-goldens
           #:corpus-files #:golden-for))
(in-package #:qbe-test)

(defparameter *qbe-path*
  (or (uiop:getenv "QBE_BIN") "qbe")
  "Reference QBE binary (oracle).  Defaults to `qbe` on PATH; override with the
QBE_BIN env var.  Only needed for live-oracle mode / capturing goldens; the
committed goldens let the suite run without it.")

(defun project-dir ()
  (asdf:system-relative-pathname "qbe-cl" ""))

(defun corpus-files ()
  (sort (directory (merge-pathnames "test/corpus/*.ssa" (project-dir)))
        #'string< :key #'namestring))

(defun golden-for (ssa-path)
  (merge-pathnames (make-pathname :name (pathname-name ssa-path) :type "dp")
                   (merge-pathnames "test/golden/" (project-dir))))

(defun qbe-dp (ssa-path)
  "Run `qbe -dP` on SSA-PATH; return its stderr (the after-parsing dump)."
  (multiple-value-bind (out err)
      (uiop:run-program (list *qbe-path* "-dP" "-o" "/dev/null" (namestring ssa-path))
                        :output :string :error-output :string :ignore-error-status t)
    (declare (ignore out))
    err))

(defun capture-goldens (&optional (files (corpus-files)))
  "Dump `qbe -dP` for each corpus file into test/golden/."
  (ensure-directories-exist (merge-pathnames "test/golden/" (project-dir)))
  (dolist (f files)
    (uiop:with-output-file (s (golden-for f) :if-exists :supersede)
      (write-string (qbe-dp f) s)))
  (format t "~&captured ~d goldens~%" (length files)))

(defun dp-for (ssa-path)
  "The -dP dump for SSA-PATH: from saved golden if present, else live qbe."
  (let ((g (golden-for ssa-path)))
    (if (probe-file g) (uiop:read-file-string g) (qbe-dp ssa-path))))

(defun split-dp (dp)
  "Split a -dP dump into an alist of (fn-name . body-string) where each body
ends with a trailing newline, matching print-fn-to-string."
  (let ((lines (uiop:split-string dp :separator '(#\Newline)))
        (result '()) (name nil) (acc '()))
    (labels ((flush ()
               (when name
                 (let ((body (nreverse acc)))
                   (loop while (and body (string= (car (last body)) ""))
                         do (setf body (butlast body)))
                   (push (cons name (format nil "~{~a~%~}" body)) result))
                 (setf name nil acc '()))))
      (dolist (line lines)
        (cond
          ((uiop:string-prefix-p "**** Function " line)
           (flush)
           (let* ((rest (subseq line (length "**** Function ")))
                  (end (search " ****" rest)))
             (setf name (subseq rest 0 (or end (length rest))))))
          ((string= line "> After parsing:"))
          (name (push line acc))))
      (flush))
    (nreverse result)))

(defun first-diff (a b)
  (let ((la (uiop:split-string a :separator '(#\Newline)))
        (lb (uiop:split-string b :separator '(#\Newline))))
    (loop for x in la for y in lb for i from 1
          unless (string= x y)
            do (return (format nil ">>> first diff at line ~d:~%  mine: ~s~%  ref:  ~s~%" i x y))
          finally (return (format nil ">>> differ in length (~d vs ~d lines)~%"
                                  (length la) (length lb))))))

(defun diff-file (ssa-path &key (verbose t))
  "Parse SSA-PATH, print each function, diff against its -dP dump.
Returns (values matched total mismatched-names)."
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (split-dp (dp-for ssa-path)))
         (total 0) (ok 0) (bad '()))
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (let ((mine (qbe:print-fn-to-string fn))
            (ref (cdr (assoc (qbe:fn-name fn) golden :test #'string=))))
        (cond
          ((null ref) (push (qbe:fn-name fn) bad)
           (when verbose (format t "~&[NO GOLDEN] ~a~%" (qbe:fn-name fn))))
          ((string= mine ref) (incf ok))
          (t (push (qbe:fn-name fn) bad)
             (when verbose
               (format t "~&[MISMATCH] ~a in ~a~%~a~%"
                       (qbe:fn-name fn) (file-namestring ssa-path)
                       (first-diff mine ref)))))))
    (values ok total (nreverse bad))))

(defun run-corpus (&key (files (corpus-files)) (verbose nil))
  (let ((tot 0) (ok 0) (files-ok 0) (nfiles 0))
    (dolist (p files)
      (incf nfiles)
      (handler-case
          (multiple-value-bind (o n bad) (diff-file p :verbose verbose)
            (incf tot n) (incf ok o)
            (when (null bad) (incf files-ok))
            (when (or verbose bad)
              (format t "~&~a: ~d/~d~@[  FAIL: ~{~a ~}~]~%" (file-namestring p) o n bad)))
        (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
    (format t "~&=== ~d/~d functions match, ~d/~d files clean ===~%"
            ok tot files-ok nfiles)
    (= ok tot)))
