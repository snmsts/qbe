;;;; dom.lisp --- A1 oracle: our dominator tree vs `qbe -dN`'s "> Dominators:".
;;;; usage: QBE_BIN=/path/to/qbe ros -Q run -- --script test/dom.lisp
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun dom-string (fn)
  "Reproduce QBE's `> Dominators:` body for FN: one line per block that has
dom-tree children, `%10s:` name then the children (in dlink order)."
  (qbe:fill-cfg fn)
  (qbe:fill-dom fn)
  (with-output-to-string (s)
    (dolist (b (qbe:fn-blocks fn))
      (when (qbe:blk-doms b)
        (format s "~10@A:~{ ~A~}~%" (qbe:blk-name b)
                (mapcar #'qbe:blk-name (qbe:blk-doms b)))))))

(defun qbe-dominators (dn-dump)
  "Alist fn-name -> the `> Dominators:` body from a -dN dump."
  (let ((result '()) (name nil) (in nil) (acc '()))
    (labels ((flush () (when name
                         (let ((lines (nreverse acc)))
                           (loop while (and lines (string= (car (last lines)) ""))
                                 do (setf lines (butlast lines)))
                           (push (cons name (format nil "~{~A~%~}" lines)) result))
                         (setf acc '()))))
      (dolist (line (uiop:split-string dn-dump :separator '(#\Newline)))
        (cond
          ((uiop:string-prefix-p "**** Function " line)
           (flush)
           (let* ((rest (subseq line (length "**** Function ")))
                  (end (search " ****" rest)))
             (setf name (subseq rest 0 (or end (length rest))) in nil)))
          ((string= line "> Dominators:") (setf in t))
          ((uiop:string-prefix-p "> " line) (setf in nil))
          (in (push line acc))))
      (flush))
    (nreverse result)))

(defun dn-dump (ssa-path)
  "The -dN dump for SSA-PATH: from the saved golden if present, else live qbe."
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path) :type "dn")
            (merge-pathnames "test/golden-dn/"
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-dN" "-o" "/dev/null" (namestring ssa-path))
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore out)) err))))

(defun diff-dom (ssa-path &key (verbose t))
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (qbe-dominators (dn-dump ssa-path)))
         (ok 0) (total 0) (bad '()))
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (let ((mine (dom-string fn))
            (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
        (if (string= mine ref) (incf ok)
            (progn (push (qbe:fn-name fn) bad)
                   (when verbose
                     (format t "~&[DOM MISMATCH] ~a in ~a~%--- mine ---~%~a--- ref ---~%~a~%"
                             (qbe:fn-name fn) (file-namestring ssa-path) mine ref))))))
    (values ok total (nreverse bad))))

(let ((tot 0) (ok 0) (files-ok 0) (nfiles 0))
  (dolist (p (corpus-files))
    (incf nfiles)
    (handler-case
        (multiple-value-bind (o n bad) (diff-dom p :verbose t)
          (incf tot n) (incf ok o)
          (when (null bad) (incf files-ok))
          (when bad (format t "~&~a: ~d/~d  FAIL ~{~a ~}~%" (file-namestring p) o n bad)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== dominators: ~d/~d functions, ~d/~d files ===~%" ok tot files-ok nfiles)
  (sb-ext:exit :code (if (= ok tot) 0 1)))
