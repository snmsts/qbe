;;;; gcm.lisp --- M2/C4 oracle: our gvn vs `qbe -dG`'s "> After GCM:" dump.
;;;;
;;;; usage:  ros -Q run -- --script test/gvn.lisp
;;;;
;;;; INCREMENTAL: current gvn implements normins only (canonicalization).
;;;; Functions needing copy-prop / fold / CSE / phi-dedup / narrowpars won't
;;;; match yet; this measures the normins-only subset.  `norm` canonicalizes
;;;; temp suffixes (QBE run-global counter offset).  Also gated on loadopt /
;;;; coalesce being no-ops (not implemented; they run before gvn in QBE).
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun dg-dump (ssa-path)
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path) :type "dg")
            (merge-pathnames "test/golden-dg/"
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-dG" "-o" "/dev/null" (namestring ssa-path))
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore out)) err))))

(defun dg-sections (dump)
  "Alist fn-name -> the '> After GCM:' body."
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
          ((string= line "> After GCM:") (setf acc '() in t))
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

(defun our-gvn (fn)
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:fill-alias fn) (qbe:loadopt fn) (qbe:fill-use fn) (qbe:fill-alias fn) (qbe:coalesce fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:gvn fn)
  (qbe:fill-cfg fn) (qbe:simplcfg fn)
  (qbe:fill-use fn) (qbe:fill-dom fn) (qbe:gcm fn)
  (qbe:print-fn-to-string fn))

(defun diff-gvn (ssa-path)
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (dg-sections (dg-dump ssa-path)))
         (raw 0) (norm 0) (total 0))
    (setf qbe::*tmp-counter* 0)
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (handler-case
          (let ((mine (our-gvn fn))
                (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
            (when (string= mine ref) (incf raw))
            (when (string= (normalize mine) (normalize ref)) (incf norm)))
        (error () nil)))
    (values raw norm total)))

(let ((raw 0) (norm 0) (tot 0))
  (dolist (p (corpus-files))
    (handler-case
        (multiple-value-bind (r nm n) (diff-gvn p)
          (incf raw r) (incf norm nm) (incf tot n))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== gcm / After GCM ===~%")
  (format t "  raw  (byte-exact):   ~d/~d functions~%" raw tot)
  (format t "  norm (structure):    ~d/~d functions~%" norm tot)
  (sb-ext:exit :code 0))
