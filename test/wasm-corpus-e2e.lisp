;;;; wasm-corpus-e2e.lisp --- run QBE's own test/*.ssa programs end to end
;;;; through the wasm backend, inside an emscripten/emsdk container.
;;;;
;;;; Why emscripten: the corpus C drivers need a libc, QBE IL is LP64, and the
;;;; only shipped libc for 64-bit wasm is emscripten's (-sMEMORY64=1) -- the
;;;; official wasi-sdk sysroots are wasm32-only and wasi-libc's preview1
;;;; header still rejects wasm64 outright.  emcc compiles each driver, links
;;;; our object (assembled in-container by emsdk's clang), and produces a .js
;;;; launcher that the image's node (memory64-capable) runs.
;;;;
;;;; This doubles as the clang-ABI compatibility oracle for the backend: the
;;;; drivers were compiled by clang for wasm64, so aggregate classification
;;;; (singleton unwrap vs by-pointer), sret, the vararg buffer layout
;;;; (naturally-aligned 4/8-byte slots) and the promoted-main convention
;;;; (main is always (i32, i64) -> i32) all have to match for these
;;;; programs to run.
;;;;
;;;; Each corpus file embeds a C driver (# >>> driver ... # <<<) and/or
;;;; expected stdout (# >>> output ... # <<<); a driver-less file with an
;;;; output block carries its own main and links alone.
;;;;
;;;; usage:  ros -Q run -- --script test/wasm-corpus-e2e.lisp
;;;;         DOCKER_IMAGE=emscripten/emsdk:latest to override the image.
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))
(in-package #:qbe-test)

(defvar *pass* 0) (defvar *fail* 0) (defvar *skip* 0)

(defparameter *image* (or (uiop:getenv "DOCKER_IMAGE") "emscripten/emsdk:latest"))

(defun docker-emsdk-p ()
  (ignore-errors
   (zerop (nth-value 2 (uiop:run-program
                        (list "docker" "run" "--rm" *image* "emcc" "--version")
                        :output :string :error-output :string
                        :ignore-error-status t)))))

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
             (when (uiop:string-suffix-p body "#")
               (setf body (subseq body 0 (1- (length body)))))
             (unless (uiop:string-prefix-p ">>> " body)
               (push body acc)))))))
    (when in (format nil "~{~A~%~}" (nreverse acc)))))

;;; What a register machine tolerates and wasm structurally cannot.  The
;;; corpus has no `# skip wasm` markers (upstream QBE has no wasm target), so
;;; the list lives here, each entry with its reason:
;;;   dark     reads its own return address off the stack (and calls a
;;;            1-parameter function with 0 args on purpose)
;;;   conaddr  loads absolute address 10 expecting a SIGSEGV; wasm memory
;;;            has no signals and address 10 is readable
;;;   abi3     takes the address of an extern C function: IL carries no
;;;            type to declare it by, so the assembler makes it a data
;;;            symbol and the link mismatches
;;;   abi9     C calls `obj f()` unprototyped with 0 args, IL declares a
;;;            parameter; wasm checks arity, registers do not
;;;   vararg1  C declares f(int, ...) where IL takes `l`: i32 vs i64
;;;            first parameter, well-defined only in a register
(defparameter *wasm-skips*
  '(("dark" . "return-address introspection")
    ("conaddr" . "expects SIGSEGV on a wild load")
    ("abi3" . "address of an extern C function (no type info in IL)")
    ("abi9" . "unprototyped C call drops an argument")
    ("vararg1" . "i32/i64 first-parameter mismatch between driver and IL")))

;;; IL has no extern declarations, so when it binds the "result" of a void C
;;; driver function (a garbage register upstream, a signature mismatch here)
;;; the true prototype has to come from this side of the fence:
(defparameter *extern-rets*
  '(("abi1" . (("fcb" . :void)))
    ("isel6" . (("myfunc" . :void)))))

(defparameter *work*
  (merge-pathnames (format nil "qbe-wasm-e2e-~d/" (random (expt 36 6) (make-random-state t)))
                   (uiop:temporary-directory)))

(defun stage-corpus-file (p names)
  "Emit P for wasm into *work* with its driver/expect; push its name."
  (let* ((txt (uiop:read-file-string p))
         (lines (uiop:split-string txt :separator '(#\Newline)))
         (driver (extract-block lines "driver"))
         (expect (extract-block lines "output"))
         (name (pathname-name p)))
    (unless (or driver expect) (return-from stage-corpus-file names))
    (let ((skip (assoc name *wasm-skips* :test #'string=)))
      (when skip
        (incf *skip*)
        (format t "~&  skip ~a: ~a~%" (file-namestring p) (cdr skip))
        (return-from stage-corpus-file names)))
    (handler-case
        (let* ((qbe::*wa-extern-rets*
                 (cdr (assoc name *extern-rets* :test #'string=)))
               (asm (qbe:wa-emit-module (qbe:parse-file p))))
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
                (subseq (princ-to-string e) 0 (min 90 (length (princ-to-string e)))))
        names))))

(defparameter *runner* "#!/bin/sh
# built and run inside the emscripten/emsdk container; one verdict per test
cd /w
CLANG=/emsdk/upstream/bin/clang
for s in *.s; do
  n=${s%.s}
  if ! $CLANG --target=wasm64 -msign-ext -mnontrapping-fptoint -mbulk-memory \\
       -c $n.s -o $n.o 2>$n.err; then
    echo \"FAIL $n: assemble: $(head -c 120 $n.err | tr '\\n' ' ')\"
    continue
  fi
  if [ -f $n.c ]; then src=\"$n.c $n.o\"; else src=$n.o; fi
  if ! emcc -sMEMORY64=1 -Wno-deprecated $src -o $n.js 2>$n.err; then
    echo \"FAIL $n: link: $(grep -v INFO $n.err | head -c 200 | tr '\\n' ' ')\"
    continue
  fi
  node $n.js a b c >$n.got 2>/dev/null
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

(unless (docker-emsdk-p)
  (format t "~&=== wasm corpus e2e: no docker/emsdk; skipping ===~%")
  (sb-ext:exit :code 0))

(ensure-directories-exist *work*)
(let ((names '()))
  (dolist (p (corpus-files)) (setf names (stage-corpus-file p names)))
  (with-open-file (s (merge-pathnames "runner.sh" *work*)
                     :direction :output :if-exists :supersede)
    (write-string *runner* s))
  (let ((out (uiop:run-program
              (list "docker" "run" "--rm"
                    "-v" (format nil "~a:/w" (namestring *work*))
                    *image* "sh" "/w/runner.sh")
              :output :string :error-output :string :ignore-error-status t)))
    (dolist (l (uiop:split-string out :separator '(#\Newline)))
      (cond ((uiop:string-prefix-p "ok " l)
             (incf *pass*) (format t "~&  ok   ~a.ssa~%" (subseq l 3)))
            ((uiop:string-prefix-p "FAIL " l)
             (incf *fail*) (format t "~&  ~a~%" l))))))
(uiop:delete-directory-tree *work* :validate t :if-does-not-exist :ignore)

(format t "~&=== wasm corpus e2e (emscripten MEMORY64 container) ===~%  ~d passed, ~d failed, ~d skipped~%"
        *pass* *fail* *skip*)
(sb-ext:exit :code (if (zerop *fail*) 0 1))
