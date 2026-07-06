;;;; cfg.lisp --- control-flow analysis (mirrors cfg.c)
;;;;
;;;; fill-rpo   : DFS post-order -> reverse-postorder ids; prunes unreachable
;;;; fill-preds : predecessor lists
;;;; fill-dom   : immediate dominators (Cooper-Harvey-Kennedy) + dom-tree kids
;;;; fill-fron  : dominance frontier
;;;;
;;;; These are pure data->data annotations on the IR.  The dominator tree is
;;;; oracle-checked against `qbe -dN`'s "> Dominators:" dump (test/dom.lisp).

(in-package #:qbe)

(defun fill-rpo (fn)
  "Number reachable blocks in reverse-postorder, build FN's rpo vector, and
drop unreachable blocks from the layout list."
  (let ((visited (make-hash-table :test 'eq)) (po 0))
    (labels ((rec (b)
               (when (and b (not (gethash b visited)))
                 (setf (gethash b visited) t)
                 ;; s1 before s2 (loop-ordering swap only matters post-fillloop,
                 ;; which does not run before ssa; loop=0 here => no swap).
                 (rec (blk-s1 b))
                 (rec (blk-s2 b))
                 (setf (blk-id b) po)          ; postorder number, fixed up below
                 (incf po))))
      (rec (fn-start fn)))
    (let ((rpo (make-array po)))
      (setf (fn-blocks fn) (remove-if-not (lambda (b) (gethash b visited)) (fn-blocks fn)))
      (dolist (b (fn-blocks fn))
        (setf (blk-id b) (- po (blk-id b) 1))
        (setf (aref rpo (blk-id b)) b))
      (setf (fn-rpo fn) rpo (fn-nblk fn) po)
      ;; relink the layout chain to the surviving blocks (QBE's fillrpo rebuilds
      ;; ->link); the printer reads blk-link for jmp fall-through elision.
      (loop for (b . rest) on (fn-blocks fn) do (setf (blk-link b) (car rest))))))

(defun fill-preds (fn)
  (dolist (b (fn-blocks fn)) (setf (blk-preds b) nil))
  (dolist (b (fn-blocks fn))
    (when (blk-s1 b) (push b (blk-preds (blk-s1 b))))
    (when (and (blk-s2 b) (not (eq (blk-s2 b) (blk-s1 b))))
      (push b (blk-preds (blk-s2 b)))))
  ;; QBE appends preds in block-link order; undo the push reversal.
  (dolist (b (fn-blocks fn)) (setf (blk-preds b) (nreverse (blk-preds b)))))

(defun fill-cfg (fn)
  (fill-rpo fn)
  (fill-preds fn))

;;; ---------------------------------------------------------- dominators

(defun cfg-inter (b1 b2)
  "Nearest common dominator of B1,B2 walking up by rpo id (Cooper et al.)."
  (cond
    ((null b1) b2)
    (t (loop until (eq b1 b2) do
         (when (< (blk-id b1) (blk-id b2)) (rotatef b1 b2))
         (loop while (> (blk-id b1) (blk-id b2)) do (setf b1 (blk-idom b1))))
       b1)))

(defun fill-dom (fn)
  (let ((start (fn-start fn)) (rpo (fn-rpo fn)))
    (dolist (b (fn-blocks fn))
      (setf (blk-idom b) nil (blk-doms b) nil))
    (loop with changed = t while changed do
      (setf changed nil)
      (loop for n from 1 below (fn-nblk fn)
            for b = (aref rpo n) do
        (let ((d nil))
          (dolist (p (blk-preds b))
            (when (or (blk-idom p) (eq p start))
              (setf d (cfg-inter d p))))
          (unless (eq d (blk-idom b))
            (setf changed t (blk-idom b) d)))))
    ;; dom-tree children, in reverse link order (matches QBE's dlink prepend)
    (dolist (b (fn-blocks fn))
      (let ((d (blk-idom b)))
        (when d (push b (blk-doms d)))))))

(defun sdom (b1 b2)
  "Does B1 strictly dominate B2?"
  (and (not (eq b1 b2))
       (progn (loop while (> (blk-id b2) (blk-id b1)) do (setf b2 (blk-idom b2)))
              (eq b1 b2))))

(defun dom (b1 b2)
  (or (eq b1 b2) (sdom b1 b2)))

;;; ---------------------------------------------------------- frontier

(defun add-fron (a b)
  (unless (member b (blk-fron a) :test #'eq)
    (setf (blk-fron a) (nconc (blk-fron a) (list b)))))

(defun fill-fron (fn)
  (dolist (b (fn-blocks fn)) (setf (blk-fron b) nil))
  (dolist (b (fn-blocks fn))
    (when (blk-s1 b)
      (loop for a = b then (blk-idom a) until (sdom a (blk-s1 b))
            do (add-fron a (blk-s1 b))))
    (when (blk-s2 b)
      (loop for a = b then (blk-idom a) until (sdom a (blk-s2 b))
            do (add-fron a (blk-s2 b))))))
