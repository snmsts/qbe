;;;; promote.lisp --- A4 oracle: our promote vs `qbe -dM`'s
;;;; "> After slot promotion:" printfn dump (promote in isolation, pre-ssa).
;;;;
;;;; usage:  ros -Q run -- --script test/promote.lisp
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun dm-dump (ssa-path)
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path) :type "dm")
            (merge-pathnames "test/golden-dm/"
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-dM" "-o" "/dev/null" (namestring ssa-path))
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore out)) err))))

(defun dm-sections (dump section)
  "Alist fn-name -> the body of the named `> ...:` SECTION for each function."
  (let ((result '()) (name nil) (in nil) (acc '()))
    (labels ((flush ()
               (when (and name in)
                 (let ((lines (nreverse acc)))
                   (loop while (and lines (string= (car (last lines)) ""))
                         do (setf lines (butlast lines)))
                   (push (cons name (format nil "~{~A~%~}" lines)) result)))
               (setf acc '() in nil)))
      (dolist (line (uiop:split-string dump :separator '(#\Newline)))
        (cond
          ((uiop:string-prefix-p "**** Function " line)
           (flush)
           (let* ((rest (subseq line (length "**** Function ")))
                  (end (search " ****" rest)))
             (setf name (subseq rest 0 (or end (length rest))))))
          ((string= line section) (setf acc '() in t))
          ((uiop:string-prefix-p "> " line) (when in (flush)))
          (in (push line acc))))
      (flush))
    (nreverse result)))

(defun our-promote (fn)
  (qbe:fill-cfg fn)
  (qbe:fill-use fn)
  (qbe:promote fn)
  (qbe:print-fn-to-string fn))

(defun diff-promote (ssa-path)
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (dm-sections (dm-dump ssa-path) "> After slot promotion:"))
         (ok 0) (total 0) (bad '()))
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (let ((mine (our-promote fn))
            (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
        (if (string= mine ref) (incf ok) (push (qbe:fn-name fn) bad))))
    (values ok total (nreverse bad))))

(let ((tot 0) (ok 0) (files-ok 0) (nfiles 0))
  (dolist (p (corpus-files))
    (incf nfiles)
    (handler-case
        (multiple-value-bind (o n bad) (diff-promote p)
          (incf tot n) (incf ok o)
          (when (null bad) (incf files-ok))
          (when bad (format t "~&~a: ~d/~d  fail ~{~a ~}~%" (file-namestring p) o n bad)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== slot promotion: ~d/~d functions, ~d/~d files ===~%" ok tot files-ok nfiles)
  (sb-ext:exit :code (if (= ok tot) 0 1)))
