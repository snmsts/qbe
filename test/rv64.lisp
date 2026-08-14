;;;; rv64.lisp --- rv64 oracle: our ABI + isel vs `qbe -t rv64 -dA / -dI`.
;;;;
;;;; usage:  ros -Q run -- --script test/rv64.lisp
;;;;
;;;; Two pass-level dumps, diffed per function over the whole corpus:
;;;;   "> After ABI lowering:"          (abi1 = rv64_abi; abi0 is elimsb,
;;;;                                     which -dA does not dump separately)
;;;;   "> After instruction selection:" (rv64_isel)
;;;; Goldens live in test/golden-rv64-{da,di}/ (captured from upstream QBE at
;;;; e786f06); without a golden the live QBE_BIN oracle is invoked.  As with
;;;; the other oracles `raw` is offset by QBE's run-global newtmp counter, so
;;;; `norm` (temp suffixes canonicalized) is the structural gate.
;;;;
;;;; The rv64 pipeline has T.cansel = 0, so there is NO if-conversion.  The
;;;; final-assembly stage is exercised by test/rv64-corpus-e2e.lisp (native
;;;; execution in a linux/riscv64 container); rega's register choices and
;;;; block layout legitimately differ from upstream, so full-asm equality is
;;;; not a gate (38/77 corpus files happen to match byte-for-byte anyway).
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun rv-dump (ssa-path kind)
  "The -dA / -dI dump for SSA-PATH: from the saved golden if present, else the
live QBE_BIN oracle."
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path)
                           :type (ecase kind (:da "da") (:di "di")))
            (merge-pathnames (ecase kind
                               (:da "test/golden-rv64-da/")
                               (:di "test/golden-rv64-di/"))
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-t" "rv64"
                                    (ecase kind (:da "-dA") (:di "-dI"))
                                    "-o" *null-device* (namestring ssa-path))
                              :output :string :error-output :string
                              :ignore-error-status t)
          (declare (ignore out)) err))))

(defun rv-sections (dump header)
  "Alist fn-name -> the block of lines under HEADER for each function in DUMP."
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

;;; Pre-abi1 pipeline (main.c func for T.cansel=0, so NO ifconvert): abi0 =
;;; elimsb, SSA, mid-end.  The mid-end is target-independent; only abi1/isel
;;; read the active target, so *target* is bound just around them (matching
;;; how the goldens were captured).
(defun rv-mid-end (fn)
  (qbe:elimsb fn)
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:fill-alias fn) (qbe:loadopt fn) (qbe:fill-use fn) (qbe:fill-alias fn)
  (qbe:coalesce fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:gvn fn) (qbe:fill-cfg fn) (qbe:simplcfg fn)
  (qbe:fill-use fn) (qbe:fill-dom fn) (qbe:gcm fn) (qbe:fill-use fn))

(defun our-rv-abi (fn)
  (rv-mid-end fn)
  (let ((qbe::*target* qbe:*rv64-target*))
    (qbe:rv64-abi fn))
  (qbe:print-fn-to-string fn))

(defun our-rv-isel (fn)
  (rv-mid-end fn)
  (let ((qbe::*target* qbe:*rv64-target*))
    (qbe:rv64-abi fn) (qbe::simpl fn) (qbe:fill-cfg fn) (qbe:fill-use fn)
    (qbe:rv64-isel fn))
  (qbe:print-fn-to-string fn))

(defun run-stage (title kind header ours)
  (let ((raw 0) (norm 0) (sup 0) (unsup 0) (tot 0))
    (dolist (p (corpus-files))
      (handler-case
          (let* ((mod (qbe:parse-file p))
                 (golden (rv-sections (rv-dump p kind) header)))
            (setf qbe::*tmp-counter* 0) (qbe::reset-stash)
            (dolist (fn (qbe:module-funcs mod))
              (incf tot)
              (handler-case
                  (let ((mine (funcall ours fn))
                        (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
                    (incf sup)
                    (when (string= mine ref) (incf raw))
                    (if (string= (normalize mine) (normalize ref))
                        (incf norm)
                        (format t "~&[MISMATCH] ~a in ~a~%" (qbe:fn-name fn)
                                (file-namestring p))))
                (error (e) (declare (ignore e)) (incf unsup)))))
        (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
    (format t "~&=== rv64 ~a ===~%  supported: ~d/~d functions~%  ~
              raw  (byte-exact):   ~d/~d supported~%  ~
              norm (structure):    ~d/~d supported~%"
            title sup tot raw sup norm sup)
    (and (= norm sup) (= unsup 0))))

(let ((a (run-stage "abi1 (rv64_abi) — ABI-lowering dump" :da
                    "> After ABI lowering:" #'our-rv-abi))
      (b (run-stage "isel (rv64_isel) — instruction-selection dump" :di
                    "> After instruction selection:" #'our-rv-isel)))
  (sb-ext:exit :code (if (and a b) 0 1)))
