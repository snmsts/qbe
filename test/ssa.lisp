;;;; ssa.lisp --- A2+A3+A4 oracle: our SSA construction vs `qbe -dN`'s
;;;; "> After SSA construction:" printfn dump.
;;;;
;;;; usage:  ros -Q run -- --script test/ssa.lisp
;;;;
;;;; With A4 (promote) in the pipeline, SSA *structure* matches the whole
;;;; corpus (norm 180/180).  The residual raw (byte) diffs are only `%x.N`
;;;; suffix NUMBERS: QBE's newtmp counter is run-global and QBE runs each
;;;; function through its WHOLE backend (isel/rega, which mint `%isel.N`
;;;; temps) before parsing the next function -- so a function's temp numbers
;;;; include every preceding function's backend temps, which don't exist
;;;; until M3/isel.  Hence `norm` (suffixes canonicalized) is the true
;;;; A2-A4 acceptance signal; `raw` closes as the backend lands.
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun dn-dump (ssa-path)
  "The -dN dump for SSA-PATH: from saved golden if present, else live qbe."
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

(defun qbe-ssa-sections (dn-dump)
  "Alist fn-name -> the `> After SSA construction:` body (the printfn block)."
  (let ((result '()) (name nil) (in nil) (acc '()))
    (labels ((flush ()
               (when (and name in)
                 (let ((lines (nreverse acc)))
                   (loop while (and lines (string= (car (last lines)) ""))
                         do (setf lines (butlast lines)))
                   (push (cons name (format nil "~{~A~%~}" lines)) result)))
               (setf acc '() in nil)))
      (dolist (line (uiop:split-string dn-dump :separator '(#\Newline)))
        (cond
          ((uiop:string-prefix-p "**** Function " line)
           (flush)
           (let* ((rest (subseq line (length "**** Function ")))
                  (end (search " ****" rest)))
             (setf name (subseq rest 0 (or end (length rest))))))
          ((string= line "> After SSA construction:") (setf acc '() in t))
          ((uiop:string-prefix-p "> " line) (when in (flush)))
          (in (push line acc))))
      (flush))
    (nreverse result)))

(defun our-ssa (fn)
  "Run the A4+A2+A3 pipeline on FN and return its printfn text."
  (qbe:fill-cfg fn)
  (qbe:fill-use fn)
  (qbe:promote fn)
  (qbe:fill-use fn)        ; QBE re-fills use after promote (new defs)
  (qbe:ssa fn)
  (qbe:print-fn-to-string fn))

(defun normalize (s)
  "Canonicalize newtmp suffixes: rewrite each distinct `%name.N` to `%name.<rank>`
by order of first appearance.  Cancels QBE's run-global counter offset (which we
can't reproduce until A4/promote), isolating SSA *structure* from temp numbering."
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
               (let* ((tok (subseq s start i))
                      (dot (position #\. tok :from-end t)))
                 (if (and dot (< (1+ dot) (length tok))
                          (every #'digit-char-p (subseq tok (1+ dot))))
                     (let ((canon (or (gethash tok map) (setf (gethash tok map) (incf ctr)))))
                       (format out "~a.~d" (subseq tok 0 dot) canon))
                     (write-string tok out)))))
            (t (write-char c out) (incf i))))))
    (get-output-stream-string out)))

(defun diff-ssa (ssa-path)
  "Returns (values raw-ok norm-ok total norm-bad raw-bad).  raw = byte-exact;
norm = equal after canonicalizing temp suffixes (SSA structure only)."
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (qbe-ssa-sections (dn-dump ssa-path)))
         (raw-ok 0) (norm-ok 0) (total 0) (norm-bad '()) (raw-bad '()))
    (setf qbe::*tmp-counter* 0)          ; reset once per file, as qbe does
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (let ((mine (our-ssa fn))
            (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
        (if (string= mine ref) (incf raw-ok) (push (qbe:fn-name fn) raw-bad))
        (if (string= (normalize mine) (normalize ref))
            (incf norm-ok)
            (push (qbe:fn-name fn) norm-bad))))
    (values raw-ok norm-ok total (nreverse norm-bad) (nreverse raw-bad))))

(let ((tot 0) (raw 0) (norm 0) (files-raw 0) (files-norm 0) (nfiles 0))
  (dolist (p (corpus-files))
    (incf nfiles)
    (handler-case
        (multiple-value-bind (r nm n bad raw-bad) (diff-ssa p)
          (incf tot n) (incf raw r) (incf norm nm)
          (when (= r n) (incf files-raw))
          (when (null bad) (incf files-norm))
          (when bad
            (format t "~&~a: STRUCT-DIFF ~{~a ~}~%" (file-namestring p) bad))
          (when (and raw-bad (null bad))
            (format t "~&~a: raw-only diff (suffix offset) ~{~a ~}~%"
                    (file-namestring p) raw-bad)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== ssa construction (promote + SSA) ===~%")
  (format t "  raw  (byte-exact):        ~d/~d functions, ~d/~d files~%" raw tot files-raw nfiles)
  (format t "  norm (structure only):    ~d/~d functions, ~d/~d files~%" norm tot files-norm nfiles)
  (format t "  (raw<norm gap = preceding fns' backend %isel.N temps, awaits M3/isel)~%")
  (sb-ext:exit :code (if (= norm tot) 0 1)))
