;;;; arm64-abi.lisp --- G2 oracle: our arm64 ABI vs `qbe -t arm64_apple -dA`.
;;;;
;;;; Two dump points in arm64_apple's -dA:
;;;;   "> After Apple pre-ABI:"  (abi0 = apple_extsb)
;;;;   "> After ABI lowering:"   (abi1 = arm64_abi)
;;;; This runner diffs the pre-ABI stage first (abi0); the ABI-lowering stage is
;;;; added as abi1 lands.  As with the amd64 abi oracle, `raw` is offset by the
;;;; run-global newtmp counter so `norm` (temp suffixes canonicalized) is the
;;;; structural signal.
;;;; usage: ros -Q run -- --script test/arm64-abi.lisp
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun a64da-dump (ssa-path)
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path) :type "da")
            (merge-pathnames "test/golden-arm64-da/"
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-t" "arm64_apple" "-dA" "-o" "/dev/null"
                                    (namestring ssa-path))
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore out)) err))))

(defun a64da-sections (dump header)
  "Alist fn-name -> the block of lines under HEADER (e.g. \"> After Apple
pre-ABI:\") for each function in DUMP."
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
          ((string= line header) (setf acc '() in t))
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

(defun our-a64-pre-abi (fn)
  "abi0 only (apple_extsb): parse -> a64-apple-extsb -> print."
  (qbe:a64-apple-extsb fn)
  (qbe:print-fn-to-string fn))

(defun diff-pre-abi (ssa-path)
  "(values raw-ok norm-ok supported unsupported total)."
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (a64da-sections (a64da-dump ssa-path) "> After Apple pre-ABI:"))
         (raw 0) (norm 0) (sup 0) (unsup 0) (total 0))
    (setf qbe::*tmp-counter* 0) (qbe::reset-stash)
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (handler-case
          (let ((mine (our-a64-pre-abi fn))
                (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
            (incf sup)
            (when (string= mine ref) (incf raw))
            (when (string= (normalize mine) (normalize ref)) (incf norm)))
        (error (e) (declare (ignore e)) (incf unsup))))
    (values raw norm sup unsup total)))

(let ((raw 0) (norm 0) (sup 0) (unsup 0) (tot 0))
  (dolist (p (corpus-files))
    (handler-case
        (multiple-value-bind (r nm s u n) (diff-pre-abi p)
          (incf raw r) (incf norm nm) (incf sup s) (incf unsup u) (incf tot n)
          (when (and (> s 0) (< nm s))
            (format t "~&~a: norm ~d/~d supported (~d unsupported)~%"
                    (file-namestring p) nm s u)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== arm64 abi0 (apple_extsb) — pre-ABI dump ===~%")
  (format t "  supported: ~d/~d functions~%" sup tot)
  (format t "  raw  (byte-exact):   ~d/~d supported~%" raw sup)
  (format t "  norm (structure):    ~d/~d supported~%" norm sup)
  (sb-ext:exit :code (if (= norm sup) 0 1)))
