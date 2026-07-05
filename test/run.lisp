;;;; run.lisp --- M0 regression / diff runner.
;;;;
;;;; usage:
;;;;   ros -Q run -- --script test/run.lisp                 # corpus vs golden (offline)
;;;;   ros -Q run -- --script test/run.lisp capture         # (re)capture goldens (needs qbe)
;;;;   ros -Q run -- --script test/run.lisp foo.ssa bar.ssa # diff given files vs live qbe
;;;;
;;;; The oracle QBE binary is found via the QBE_BIN env var (see harness.lisp).
;;;; Exit code is 0 iff every compared function matched.
(require :asdf)
(push (truename #p"/home/snmsts/work/qbe/") asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl/test" :verbose nil))

(let* ((args sb-ext:*posix-argv*)
       (capture (member "capture" args :test #'string=))
       (files (remove-if-not (lambda (a) (uiop:string-suffix-p a ".ssa")) args)))
  (when capture (qbe-test:capture-goldens))
  (let ((ok (if files
                (qbe-test:run-corpus :files (mapcar #'pathname files) :verbose t)
                (qbe-test:run-corpus))))
    (sb-ext:exit :code (if ok 0 1))))
