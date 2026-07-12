;;;; arm64-encode-corpus.lisp --- G6 as-diff over EVERY corpus function.
;;;; For each function the arm64 backend can encode, compare two ways:
;;;;   (1) aenc-fn                      -> our machine code
;;;;   (2) a64-be-emit-fn -> as -> __text -> Apple `as`'s machine code
;;;; This is the exhaustive complement to the curated test/arm64-encode.lisp.
;;;;
;;;; Two differences are EXPECTED and counted separately (not failures):
;;;;   * ops the encoder doesn't cover yet                 -> skip
;;;;   * a `bl` to a function defined in the SAME object   -> local-call
;;;;     (`as` resolves it to a fixed PC-relative offset, but the encoder emits
;;;;     `bl #0` + a BRANCH26 fixup for the loader/solder to patch; byte-
;;;;     identical after linking).
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-encode-corpus.lisp
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe)

(defun a64ec-text-bytes (fn)
  (reset-stash)
  (uiop:with-temporary-file (:pathname sf :type "s" :keep t)
    (with-open-file (o sf :direction :output :if-exists :supersede) (a64-be-emit-fn fn o))
    (let ((of (concatenate 'string (namestring sf) ".o")))
      (handler-case (uiop:run-program (list "as" (namestring sf) "-o" of))
        (error () (return-from a64ec-text-bytes :as-fail)))
      (let ((out (uiop:run-program (list "otool" "-t" "-X" of) :output :string)) (bs '()))
        (dolist (l (uiop:split-string out :separator '(#\Newline)))
          (dolist (tok (remove "" (uiop:split-string (string-trim " " l) :separator '(#\Space))
                               :test #'string=))
            (when (= (length tok) 8)
              (let ((w (parse-integer tok :radix 16)))
                (dotimes (k 4) (push (ldb (byte 8 (* 8 k)) w) bs))))))
        (coerce (nreverse bs) 'vector)))))

(defun a64ec-diffs-are-branch26 (tb eb fixups)
  "T if every differing word is at a BRANCH26 fixup site (a local `bl` that `as`
resolved but the encoder relocated)."
  (and (= (length tb) (length eb))
       (let ((brs (loop for fx in fixups when (eq (getf fx :kind) :branch26)
                        collect (getf fx :offset))))
         (loop for k below (length tb) by 4
               for tw = (logior (aref tb k) (ash (aref tb (+ k 1)) 8)
                                (ash (aref tb (+ k 2)) 16) (ash (aref tb (+ k 3)) 24))
               for ew = (logior (aref eb k) (ash (aref eb (+ k 1)) 8)
                                (ash (aref eb (+ k 2)) 16) (ash (aref eb (+ k 3)) 24))
               always (or (= tw ew) (member k brs))))))

(let ((pass 0) (localcall 0) (fail 0) (asfail 0) (encerr 0) (fails '()) (errs '()))
  (dolist (p (qbe-test:corpus-files))
    (let ((mod (parse-file p)))
      (let ((*target* *arm64-apple-target*) (*a64-id0* 0))
        (setf *tmp-counter* 0)
        (dolist (fn (module-funcs mod))
          (handler-case
              (progn
                (a64-backend-pipeline fn)
                (multiple-value-bind (eb syms fixups) (aenc-fn fn)
                  (declare (ignore syms))
                  (let ((tb (a64ec-text-bytes fn)))
                    (cond
                      ((eq tb :as-fail) (incf asfail))
                      ((equalp tb eb) (incf pass))
                      ((a64ec-diffs-are-branch26 tb eb fixups) (incf localcall))
                      (t (incf fail) (push (fn-name fn) fails))))))
            ;; aenc-fn itself erroring means the encoder can't handle an op yet.
            (error (c) (declare (ignore c)) (incf encerr) (push (fn-name fn) errs)))))))
  (format t "~&=== G6 arm64 encode-corpus (as-diff) ===~%")
  (format t "  byte-exact:  ~d~%" pass)
  (format t "  local-call:  ~d  (bl to same-object fn -> BRANCH26 fixup; = after link)~%" localcall)
  (format t "  fail:        ~d~@[  ~{~a ~}~]~%" fail fails)
  (format t "  enc-gap:     ~d~@[  ~{~a ~}~]  (aenc-fn errored: op not encoded)~%" encerr errs)
  (format t "  as-fail:     ~d  (`as` can't assemble the per-fn text; oracle N/A, encoder ran)~%" asfail)
  ;; a real regression is a byte mismatch (fail) or a new encoder gap (enc-gap).
  (sb-ext:exit :code (if (and (zerop fail) (zerop encerr)) 0 1)))
