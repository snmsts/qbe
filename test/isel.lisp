; ;;; isel.lisp --- M3/B1 oracle: our amd64 SysV abi1 vs `qbe -dA`'s
;;;; "> After instruction selection:" printfn dump.
;;;;
;;;; usage:  ros -Q run -- --script test/abi.lisp
;;;;
;;;; B1 handles the scalar path only (<=6 int / <=8 sse register params,
;;;; scalar/void returns, call-free); everything else signals an error and
;;;; is counted as "unsupported" (skipped), not a mismatch.  As with the SSA
;;;; oracle, `raw` byte-diff is offset by QBE's run-global newtmp counter
;;;; (backend %isel/%abi temps of preceding functions), so `norm` (temp
;;;; suffixes canonicalized) is the structural signal.  This also rides on
;;;; the mid-end opts (loadopt/gvn/gcm) being no-ops for a function, since
;;;; those run before abi1 in QBE but are not implemented yet.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun da-dump (ssa-path)
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path) :type "di")
            (merge-pathnames "test/golden-di/"
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-dA" "-o" "/dev/null" (namestring ssa-path))
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore out)) err))))

(defun da-sections (dump)
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

(defun our-abi (fn)
  ;; Full pre-abi pipeline (mirrors main.c for amd64, T.cansel=1): SSA, the
  ;; mid-end (gvn -> simplcfg -> gcm), then if-conversion, then abi1.  loadopt
  ;; and coalesce (before gvn in QBE) are still unimplemented, so functions
  ;; needing them remain gated.
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:fill-alias fn) (qbe:loadopt fn) (qbe:fill-use fn) (qbe:fill-alias fn) (qbe:coalesce fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:gvn fn) (qbe:fill-cfg fn) (qbe:simplcfg fn)
  (qbe:fill-use fn) (qbe:fill-dom fn) (qbe:gcm fn) (qbe:fill-use fn)
  (qbe:ifconvert fn) (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:amd64-abi fn) (qbe:simpl fn) (qbe:fill-cfg fn) (qbe:fill-use fn)
  (qbe:amd64-isel fn)
  (qbe:print-fn-to-string fn))

(defun diff-abi (ssa-path)
  "(values raw-ok norm-ok supported unsupported total)."
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (da-sections (da-dump ssa-path)))
         (raw 0) (norm 0) (sup 0) (unsup 0) (total 0))
    (setf qbe::*tmp-counter* 0) (qbe::reset-stash)
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (handler-case
          (let ((mine (our-abi fn))
                (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
            (incf sup)
            (when (string= mine ref) (incf raw))
            (when (string= (normalize mine) (normalize ref)) (incf norm)))
        (error () (incf unsup))))
    (values raw norm sup unsup total)))

(let ((raw 0) (norm 0) (sup 0) (unsup 0) (tot 0))
  (dolist (p (corpus-files))
    (handler-case
        (multiple-value-bind (r nm s u n) (diff-abi p)
          (incf raw r) (incf norm nm) (incf sup s) (incf unsup u) (incf tot n)
          (when (and (> s 0) (< nm s))
            (format t "~&~a: norm ~d/~d supported (~d unsupported)~%"
                    (file-namestring p) nm s u)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== amd64 isel (B3 scalar-int slice) ===~%")
  (format t "  supported (no structs/stack-args/varargs): ~d/~d functions~%" sup tot)
  (format t "  raw  (byte-exact):   ~d/~d supported~%" raw sup)
  (format t "  norm (structure):    ~d/~d supported~%" norm sup)
  (sb-ext:exit :code (if (= norm sup) 0 1)))
