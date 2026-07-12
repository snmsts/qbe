;;;; arm64-isel.lisp --- G3 oracle: our arm64 isel vs `qbe -t arm64_apple -dI`'s
;;;; "> After instruction selection:" printfn dump.
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-isel.lisp
;;;;
;;;; The arm64_apple pipeline has T.cansel = 0, so there is NO if-conversion
;;;; (unlike amd64).  As with the other oracles `raw` is offset by QBE's
;;;; run-global newtmp counter (%isel/%abi temps of preceding functions), so
;;;; `norm` (temp suffixes canonicalized) is the structural signal.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun a64di-dump (ssa-path)
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path) :type "di")
            (merge-pathnames "test/golden-arm64-di/"
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-t" "arm64_apple" "-dI" "-o" "/dev/null"
                                    (namestring ssa-path))
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore out)) err))))

(defun a64di-sections (dump)
  "Alist fn-name -> the block under \"> After instruction selection:\"."
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
          ((string= line "> After instruction selection:") (setf acc '() in t))
          ((uiop:string-prefix-p "> " line) (when in (flush)))
          (in (push line acc))))
      (flush))
    (nreverse result)))

(defun normalize (s)
  "Canonicalize newtmp suffixes: each distinct `%name.N` -> `%name.<rank>`."
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

(defun our-a64-isel (fn)
  "Full arm64_apple pre-isel pipeline (main.c func, T.cansel=0 → NO ifconvert):
abi0, SSA, mid-end (loadopt/coalesce/gvn/simplcfg/gcm), abi1, simpl, then isel."
  (qbe:a64-apple-extsb fn)
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:fill-alias fn) (qbe:loadopt fn) (qbe:fill-use fn) (qbe:fill-alias fn)
  (qbe:coalesce fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:gvn fn) (qbe:fill-cfg fn) (qbe:simplcfg fn)
  (qbe:fill-use fn) (qbe:fill-dom fn) (qbe:gcm fn) (qbe:fill-use fn)
  (qbe:arm64-abi fn) (qbe:simpl fn) (qbe:fill-cfg fn) (qbe:fill-use fn)
  (qbe:arm64-isel fn)
  (qbe:print-fn-to-string fn))

(defun diff-isel (ssa-path)
  "(values raw-ok norm-ok supported unsupported total)."
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (a64di-sections (a64di-dump ssa-path)))
         (raw 0) (norm 0) (sup 0) (unsup 0) (total 0))
    (setf qbe::*tmp-counter* 0) (qbe::reset-stash)
    (let ((qbe::*target* qbe:*arm64-apple-target*))
      (dolist (fn (qbe:module-funcs mod))
        (incf total)
        (handler-case
            (let ((mine (our-a64-isel fn))
                  (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
              (incf sup)
              (when (string= mine ref) (incf raw))
              (when (string= (normalize mine) (normalize ref)) (incf norm)))
          (error (e) (declare (ignore e)) (incf unsup)))))
    (values raw norm sup unsup total)))

(let ((raw 0) (norm 0) (sup 0) (unsup 0) (tot 0))
  (dolist (p (corpus-files))
    (handler-case
        (multiple-value-bind (r nm s u n) (diff-isel p)
          (incf raw r) (incf norm nm) (incf sup s) (incf unsup u) (incf tot n)
          (when (and (> s 0) (< nm s))
            (format t "~&~a: norm ~d/~d supported (~d unsupported)~%"
                    (file-namestring p) nm s u)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== arm64 isel (arm64_isel) — instruction-selection dump ===~%")
  (format t "  supported: ~d/~d functions~%" sup tot)
  (format t "  raw  (byte-exact):   ~d/~d supported~%" raw sup)
  (format t "  norm (structure):    ~d/~d supported~%" norm sup)
  (sb-ext:exit :code (if (= norm sup) 0 1)))
