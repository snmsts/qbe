;;;; rv64-corpus-e2e.lisp --- run QBE's own test/*.ssa programs end to end
;;;; through the rv64 backend, inside a linux/riscv64 container.
;;;;
;;;; Unlike linux/arm64 (native on Apple Silicon), linux/riscv64 runs through
;;;; qemu user emulation -- slower, but the same single-container scheme keeps
;;;; the overhead at one startup: every program is emitted and staged into one
;;;; work directory together with its C driver and expected output, and a
;;;; single `runner.sh` installs the toolchain (riscv64/alpine:edge has none),
;;;; builds, runs (as `prog a b c`, like upstream tools/test.sh) and checks
;;;; all of them inside one container.
;;;;
;;;; Each corpus file embeds a C driver (# >>> driver ... # <<<) and/or
;;;; expected stdout (# >>> output ... # <<<).  A driver-less file with an
;;;; output block carries its own main and links alone; a trailing `#` on an
;;;; output line protects significant trailing whitespace (tools/test.sh).
;;;;
;;;; usage:  ros -Q run -- --script test/rv64-corpus-e2e.lisp
;;;;         DOCKER_IMAGE=riscv64/alpine:edge to override the image.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

(defparameter *image* (or (uiop:getenv "DOCKER_IMAGE") "riscv64/alpine:edge"))

(defun docker-riscv64-p ()
  "Is there a docker daemon that can run linux/riscv64 (qemu binfmt)?"
  (zerop (nth-value 2 (uiop:run-program
                       (list "docker" "run" "--rm" "--platform" "linux/riscv64"
                             *image* "true")
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

(defun skip-target-p (lines)
  "QBE corpus convention: a leading `# skip <targets...>` line lists targets the
program is not expected to run on."
  (let ((first (car lines)))
    (and first (uiop:string-prefix-p "# skip" first)
         (member "rv64" (uiop:split-string first :separator '(#\Space))
                 :test #'string=))))

(defparameter *work*
  (merge-pathnames (format nil "qbe-rv64-~d/" (random (expt 36 6) (make-random-state t)))
                   (uiop:temporary-directory)))

(defun stage-corpus-file (p names)
  "Emit P for rv64 into *work* with its driver/expect; push its name."
  (let* ((txt (uiop:read-file-string p))
         (lines (uiop:split-string txt :separator '(#\Newline)))
         (driver (extract-block lines "driver"))
         (expect (extract-block lines "output"))
         (name (pathname-name p)))
    (when (skip-target-p lines)
      (incf *skip*) (format t "~&  skip ~a: marked # skip rv64~%" (file-namestring p))
      (return-from stage-corpus-file names))
    (unless (or driver expect) (return-from stage-corpus-file names))
    (handler-case
        (let ((asm (qbe:rv64-emit-module (qbe:parse-file p))))
          (with-open-file (s (merge-pathnames (format nil "~a.s" name) *work*)
                             :direction :output :if-exists :supersede)
            (write-string asm s))
          (when driver
            (with-open-file (s (merge-pathnames (format nil "~a.c" name) *work*)
                               :direction :output :if-exists :supersede)
              (write-string driver s)))
          (when expect
            (with-open-file (s (merge-pathnames (format nil "~a.expect" name) *work*)
                               :direction :output :if-exists :supersede)
              (write-string expect s)))
          (cons name names))
      (error (e)
        (incf *skip*)
        (format t "~&  skip ~a: ~a~%" (file-namestring p)
                (subseq (princ-to-string e) 0 (min 70 (length (princ-to-string e)))))
        names))))

(defparameter *runner* "#!/bin/sh
# built and run inside the linux/riscv64 container; one verdict line per test
cd /w
apk add --quiet gcc musl-dev 2>/dev/null
for s in *.s; do
  n=${s%.s}
  if [ -f $n.c ]; then src=\"$n.s $n.c\"; else src=$n.s; fi
  if ! cc $src -o $n.bin -lpthread -lm 2>$n.ccerr; then
    echo \"FAIL $n: link: $(head -c 120 $n.ccerr | tr '\\n' ' ')\"
    continue
  fi
  ./$n.bin a b c >$n.got 2>/dev/null
  code=$?
  if [ -f $n.expect ]; then
    if diff -q $n.got $n.expect >/dev/null 2>&1; then echo \"ok $n\"
    else echo \"FAIL $n: output mismatch\"; fi
  else
    if [ $code -eq 0 ]; then echo \"ok $n\"
    else echo \"FAIL $n: exit $code\"; fi
  fi
done
")

(unless (docker-riscv64-p)
  (format t "~&=== rv64 corpus e2e: no docker/linux-riscv64; skipping ===~%")
  (sb-ext:exit :code 0))

(ensure-directories-exist *work*)
(let ((names '()))
  (dolist (p (corpus-files)) (setf names (stage-corpus-file p names)))
  (with-open-file (s (merge-pathnames "runner.sh" *work*)
                     :direction :output :if-exists :supersede)
    (write-string *runner* s))
  (let ((out (uiop:run-program
              (list "docker" "run" "--rm" "--platform" "linux/riscv64"
                    "-v" (format nil "~a:/w" (namestring *work*))
                    *image* "sh" "/w/runner.sh")
              :output :string :error-output :string :ignore-error-status t)))
    (dolist (l (uiop:split-string out :separator '(#\Newline)))
      (cond ((uiop:string-prefix-p "ok " l)
             (incf *pass*) (format t "~&  ok   ~a.ssa~%" (subseq l 3)))
            ((uiop:string-prefix-p "FAIL " l)
             (incf *fail*) (format t "~&  ~a~%" l))))))
(uiop:delete-directory-tree *work* :validate t :if-does-not-exist :ignore)

(format t "~&=== rv64 corpus e2e (linux/riscv64 container, qemu) ===~%  ~d passed, ~d failed, ~d skipped~%"
        *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
