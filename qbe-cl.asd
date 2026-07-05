;;;; qbe-cl.asd --- QBE compiler backend, reimplemented in Common Lisp
;;;;
;;;; M0: IR data model (CLOS) + ops table + IL parser + IL printer.
;;;; Correctness oracle: real QBE `-dP` dump (see test/harness.lisp).

(asdf:defsystem "qbe-cl"
  :description "QBE backend reimplemented in idiomatic Common Lisp (M0: parse+print)."
  :license "MIT"
  :serial t
  :components ((:module "src"
                :serial t
                :components ((:file "packages")
                             (:file "ops")
                             (:file "ir")
                             (:file "parse")
                             (:file "print")))))

(asdf:defsystem "qbe-cl/test"
  :description "M0 diff harness: parse->print vs real QBE -dP."
  :depends-on ("qbe-cl" "uiop")
  :serial t
  :components ((:module "test"
                :components ((:file "harness")))))
