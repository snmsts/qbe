;;;; ifopt.lisp --- if-conversion (M3, amd64 T.cansel=1).
;;;;
;;;; QBE runs ifconvert between gcm and abi1 when the target sets cansel (amd64
;;;; does).  It replaces small if-then[-else] diamonds with `sel` instructions,
;;;; so the pre-abi IR the -dA/-dI oracle dumps already contains sel0/sel1.
;;;; Ports ifopt.c (+ cfg.c ifgraph).

(in-package #:qbe)

(defun ifgraph (ifb)
  "cfg.c ifgraph.  If IFB is a convertible if-then / if-else diamond, return
   (values thenb elseb joinb) where thenb/elseb are the true/false arg sources;
   else NIL.  (thenb==ifb for an if-then whose else falls straight through.)"
  (when (eq (blk-jmp-type ifb) :jnz)
    (let ((s1 (blk-s1 ifb)) (s2 (blk-s2 ifb)) (swap nil))
      (when (> (blk-id s1) (blk-id s2))
        (rotatef s1 s2) (setf swap t))
      (unless (eq s1 s2)
        (when (and (eq (blk-jmp-type s1) :jmp) (= 1 (length (blk-preds s1))))
          ;; `out` mirrors qbe's pthenb/pelseb pointer swap: THEN gets the true
          ;; branch's arg source, ELSE the false branch's.
          (flet ((out (a b j) (if swap (values b a j) (values a b j))))
            (cond
              ((eq (blk-s1 s1) s2)
               (when (= 2 (length (blk-preds s2)))
                 (out s1 ifb s2)))
              ((and (eq (blk-jmp-type s2) :jmp) (= 1 (length (blk-preds s2)))
                    (eq (blk-s1 s1) (blk-s1 s2))
                    (= 2 (length (blk-preds (blk-s1 s1)))))
               (out s1 s2 (blk-s1 s1))))))))))

(defun ok-branch (b)
  "ifopt.c okbranch: <= 2 real ins and none pinned."
  (let ((n 0))
    (dolist (i (blk-ins b) (<= n 2))
      (unless (eq (ins-op i) :dbgloc)
        (when (pinned-ins i) (return nil))
        (unless (eq (ins-op i) :nop) (incf n))))))

(defun ok-join (b)
  "ifopt.c okjoin: <= 2 phis, all integer-class."
  (let ((n 0))
    (dolist (p (blk-phis b) (<= n 2))
      (when (/= 0 (cls-base (phi-cls p))) (return nil))
      (incf n))))

(defun ok-graph (ifb thenb elseb joinb)
  (and (= 2 (length (blk-preds joinb))) (ok-join joinb)
       (or (eq thenb ifb) (ok-branch thenb))
       (or (eq elseb ifb) (ok-branch elseb))))

(defun ifconvert-block (ifb thenb elseb joinb)
  "ifopt.c convert: merge then/else ins into IFB and turn JOINB's phis into
   sel instructions; IFB then jumps straight to JOINB."
  (let ((ins (ins-not-nop (blk-ins ifb))))
    (unless (eq thenb ifb) (setf ins (nconc ins (ins-not-nop (blk-ins thenb)))))
    (unless (eq elseb ifb) (setf ins (nconc ins (ins-not-nop (blk-ins elseb)))))
    (when (blk-phis joinb)
      (setf ins (nconc ins (list (make-instance 'ins :op :sel0 :cls :w
                                                :arg0 (blk-jmp-arg ifb))))))
    (dolist (p (blk-phis joinb))
      (setf ins (nconc ins (list (make-instance 'ins :op :sel1 :cls (phi-cls p)
                                   :to (phi-to p)
                                   :arg0 (cdr (assoc thenb (phi-args p) :test #'eq))
                                   :arg1 (cdr (assoc elseb (phi-args p) :test #'eq)))))))
    (setf (blk-ins ifb) ins
          (blk-jmp-type ifb) :jmp (blk-jmp-arg ifb) nil
          (blk-s1 ifb) joinb (blk-s2 ifb) nil
          (blk-preds joinb) (list ifb)
          (blk-phis joinb) nil)))

(defun ifconvert (fn)
  "Eliminate if-then[-else] graphlets with sel instructions (ifopt.c).
Needs rpo/pred/use; breaks cfg/use (caller re-runs fill-cfg/fill-use)."
  (dolist (ifb (copy-list (fn-blocks fn)))
    (multiple-value-bind (thenb elseb joinb) (ifgraph ifb)
      (when (and joinb (ok-graph ifb thenb elseb joinb))
        (ifconvert-block ifb thenb elseb joinb)))))
