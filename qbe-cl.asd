;;;; qbe-cl.asd --- QBE compiler backend, reimplemented in Common Lisp
;;;;
;;;; M0: IR data model (CLOS) + ops table + IL parser + IL printer.
;;;; Correctness oracle: real QBE `-dP` dump (see test/harness.lisp).

(asdf:defsystem "qbe-cl"
  :description "QBE backend reimplemented in idiomatic Common Lisp (M0: parse+print)."
  :license "MIT"
  :depends-on ("uiop")
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "packages")
                             (:file "ops")
                             (:file "ir")
                             (:file "parse")
                             (:file "print")
                             (:file "cfg")
                             (:file "ssa")
                             (:file "mem")
                             (:file "gvn")
                             (:file "gcm")
                             (:file "ifopt")
                             (:file "amd64")
                             (:file "amd64-abi")
                             (:file "driver")))))

(asdf:defsystem "qbe-cl/test"
  :description "M0 diff harness: parse->print vs real QBE -dP."
  :depends-on ("qbe-cl" "uiop")
  :serial t
  :components ((:module "test"
                :components ((:file "harness")))))
