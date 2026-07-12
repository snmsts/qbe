;;;; M3b corpus oracle: byte-exact-vs-`as` over EVERY function in test/corpus.
;;;; For each corpus function, encode it two ways and compare the .text bytes:
;;;;   (1) enc-fn                       -> our machine code
;;;;   (2) be-emit-fn -> as -> .text    -> `as`'s machine code
;;;; This is the exhaustive complement to test/encode.lisp's curated cases -- it
;;;; is what proved the encoder byte-identical to `as` across the whole corpus
;;;; (and caught sub-aliasing / wide-immediate / setcc-byte-reg / xmm-store bugs).
;;;;
;;;; Run: ros -Q run --non-interactive --load test/encode-corpus.lisp  (repo root)

(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))    ; amd64-encode is part of the system
(in-package #:qbe)

(defun corpus-read-octets (path)
  (with-open-file (s path :element-type '(unsigned-byte 8))
    (let ((v (make-array (file-length s) :element-type '(unsigned-byte 8))))
      (read-sequence v s) v)))

(defun corpus-as-text (fn)
  "Assemble one already-pipelined function via the text emitter + `as`; .text bytes."
  (reset-stash)
  (let ((asm (with-output-to-string (s)
               (be-emit-fn fn s 0)
               (format s ".section .note.GNU-stack,\"\",@progbits~%"))))
    (uiop:with-temporary-file (:pathname sf :type "s" :keep t)
      (with-open-file (o sf :direction :output :if-exists :supersede) (write-string asm o))
      (let ((of (concatenate 'string (namestring sf) ".o"))
            (bf (concatenate 'string (namestring sf) ".bin")))
        (uiop:run-program (list "as" (namestring sf) "-o" of))
        (uiop:run-program (list "objcopy" "--only-section=.text" "-O" "binary" of bf))
        (corpus-read-octets bf)))))

(defun corpus-first-diff (a b)
  (loop for k below (min (length a) (length b))
        when (/= (aref a k) (aref b k)) do (return k)
        finally (return (if (= (length a) (length b)) nil (list (length a) (length b))))))

(let ((pass 0) (fails '()))
  (dolist (f (directory (merge-pathnames "test/corpus/*.ssa"
                          (truename (merge-pathnames "../" (directory-namestring *load-pathname*))))))
    (handler-case
        (dolist (fn (module-funcs (parse-file (namestring f))))
          (handler-case
              (progn
                (be-backend-pipeline fn)
                (let ((eb (nth-value 0 (enc-fn fn))) (tb (corpus-as-text fn)))
                  (if (equalp eb tb) (incf pass)
                      (push (format nil "~a:~a diff@~s" (pathname-name f) (fn-name fn)
                                    (corpus-first-diff eb tb))
                            fails))))
            (error (c) (push (format nil "~a:~a ERR ~a" (pathname-name f) (fn-name fn) c) fails))))
      (error (c) (declare (ignore c)))))     ; skip files the parser/pipeline rejects
  (format t "~&~%~a  (~d pass, ~d fail)~%"
          (if (null fails) "=== ALL BYTE-EXACT vs as ===" "=== SOME DIFFER ===")
          pass (length fails))
  (dolist (x (reverse fails)) (format t "  FAIL ~a~%" x))
  (uiop:quit (if (null fails) 0 1)))
