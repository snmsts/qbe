;;;; arm64-elf-corpus-e2e.lisp --- run QBE's own test/*.ssa programs end to end
;;;; through the arm64 (ELF/Linux) backend, inside a linux/arm64 container.
;;;;
;;;; On Apple Silicon `docker run --platform linux/arm64` executes natively (no
;;;; emulation), so this is a fast, faithful Linux AAPCS64 host.  To keep the
;;;; container overhead at one startup instead of ~80, every program is emitted
;;;; and staged into one work directory together with its C driver and expected
;;;; output, and a single `runner.sh` builds, runs (as `prog a b c`, like
;;;; upstream tools/test.sh) and checks all of them inside one container.
;;;;
;;;; Each corpus file embeds a C driver (# >>> driver ... # <<<) and/or
;;;; expected stdout (# >>> output ... # <<<).  A driver-less file with an
;;;; output block carries its own main and links alone; a trailing `#` on an
;;;; output line protects significant trailing whitespace (tools/test.sh).
;;;;
;;;; usage:  ros -Q run -- --script test/arm64-elf-corpus-e2e.lisp
;;;;         DOCKER_IMAGE=gcc:14 to override the toolchain image.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

(defparameter *image* (or (uiop:getenv "DOCKER_IMAGE") "gcc:14"))

(defun docker-arm64-p ()
  "Is there a docker daemon that can run linux/arm64?"
  (zerop (nth-value 2 (uiop:run-program
                       (list "docker" "run" "--rm" "--platform" "linux/arm64"
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
         (member "arm64" (uiop:split-string first :separator '(#\Space))
                 :test #'string=))))

(defparameter *work*
  (merge-pathnames (format nil "qbe-a64elf-~d/" (random (expt 36 6) (make-random-state t)))
                   (uiop:temporary-directory)))

(defun stage-corpus-file (p names)
  "Emit P for arm64 ELF into *work* with its driver/expect; push its name."
  (let* ((txt (uiop:read-file-string p))
         (lines (uiop:split-string txt :separator '(#\Newline)))
         (driver (extract-block lines "driver"))
         (expect (extract-block lines "output"))
         (name (pathname-name p)))
    (when (skip-target-p lines)
      (incf *skip*) (format t "~&  skip ~a: marked # skip arm64~%" (file-namestring p))
      (return-from stage-corpus-file names))
    (unless (or driver expect) (return-from stage-corpus-file names))
    (handler-case
        (let ((asm (qbe:a64-be-emit-module (qbe:parse-file p) qbe:*arm64-elf-target*)))
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
# built and run inside the linux/arm64 container; one line of verdict per test
cd /w
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

(unless (docker-arm64-p)
  (format t "~&=== arm64 ELF corpus e2e: no docker/linux-arm64; skipping ===~%")
  (sb-ext:exit :code 0))

(ensure-directories-exist *work*)
(let ((names '()))
  (dolist (p (corpus-files)) (setf names (stage-corpus-file p names)))
  (with-open-file (s (merge-pathnames "runner.sh" *work*)
                     :direction :output :if-exists :supersede)
    (write-string *runner* s))
  (let ((out (uiop:run-program
              (list "docker" "run" "--rm" "--platform" "linux/arm64"
                    "-v" (format nil "~a:/w" (namestring *work*))
                    *image* "sh" "/w/runner.sh")
              :output :string :error-output :string :ignore-error-status t)))
    (dolist (l (uiop:split-string out :separator '(#\Newline)))
      (cond ((uiop:string-prefix-p "ok " l)
             (incf *pass*) (format t "~&  ok   ~a.ssa~%" (subseq l 3)))
            ((uiop:string-prefix-p "FAIL " l)
             (incf *fail*) (format t "~&  ~a~%" l))))))
(uiop:delete-directory-tree *work* :validate t :if-does-not-exist :ignore)

(format t "~&=== arm64 ELF corpus e2e (linux/arm64 container) ===~%  ~d passed, ~d failed, ~d skipped~%"
        *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
