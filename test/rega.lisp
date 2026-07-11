;;;; rega.lisp --- M4 oracle: our rega vs `qbe -dR` "> After register allocation:".
;;;;
;;;; usage:  ros -Q run -- --script test/rega.lisp
;;;;
;;;; Full backend: mid-end + abi1 + isel + materialize + filllive + fillloop +
;;;; fillcost + spill + rega, diffed against the -dR printfn.  Registers print as
;;;; R<id> and spill slots as S<n> (both per-function stable); `norm` only needs
;;;; to canonicalize QBE's run-global %name.N (rare post-rega, but edge blocks
;;;; are named after their endpoints so mostly register/slot refs remain).
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun dr-dump (ssa-path)
  (uiop:read-file-string
   (merge-pathnames (make-pathname :name (pathname-name ssa-path) :type "dr")
                    (merge-pathnames "test/golden-dr/"
                                     (asdf:system-relative-pathname "qbe-cl" "")))))

(defun dr-sections (dump)
  "Map function-name -> text of its `> After register allocation:` printfn body."
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
          ((and in (uiop:string-prefix-p "> " line)) (flush))
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

(defun our-rega (fn)
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:fill-alias fn) (qbe:loadopt fn) (qbe:fill-use fn) (qbe:fill-alias fn) (qbe:coalesce fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:gvn fn) (qbe:fill-cfg fn) (qbe:simplcfg fn)
  (qbe:fill-use fn) (qbe:fill-dom fn) (qbe:gcm fn) (qbe:fill-use fn)
  (qbe:ifconvert fn) (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:amd64-abi fn) (qbe:simpl fn) (qbe:fill-cfg fn) (qbe:fill-use fn)
  (qbe:amd64-isel fn)
  (qbe:materialize-regs fn)
  (qbe:fill-cfg fn) (qbe:be-fill-live fn) (qbe:fill-loop fn) (qbe:fill-cost fn)
  (qbe:spill fn) (qbe:rega fn)
  (qbe:print-fn-to-string fn))

(defun diff-rega (ssa-path)
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (dr-sections (dr-dump ssa-path)))
         (raw 0) (norm 0) (sup 0) (unsup 0) (total 0))
    (setf qbe::*tmp-counter* 0) (qbe::reset-stash)
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (handler-case
          (let ((mine (our-rega fn))
                (ref (or (cdr (assoc (qbe:fn-name fn) golden :test #'string=)) "")))
            (incf sup)
            (when (string= mine ref) (incf raw))
            (when (string= (normalize mine) (normalize ref)) (incf norm))
            (when (and (probe-file "/tmp/rega-verbose")
                       (not (string= (normalize mine) (normalize ref))))
              (format t "~&--- ~a ---~%MINE:~%~a~%GOLD:~%~a~%" (qbe:fn-name fn) mine ref)))
        (error (e) (incf unsup)
          (when (probe-file "/tmp/rega-errors")
            (format t "~&~a: ~a~%" (qbe:fn-name fn) e)))))
    (values raw norm sup unsup total)))

(let ((raw 0) (norm 0) (sup 0) (unsup 0) (tot 0))
  (dolist (p (corpus-files))
    (handler-case
        (multiple-value-bind (r nm s u n) (diff-rega p)
          (incf raw r) (incf norm nm) (incf sup s) (incf unsup u) (incf tot n)
          (when (and (> s 0) (< nm s))
            (format t "~&~a: rega norm ~d/~d supported (~d unsupported)~%"
                    (file-namestring p) nm s u)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== M4 rega (After register allocation) ===~%")
  (format t "  supported: ~d/~d functions~%" sup tot)
  (format t "  raw  (byte-exact):   ~d/~d supported~%" raw sup)
  (format t "  norm (structure):    ~d/~d supported~%" norm sup)
  (sb-ext:exit :code (if (= norm sup) 0 1)))
