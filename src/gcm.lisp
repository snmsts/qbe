;;;; gcm.lisp --- CFG simplification + global code motion (M2/C4).
;;;;
;;;; QBE runs, between GVN and the ABI pass:  gvn -> fillcfg -> simplcfg ->
;;;; filluse -> filldom -> gcm.  This file ports simplcfg (cfg.c) and gcm
;;;; (gcm.c).  Oracles: `qbe -dC` "> After CFG simplification:" for simplcfg,
;;;; `qbe -dG` "> After GCM:" for the whole chain.
;;;;
;;;; STAGE 2 (this slice): simplcfg only.  gcm lands in later stages.

(in-package #:qbe)

;;; ----------------------------------------------------------- simplcfg
;;; cfg.c simplcfg: lower single-pred phis to copies, thread jmp chains through
;;; single-pred targets, and drop a jnz whose two (empty) arms jump identically.

(defstruct (sjmp (:constructor make-sjmp (type arg s1 s2))) type arg s1 s2)

(defun blk-empty-p (b)
  "No phis and only nop/dbgloc instructions (cfg.c simplcfg `empty`)."
  (and (null (blk-phis b))
       (every (lambda (i) (member (ins-op i) '(:nop :dbgloc))) (blk-ins b))))

(defun sjmpeq (a b)
  (and (eq (sjmp-type a) (sjmp-type b)) (eq (sjmp-arg a) (sjmp-arg b))
       (eq (sjmp-s1 a) (sjmp-s1 b)) (eq (sjmp-s2 a) (sjmp-s2 b))))

(defun sjmpnophi (j)
  (and (or (null (sjmp-s1 j)) (null (blk-phis (sjmp-s1 j))))
       (or (null (sjmp-s2 j)) (null (blk-phis (sjmp-s2 j))))))

(defun ins-not-nop (list)
  "Copy LIST dropping nops (mirrors addins skipping Onop)."
  (remove-if (lambda (i) (eq (ins-op i) :nop)) list))

(defun simplcfg (fn)
  ;; 1. blocks with a single predecessor: lower each phi to a copy in the pred
  (dolist (b (fn-blocks fn))
    (when (= 1 (length (blk-preds b)))
      (let ((bb (first (blk-preds b))))
        (dolist (p (blk-phis b))
          (let ((cpy (make-instance 'ins :op :copy :cls (phi-cls p)
                                    :to (phi-to p)
                                    :arg0 (cdr (assoc bb (phi-args p) :test #'eq)))))
            (setf (blk-ins bb) (nconc (blk-ins bb) (list cpy)))))
        (setf (blk-phis b) nil))))
  ;; 2. snapshot each block's jump + emptiness, keyed by rpo id
  (let* ((n (fn-nblk fn))
         (jmp (make-array n))
         (empty (make-array n)))
    (dolist (b (fn-blocks fn))
      (setf (aref jmp (blk-id b))
            (make-sjmp (blk-jmp-type b) (blk-jmp-arg b) (blk-s1 b) (blk-s2 b))
            (aref empty (blk-id b)) (blk-empty-p b)))
    ;; 3. iterate to a fixpoint
    (loop with done = nil until done do
      (setf done t)
      (dolist (b (fn-blocks fn))
        (when (/= (blk-id b) -1)
          (let ((j (aref jmp (blk-id b))))
            (cond
              ;; thread a jmp through a single-pred target: inline it into b
              ((and (eq (sjmp-type j) :jmp) (sjmp-s1 j)
                    (= 1 (length (blk-preds (sjmp-s1 j)))))
               (let* ((s1 (sjmp-s1 j)) (jj (aref jmp (blk-id s1))))
                 (setf (blk-ins b) (nconc (blk-ins b) (ins-not-nop (blk-ins s1))))
                 (setf (aref empty (blk-id b))
                       (and (aref empty (blk-id b)) (aref empty (blk-id s1))))
                 ;; redirect s1's successors' phi args from s1 to b
                 (dolist (bb (remove nil (list (sjmp-s1 jj) (sjmp-s2 jj))))
                   (dolist (p (blk-phis bb))
                     (let ((pair (assoc s1 (phi-args p) :test #'eq)))
                       (when pair (setf (car pair) b)))))
                 (setf (blk-id s1) -1)
                 (setf (aref jmp (blk-id b)) (copy-sjmp jj))
                 (setf done nil)))
              ;; both jnz arms empty and jump identically with no phis: bypass
              ((and (eq (sjmp-type j) :jnz)
                    (aref empty (blk-id (sjmp-s1 j)))
                    (aref empty (blk-id (sjmp-s2 j)))
                    (sjmpeq (aref jmp (blk-id (sjmp-s1 j)))
                            (aref jmp (blk-id (sjmp-s2 j))))
                    (sjmpnophi (aref jmp (blk-id (sjmp-s1 j)))))
               (setf (aref jmp (blk-id b)) (copy-sjmp (aref jmp (blk-id (sjmp-s1 j)))))
               (setf done nil)))))))
    ;; 4. write jumps back into the surviving blocks
    (dolist (b (fn-blocks fn))
      (when (/= (blk-id b) -1)
        (let ((j (aref jmp (blk-id b))))
          (setf (blk-jmp-type b) (sjmp-type j) (blk-jmp-arg b) (sjmp-arg j)
                (blk-s1 b) (sjmp-s1 j) (blk-s2 b) (sjmp-s2 j)))))
    ;; 5. prune dead blocks + rebuild cfg
    (fill-cfg fn)))
