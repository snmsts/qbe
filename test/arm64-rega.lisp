;;;; arm64-rega.lisp --- G4 oracle: our arm64 spill/rega vs
;;;; `qbe -t arm64_apple -dR` "> After register allocation:".
;;;;
;;;; The generic backend (backend/spill/rega, made target-parametric in G0)
;;;; runs under the arm64 target here.  As with amd64 rega, a residual raw<norm
;;;; gap is expected; the strong signal is native execution (arm64-corpus-e2e).
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-rega.lisp
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun a64dr-dump (ssa-path)
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path) :type "dr")
            (merge-pathnames "test/golden-arm64-dr/"
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-t" "arm64_apple" "-dR" "-o" "/dev/null"
                                    (namestring ssa-path))
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore out)) err))))

(defun a64dr-sections (dump)
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
          ((string= line "> After register allocation:") (setf acc '() in t))
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

(defun our-a64-rega (fn)
  "arm64_apple backend through rega (T.cansel=0 -> NO ifconvert)."
  (qbe:a64-apple-extsb fn)
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:fill-alias fn) (qbe:loadopt fn) (qbe:fill-use fn) (qbe:fill-alias fn)
  (qbe:coalesce fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:gvn fn) (qbe:fill-cfg fn) (qbe:simplcfg fn)
  (qbe:fill-use fn) (qbe:fill-dom fn) (qbe:gcm fn) (qbe:fill-use fn)
  (qbe:arm64-abi fn) (qbe:simpl fn) (qbe:fill-cfg fn) (qbe:fill-use fn)
  (qbe:arm64-isel fn)
  (qbe:materialize-regs fn)
  (qbe:fill-cfg fn) (qbe:be-fill-live fn) (qbe:fill-loop fn) (qbe:fill-cost fn)
  (qbe:spill fn) (qbe:rega fn)
  (qbe:print-fn-to-string fn))

(defun diff-rega (ssa-path)
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (a64dr-sections (a64dr-dump ssa-path)))
         (raw 0) (norm 0) (sup 0) (unsup 0) (total 0))
    (setf qbe::*tmp-counter* 0) (qbe::reset-stash)
    (let ((qbe::*target* qbe:*arm64-apple-target*))
      (dolist (fn (qbe:module-funcs mod))
        (incf total)
        (handler-case
            (let ((mine (our-a64-rega fn))
                  (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
              (incf sup)
              (when (string= mine ref) (incf raw))
              (when (string= (normalize mine) (normalize ref)) (incf norm)))
          (error (e) (declare (ignore e)) (incf unsup)))))
    (values raw norm sup unsup total)))

(let ((raw 0) (norm 0) (sup 0) (unsup 0) (tot 0))
  (dolist (p (corpus-files))
    (handler-case
        (multiple-value-bind (r nm s u n) (diff-rega p)
          (incf raw r) (incf norm nm) (incf sup s) (incf unsup u) (incf tot n))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== arm64 rega (After register allocation) ===~%")
  (format t "  supported: ~d/~d functions~%" sup tot)
  (format t "  raw  (byte-exact):   ~d/~d supported~%" raw sup)
  (format t "  norm (structure):    ~d/~d supported~%" norm sup))
