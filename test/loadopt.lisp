;;;; loadopt.lisp --- C1 oracle: our fillalias+loadopt vs `qbe -dM`'s
;;;; "> After load elimination:" printfn dump.
;;;;
;;;; usage:  ros -Q run -- --script test/loadopt.lisp
;;;;
;;;; loadopt mints run-global "%ld.N" temps, so raw byte-diff carries the same
;;;; counter offset as every other backend oracle; `norm` (temp suffixes
;;;; canonicalized) is the structural signal.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
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

(defun normalize (s)
  (let ((map (make-hash-table :test 'equal)) (ctr 0)
        (out (make-string-output-stream)) (i 0) (n (length s)))
    (flet ((idch (ch) (or (alphanumericp ch) (char= ch #\_) (char= ch #\.))))
      (loop while (< i n) do
        (let ((c (char s i)))
          (cond
            ((char= c #\%)
             (write-char c out) (incf i)
             (let ((start i))
               (loop while (and (< i n) (idch (char s i))) do (incf i))
               (let* ((tok (subseq s start i)) (dot (position #\. tok :from-end t)))
                 (if (and dot (< (1+ dot) (length tok))
                          (every #'digit-char-p (subseq tok (1+ dot))))
                     (let ((canon (or (gethash tok map) (setf (gethash tok map) (incf ctr)))))
                       (format out "~a.~d" (subseq tok 0 dot) canon))
                     (write-string tok out)))))
            (t (write-char c out) (incf i))))))
    (get-output-stream-string out)))

(defun our-loadopt (fn)
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:fill-alias fn) (qbe:loadopt fn)
  (qbe:print-fn-to-string fn))

(defun diff-loadopt (ssa-path)
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (dm-sections (dm-dump ssa-path) "> After load elimination:"))
         (raw 0) (norm 0) (total 0) (bad '()))
    (setf qbe::*tmp-counter* 0)
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (let ((mine (our-loadopt fn))
            (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
        (when (string= mine ref) (incf raw))
        (if (string= (normalize mine) (normalize ref)) (incf norm)
            (push (qbe:fn-name fn) bad))))
    (values raw norm total (nreverse bad))))

(let ((tot 0) (raw 0) (norm 0) (files-ok 0) (nfiles 0))
  (dolist (p (corpus-files))
    (incf nfiles)
    (handler-case
        (multiple-value-bind (r nm n bad) (diff-loadopt p)
          (incf tot n) (incf raw r) (incf norm nm)
          (when (null bad) (incf files-ok))
          (when bad (format t "~&~a: norm ~d/~d  fail ~{~a ~}~%" (file-namestring p) nm n bad)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== loadopt / After load elimination ===~%")
  (format t "  raw  (byte-exact):   ~d/~d functions~%" raw tot)
  (format t "  norm (structure):    ~d/~d functions, ~d/~d files~%" norm tot files-ok nfiles)
  (sb-ext:exit :code (if (= norm tot) 0 1)))
