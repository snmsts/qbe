;;;; amd64-apple-corpus-e2e.lisp --- run QBE's own test/*.ssa programs end to
;;;; end through the amd64_apple backend, under Rosetta 2 on Apple Silicon
;;;; (or natively on an Intel Mac).
;;;;
;;;; Each corpus file embeds a C driver (# >>> driver ... # <<<) and optionally
;;;; expected stdout (# >>> output ... # <<<).  We emit the whole module to
;;;; amd64_apple asm via be-emit-module, assemble+link with the driver via
;;;; `cc -arch x86_64`, run it (macOS execs the x86_64 slice through Rosetta
;;;; transparently), and check the exit code / stdout.
;;;;
;;;; usage:  ros -Q run -- --script test/amd64-apple-corpus-e2e.lisp
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

;;; A host that cannot run x86_64 Mach-O at all (no Rosetta) self-skips.
(defun host-runs-x86-64-p ()
  (zerop (nth-value 2 (uiop:run-program '("arch" "-x86_64" "/usr/bin/true")
                                        :ignore-error-status t))))

(defun extract-block (lines start-tag)
  "Uncommented body of the `# >>> START-TAG ... # <<<` block, or NIL."
  (let ((in nil) (acc '()))
    (dolist (l lines)
      (let ((s (string-left-trim '(#\Space #\Tab) l)))
        (cond
          ((and (not in) (or (string= s (format nil "# >>> ~a" start-tag))
                             (string= s (format nil "#>>> ~a" start-tag))))
           (setf in t))
          ((and in (or (string= s "# <<<") (string= s "#<<<"))) (return))
          (in
           (let ((body (cond ((uiop:string-prefix-p "# " s) (subseq s 2))
                             ((uiop:string-prefix-p "#" s) (subseq s 1))
                             (t s))))
             ;; upstream tools/test.sh: `sed -e 's/#$//'` -- a trailing `#`
             ;; protects significant trailing whitespace (mandel.ssa).
             (when (uiop:string-suffix-p body "#")
               (setf body (subseq body 0 (1- (length body)))))
             (unless (uiop:string-prefix-p ">>> " body)
               (push body acc)))))))
    (when in (format nil "~{~A~%~}" (nreverse acc)))))

(defun build-run (asm driver)
  "cc -arch x86_64 ASM (+ DRIVER when the file has one -- a program whose main
lives in the .ssa itself, like tls.ssa, links alone); return (values exit-code
stdout)."
  (let ((sf (uiop:tmpize-pathname #p"/tmp/aapl-ce2e.s"))
        (cf (uiop:tmpize-pathname #p"/tmp/aapl-ce2e.c"))
        (exe (uiop:tmpize-pathname #p"/tmp/aapl-ce2e.out")))
    (with-open-file (s sf :direction :output :if-exists :supersede) (write-string asm s))
    (when driver
      (with-open-file (s cf :direction :output :if-exists :supersede) (write-string driver s)))
    (multiple-value-bind (o e code)
        (uiop:run-program (append (list "cc" "-arch" "x86_64" (namestring sf))
                                  (when driver (list (namestring cf)))
                                  (list "-o" (namestring exe) "-lpthread" "-lm"))
                          :output :string :error-output :string :ignore-error-status t)
      (declare (ignore o))
      (unless (zerop code) (error "link failed: ~a" (subseq e 0 (min 200 (length e))))))
    (multiple-value-bind (out err code)
        ;; upstream tools/test.sh runs every program as `$exe a b c`
        (uiop:run-program (list (namestring exe) "a" "b" "c")
                          :output :string :error-output :string
                          :ignore-error-status t)
      (declare (ignore err))
      (values code out))))

(defun skip-target-p (lines)
  "QBE corpus convention: a leading `# skip <targets...>` line lists targets the
program is not expected to run on."
  (let ((first (car lines)))
    (and first (uiop:string-prefix-p "# skip" first)
         (member "amd64_apple" (uiop:split-string first :separator '(#\Space))
                 :test #'string=))))

(defun run-corpus-file (p)
  (let* ((txt (uiop:read-file-string p))
         (lines (uiop:split-string txt :separator '(#\Newline)))
         (driver (extract-block lines "driver")))
    (when (skip-target-p lines)
      (incf *skip*) (format t "~&  skip ~a: marked # skip amd64_apple~%" (file-namestring p))
      (return-from run-corpus-file :skip))
    (let ((expect-out (extract-block lines "output")))
      ;; No driver and no expected output = a pure compile fixture; nothing to
      ;; run.  A driver-less file WITH an output block carries its own main.
      (unless (or driver expect-out) (return-from run-corpus-file :nodriver))
      (handler-case
          (let ((asm (qbe:be-emit-module (qbe:parse-file p) qbe:*amd64-apple-target*)))
            (multiple-value-bind (code out) (build-run asm driver)
              (cond
                (expect-out
                 (if (string= (string-right-trim '(#\Newline) out)
                              (string-right-trim '(#\Newline) expect-out))
                     (progn (incf *pass*) (format t "~&  ok   ~a~%" (file-namestring p)))
                     (progn (incf *fail*)
                            (format t "~&  FAIL ~a: output mismatch~%" (file-namestring p)))))
                (t
                 (if (zerop code)
                     (progn (incf *pass*) (format t "~&  ok   ~a~%" (file-namestring p)))
                     (progn (incf *fail*)
                            (format t "~&  FAIL ~a: exit ~a~%" (file-namestring p) code)))))))
        (error (e)
          (incf *skip*)
          (format t "~&  skip ~a: ~a~%" (file-namestring p)
                  (subseq (princ-to-string e) 0 (min 70 (length (princ-to-string e))))))))))

(unless (host-runs-x86-64-p)
  (format t "~&=== amd64_apple corpus e2e: host cannot run x86_64 Mach-O; skipping ===~%")
  (sb-ext:exit :code 0))

(dolist (p (corpus-files)) (run-corpus-file p))
(format t "~&=== amd64_apple corpus e2e (x86_64 Mach-O, Rosetta on arm64 hosts) ===~%  ~d passed, ~d failed, ~d skipped~%"
        *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
