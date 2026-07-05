;;;; mem.lisp --- memory optimization (M2 / A4), mirrors mem.c
;;;;
;;;; promote: mem2reg for uniform stack slots.  For each alloc in the start
;;;; block whose slot temp is only ever loaded/stored at one consistent
;;;; size+class, drop the alloc (-> nop), turn each store into a copy that
;;;; *defines* the slot temp, and each load into a copy/cast/ext that reads
;;;; it.  The slot temp then has multiple defs, which the following ssa()
;;;; pass turns into phis.
;;;;
;;;; Oracle: `qbe -dM`'s "> After slot promotion:" printfn dump.  Requires
;;;; fill-use; QBE re-runs filluse before ssa (the new defs must be seen).

(in-package #:qbe)

(defun op-isload (op)  (member op '(:loadsb :loadub :loadsh :loaduh :loadsw :loaduw :load)))
(defun op-isstore (op) (member op '(:storeb :storeh :storew :storel :stores :stored)))
(defun op-isalloc (op) (member op '(:alloc4 :alloc8 :alloc16)))

(defun kbase (k) (if (member k '(:w :l)) 0 1))

(defun load-size (i)
  (case (ins-op i)
    ((:loadsb :loadub) 1)
    ((:loadsh :loaduh) 2)
    ((:loadsw :loaduw) 4)
    (:load (if (member (ins-cls i) '(:l :d)) 8 4))))

(defun store-size (op)
  (ecase op (:storeb 1) (:storeh 2) ((:storew :stores) 4) ((:storel :stored) 8)))

(defun store-cls (op)
  "Value-operand class of a store (optab[op].argcls[0][0])."
  (ecase op ((:storeb :storeh :storew) :w) (:storel :l) (:stores :s) (:stored :d)))

(defun load->ext (op)
  (ecase op
    (:loadsb :extsb) (:loadub :extub)
    (:loadsh :extsh) (:loaduh :extuh)
    (:loadsw :extsw) (:loaduw :extuw)))

(defun promote (fn)
  (let ((tmps (fn-tmp fn)))
    (dolist (i (blk-ins (fn-start fn)))
      (when (op-isalloc (ins-op i))
        (let* ((to (ins-to i)) (tm (aref tmps (tmp-id to))))
          (block skip
            (when (/= (tmp-ndef tm) 1) (return-from skip))
            ;; Verify every use is a load/store of the whole slot at a single
            ;; consistent size (and, for stores, a single value class).
            (let ((s nil) (k nil))
              (dolist (u (tmp-use tm))
                (unless (eq (use-rec-type u) :ins) (return-from skip))
                (let ((l (use-rec-payload u)))
                  (cond
                    ((op-isload (ins-op l))
                     (let ((sz (load-size l)))
                       (if (or (null s) (= s sz)) (setf s sz) (return-from skip))))
                    ((op-isstore (ins-op l))
                     (let ((sz (store-size (ins-op l))) (kc (store-cls (ins-op l))))
                       (if (and (eq (ins-arg1 l) to) (not (eq (ins-arg0 l) to))
                                (or (null s) (= s sz))
                                (or (null k) (eq k kc)))
                           (setf s sz k kc)
                           (return-from skip))))
                    (t (return-from skip)))))
              ;; Commit: drop the alloc and rewrite the uses.
              (setf (ins-op i) :nop (ins-cls i) :w (ins-to i) nil
                    (ins-arg0 i) nil (ins-arg1 i) nil)
              (decf (tmp-ndef tm))
              (dolist (u (tmp-use tm))
                (let ((l (use-rec-payload u)))
                  (if (op-isstore (ins-op l))
                      ;; store val, slot  =>  slot =k copy val
                      (progn
                        (setf (ins-cls l) k (ins-op l) :copy
                              (ins-to l) (ins-arg1 l) (ins-arg1 l) nil)
                        (decf (tmp-nuse tm)) (incf (tmp-ndef tm)))
                      ;; load  =>  copy / cast / ext, so a later pass can fold it
                      (let ((op (ins-op l)))
                        (when (null k)
                          (error "qbe: slot %~a is read but never stored to" (tmp-name tm)))
                        (flet ((cast-or-copy ()
                                 (setf (ins-op l)
                                       (if (/= (kbase k) (kbase (ins-cls l))) :cast :copy))))
                          (case op
                            ((:loadsw :loaduw) (if (eq k :l)
                                                   (setf (ins-op l) (load->ext op))
                                                   (cast-or-copy)))
                            (:load (cast-or-copy))
                            (t (setf (ins-op l) (load->ext op))))))))))))))))
