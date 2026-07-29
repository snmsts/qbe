;;;; winabi.lisp --- amd64_win oracle: our amd64 Win64 abi1 vs
;;;; `qbe -t amd64_win -dA`'s "> After ABI lowering:" printfn dump.
;;;;
;;;; usage:  ros -Q run -- --script test/winabi.lisp
;;;;
;;;; The twin of test/abi.lisp, pointed at the other ABI.  The point of having
;;;; it early is that `-dA` dumps the state right after the pass being ported,
;;;; so every function of the 77-file corpus is a byte-comparable oracle for
;;;; amd64-winabi.lisp *before* isel/emit exist for this target -- porting
;;;; lower_call or lower_block_return moves a number.
;;;;
;;;; As in the SysV twin: functions whose lowering signals (unimplemented) are
;;;; counted "unsupported" (skipped) rather than as mismatches, `raw` byte-diff
;;;; is offset by QBE's run-global newtmp counter so `norm` (temp suffixes
;;;; canonicalized) is the structural signal, and the whole thing rides on the
;;;; mid-end opts being no-ops for the function.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun win-da-dump (ssa-path)
  (let ((g (merge-pathnames
            (make-pathname :name (pathname-name ssa-path) :type "da")
            (merge-pathnames "test/golden-win-da/"
                             (asdf:system-relative-pathname "qbe-cl" "")))))
    (if (probe-file g)
        (uiop:read-file-string g)
        (multiple-value-bind (out err)
            (uiop:run-program (list *qbe-path* "-t" "amd64_win" "-dA"
                                    "-o" *null-device* (namestring ssa-path))
                              :output :string :error-output :string :ignore-error-status t)
          (declare (ignore out)) err))))

(defun win-da-sections (dump)
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
          ((string= line "> After ABI lowering:") (setf acc '() in t))
          ((uiop:string-prefix-p "> " line) (when in (flush)))
          (in (push line acc))))
      (flush))
    (nreverse result)))

(defun win-normalize (s)
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

(defun our-win-abi (fn)
  ;; Same pre-abi pipeline as the SysV twin (main.c, T.cansel=1), only the abi1
  ;; pass differs.
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:fill-alias fn) (qbe:loadopt fn) (qbe:fill-use fn) (qbe:fill-alias fn) (qbe:coalesce fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:gvn fn) (qbe:fill-cfg fn) (qbe:simplcfg fn)
  (qbe:fill-use fn) (qbe:fill-dom fn) (qbe:gcm fn) (qbe:fill-use fn)
  (qbe:ifconvert fn) (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:amd64-winabi-abi fn)
  (qbe:print-fn-to-string fn))

(defvar *show* (uiop:getenv "SHOW"))

(defun diff-win-abi (ssa-path)
  "(values raw-ok norm-ok supported unsupported total)."
  (let* ((mod (qbe:parse-file ssa-path))
         (golden (win-da-sections (win-da-dump ssa-path)))
         (raw 0) (norm 0) (sup 0) (unsup 0) (total 0))
    (setf qbe::*tmp-counter* 0) (qbe::reset-stash)
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (let ((name (qbe:fn-name fn)))
        (handler-case
            (let ((mine (our-win-abi fn))
                  (ref (or (cdr (assoc name golden :test #'string=)) "")))
              (incf sup)
              (when (string= mine ref) (incf raw))
              (if (string= (win-normalize mine) (win-normalize ref))
                  (incf norm)
                  (when *show*
                    (format t "~&--- ~a:~a MISMATCH~%ours:~%~a~%theirs:~%~a~%"
                            (file-namestring ssa-path) name mine ref))))
          (error (e)
            (incf unsup)
            (when *show*
              (format t "~&--- ~a:~a UNSUPPORTED: ~a~%"
                      (file-namestring ssa-path) name e))))))
    (values raw norm sup unsup total)))

(let ((raw 0) (norm 0) (sup 0) (unsup 0) (tot 0))
  (dolist (p (corpus-files))
    (handler-case
        (multiple-value-bind (r nm s u n) (diff-win-abi p)
          (incf raw r) (incf norm nm) (incf sup s) (incf unsup u) (incf tot n)
          (when (and (> s 0) (< nm s))
            (format t "~&~a: norm ~d/~d supported (~d unsupported)~%"
                    (file-namestring p) nm s u)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== amd64 winabi (vs qbe -t amd64_win -dA) ===~%")
  (format t "  supported (lowering did not signal): ~d/~d functions~%" sup tot)
  (format t "  raw  (byte-exact):   ~d/~d supported~%" raw sup)
  (format t "  norm (structure):    ~d/~d supported~%" norm sup)
  (format t "  norm of all:         ~d/~d functions~%" norm tot)
  (sb-ext:exit :code (if (= norm tot) 0 1)))
