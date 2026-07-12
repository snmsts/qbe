;;;; depth.lisp --- unit test for GCM stage 1: filldepth / fillloop / lca.
;;;;
;;;; No QBE dump exposes dom-tree depth or loop weight, so this checks them
;;;; against hand-computed values on two known CFGs (a simple loop and a nested
;;;; loop).  usage:  ros -Q run -- --script test/depth.lisp

(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system "qbe-cl" :verbose nil))
(in-package #:qbe)

(defvar *fails* 0)

(defun blk-by-name (fn name)
  (find name (fn-blocks fn) :key #'blk-name :test #'string=))

(defun prep (text)
  "Parse the single function in TEXT and run cfg + dom + depth + loop."
  (let ((fn (first (module-funcs (parse-string text)))))
    (fill-cfg fn) (fill-dom fn) (fill-depth fn) (fill-loop fn)
    fn))

(defun check (label got want)
  (if (equal got want)
      (format t "  ok   ~a = ~a~%" label got)
      (progn (incf *fails*)
             (format t "  FAIL ~a = ~a (want ~a)~%" label got want))))

(defun check-depth-loop (fn specs)
  "SPECS: (blkname depth loop) triples."
  (dolist (s specs)
    (destructuring-bind (name depth loop) s
      (let ((b (blk-by-name fn name)))
        (check (format nil "~a.depth" name) (blk-depth b) depth)
        (check (format nil "~a.loop" name) (blk-loop b) loop)))))

;;; --- test 1: simple counted loop --------------------------------------
(let ((fn (prep "function $f1() {
@start
	jmp @loop
@loop
	%i =w phi @start 0, @loop %i1
	%i1 =w add %i, 1
	%c =w csltw %i1, 10
	jnz %c, @loop, @end
@end
	ret
}")))
  (format t "== f1 (simple loop) ==~%")
  (check-depth-loop fn '(("start" 0 1) ("loop" 1 10) ("end" 2 1)))
  (check "lca(loop,end)" (blk-name (lca (blk-by-name fn "loop") (blk-by-name fn "end"))) "loop")
  (check "lca(start,end)" (blk-name (lca (blk-by-name fn "start") (blk-by-name fn "end"))) "start"))

;;; --- test 2: nested loop (exercises depth back-fill + loop multiply) ---
(let ((fn (prep "function $f2() {
@start
	jmp @outer
@outer
	%x =w phi @start 0, @outerend %y
	jmp @inner
@inner
	%y =w add %x, 1
	jnz %y, @inner, @outerend
@outerend
	jnz %y, @outer, @end
@end
	ret
}")))
  (format t "== f2 (nested loop) ==~%")
  (check-depth-loop fn '(("start" 0 1) ("outer" 1 10) ("inner" 2 100)
                         ("outerend" 3 10) ("end" 4 1)))
  (check "lca(inner,end)" (blk-name (lca (blk-by-name fn "inner") (blk-by-name fn "end"))) "inner")
  (check "lca(outer,end)" (blk-name (lca (blk-by-name fn "outer") (blk-by-name fn "end"))) "outer")
  (check "lca(inner,outerend)" (blk-name (lca (blk-by-name fn "inner") (blk-by-name fn "outerend"))) "inner"))

(format t "~%=== depth/loop/lca: ~a ===~%" (if (zerop *fails*) "ALL PASS" (format nil "~d FAIL" *fails*)))
(sb-ext:exit :code (if (zerop *fails*) 0 1))
