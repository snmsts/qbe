;;;; live.lisp --- M4 backend oracle: our post-isel liveness + spill costs vs
;;;; `qbe -dL` ("Liveness analysis") and `qbe -dS` ("Spill costs").
;;;;
;;;; usage:  ros -Q run -- --script test/live.lisp
;;;;
;;;; Runs the full mid-end + abi1 + isel pipeline (as in isel.lisp), then the
;;;; backend entry sequence (materialize-regs -> fillcfg -> filllive -> fillloop
;;;; -> fillcost) and diffs the -dL / -dS text dumps.  dumpts hides register
;;;; bits, so -dL validates the user-temp in/out/gen sets + the nlive[] counts
;;;; (which DO fold in rglob / retregs / caller-save pressure).  As elsewhere,
;;;; `raw` is offset by QBE's run-global newtmp counter, so `norm` (temp `.N`
;;;; suffixes canonicalized) is the structural signal.  Unsupported functions
;;;; (structs/stack-args/varargs/loads) error out in abi/isel and are skipped.
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defun golden-of (ssa-path ext subdir)
  (uiop:read-file-string
   (merge-pathnames (make-pathname :name (pathname-name ssa-path) :type ext)
                    (merge-pathnames subdir
                                     (asdf:system-relative-pathname "qbe-cl" "")))))

(defun fn-sections (dump start-marker &optional (end-prefix "> "))
  "Map function-name -> text of the section beginning at START-MARKER (a full
line) up to the next line starting with END-PREFIX (or the next function)."
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
          ((string= line start-marker) (setf acc '() in t))
          ((and in (uiop:string-prefix-p end-prefix line)) (flush))
          (in (push line acc))))
      (flush))
    (nreverse result)))

(defun norm-names (s)
  "Canonicalize `base.N` temp names (bare, no % prefix as dumpts prints them):
each distinct token -> base.<rank>.  Leaves keywords/counts untouched."
  (let ((map (make-hash-table :test 'equal)) (ctr 0)
        (out (make-string-output-stream)) (i 0) (n (length s)))
    (flet ((idch (ch) (or (alphanumericp ch) (char= ch #\_) (char= ch #\.))))
      (loop while (< i n) do
        (let ((c (char s i)))
          (if (or (alpha-char-p c) (char= c #\_))
              (let ((start i))
                (loop while (and (< i n) (idch (char s i))) do (incf i))
                (let* ((tok (subseq s start i)) (dot (position #\. tok :from-end t)))
                  (if (and dot (< (1+ dot) (length tok))
                           (every #'digit-char-p (subseq tok (1+ dot))))
                      (let ((canon (or (gethash tok map) (setf (gethash tok map) (incf ctr)))))
                        (format out "~a.~d" (subseq tok 0 dot) canon))
                      (write-string tok out))))
              (progn (write-char c out) (incf i))))))
    (get-output-stream-string out)))

(defun our-through-live (fn)
  "Mid-end + abi1 + isel (see isel.lisp), then backend entry up to filllive.
Stops before fillcost, whose aggreg mutates gen/nlive (so -dL must be snapshot
here, mirroring QBE which dumps -dL inside filllive)."
  (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:promote fn) (qbe:fill-use fn)
  (qbe:ssa fn) (qbe:fill-use fn)
  (qbe:gvn fn) (qbe:fill-cfg fn) (qbe:simplcfg fn)
  (qbe:fill-use fn) (qbe:fill-dom fn) (qbe:gcm fn) (qbe:fill-use fn)
  (qbe:ifconvert fn) (qbe:fill-cfg fn) (qbe:fill-use fn) (qbe:fill-dom fn)
  (qbe:amd64-abi fn) (qbe:simpl fn) (qbe:fill-cfg fn) (qbe:fill-use fn)
  (qbe:amd64-isel fn)
  (qbe:materialize-regs fn)
  (qbe:fill-cfg fn) (qbe:be-fill-live fn))

(defun dumpts-string (bs fn)
  "dumpts: `[ n1 n2 ]` over user temps (id >= Tmp0) in ascending id order."
  (with-output-to-string (s)
    (write-string "[" s)
    (loop for tid from qbe:+tmp0+ below (qbe:fn-ntmp fn)
          when (qbe::bs-has bs tid)
            do (format s " ~a" (qbe:tmp-name (aref (qbe:fn-tmp fn) tid))))
    (write-string " ]" s)))

(defun our-dl (fn)
  "Reproduce -dL's `> Liveness analysis:` body for FN (block layout order)."
  (with-output-to-string (s)
    (dolist (b (qbe:fn-blocks fn))
      (let ((nl (qbe::blk-nlive b)))
        (format s "~C~10Ain:   ~a~%" #\Tab (qbe:blk-name b) (dumpts-string (qbe:blk-in b) fn))
        (format s "~C          out:  ~a~%" #\Tab (dumpts-string (qbe:blk-out b) fn))
        (format s "~C          gen:  ~a~%" #\Tab (dumpts-string (qbe:blk-gen b) fn))
        (format s "~C          live: ~d ~d~%" #\Tab (first nl) (second nl))))))

(defun our-ds-costs (fn)
  "Reproduce -dS's `> Spill costs:` body for FN (user temps, id order)."
  (with-output-to-string (s)
    (loop for tid from qbe:+tmp0+ below (qbe:fn-ntmp fn)
          for tm = (aref (qbe:fn-tmp fn) tid)
          do (format s "~C~10A ~d~%" #\Tab (qbe:tmp-name tm) (qbe::tmp-cost tm)))))

(defun diff-file (ssa-path)
  "(values dl-raw dl-norm ds-raw ds-norm supported unsupported total)."
  (let* ((mod (qbe:parse-file ssa-path))
         (gdl (fn-sections (golden-of ssa-path "dl" "test/golden-dl/") "> Liveness analysis:"))
         (gds (fn-sections (golden-of ssa-path "ds" "test/golden-ds/") "> Spill costs:"))
         (dlr 0) (dln 0) (dsr 0) (dsn 0) (sup 0) (unsup 0) (total 0))
    (setf qbe::*tmp-counter* 0)
    (dolist (fn (qbe:module-funcs mod))
      (incf total)
      (handler-case
          (progn
            (our-through-live fn)
            (incf sup)
            (let* ((name (qbe:fn-name fn))
                   (rl (or (cdr (assoc name gdl :test #'string=)) ""))
                   (rs (or (cdr (assoc name gds :test #'string=)) ""))
                   (ml (our-dl fn))   ; snapshot -dL before fillcost mutates gen
                   (ms (progn (qbe:fill-loop fn) (qbe:fill-cost fn) (our-ds-costs fn))))
              (when (string= ml rl) (incf dlr))
              (when (string= (norm-names ml) (norm-names rl)) (incf dln))
              (when (string= ms rs) (incf dsr))
              (when (string= (norm-names ms) (norm-names rs)) (incf dsn))
              (when (and (probe-file "/tmp/live-verbose")
                         (not (string= (norm-names ml) (norm-names rl))))
                (format t "~&--- ~a (-dL mismatch) ---~%MINE:~%~a~%GOLD:~%~a~%" name ml rl))))
        (error () (incf unsup))))
    (values dlr dln dsr dsn sup unsup total)))

(let ((dlr 0) (dln 0) (dsr 0) (dsn 0) (sup 0) (unsup 0) (tot 0))
  (dolist (p (corpus-files))
    (handler-case
        (multiple-value-bind (a b c d s u n) (diff-file p)
          (incf dlr a) (incf dln b) (incf dsr c) (incf dsn d)
          (incf sup s) (incf unsup u) (incf tot n)
          (when (and (> s 0) (or (< b s) (< d s)))
            (format t "~&~a: dL norm ~d/~d, dS norm ~d/~d supported~%"
                    (file-namestring p) b s d s)))
      (error (e) (format t "~&~a: ERROR ~a~%" (file-namestring p) e))))
  (format t "~&=== M4 backend: filllive + fillcost ===~%")
  (format t "  supported: ~d/~d functions~%" sup tot)
  (format t "  -dL Liveness  raw ~d/~d  norm ~d/~d~%" dlr sup dln sup)
  (format t "  -dS SpillCost raw ~d/~d  norm ~d/~d~%" dsr sup dsn sup)
  (sb-ext:exit :code (if (and (= dln sup) (= dsn sup)) 0 1)))
