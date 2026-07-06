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

;;; -------------------------------------------------------------- gcm
;;; gcm.c global code motion.  STAGE 3: schedearly/schedlate/gcmmove + schedblk
;;; (intra-block dependency ordering).  `sink` is deferred to stage 4.

(defun isload-op (op)
  (member op '(:loadsb :loadub :loadsh :loaduh :loadsw :loaduw :load)))
(defun isalloc-op (op) (member op '(:alloc4 :alloc8 :alloc16)))
(defun arg-op-p (op) (member op '(:arg :argsb :argub :argsh :arguh :argc :arge :argv)))

(defun canelim (i)
  "gcm.c canelim: pinned ins removable when unused (load/alloc/int-div)."
  (or (isload-op (ins-op i)) (isalloc-op (ins-op i)) (isdivwl i)))

(defun copy-ins (i)
  (make-instance 'ins :op (ins-op i) :cls (ins-cls i) :to (ins-to i)
                 :arg0 (ins-arg0 i) :arg1 (ins-arg1 i)))

;;; --- schedule early: place each value at its earliest legal (deepest) block

(defun schedearly (fn r)
  (if (not (tmp-p r))
      0                                 ; constants/regs available at start
      (let ((tm r))
        (if (/= (tmp-gcmbid tm) -1)
            (tmp-gcmbid tm)
            (let ((b (aref (fn-rpo fn) (tmp-bid tm))))
              (if (tmp-def tm)
                  (progn (setf (tmp-gcmbid tm) 0) ; mark visiting (break cycles)
                         (setf (tmp-gcmbid tm) (earlyins fn b (tmp-def tm))))
                  (setf (tmp-gcmbid tm) (tmp-bid tm))) ; phis do not move
              (tmp-gcmbid tm))))))

(defun earlyins (fn b i)
  (let ((b0 (schedearly fn (ins-arg0 i)))
        (b1 (schedearly fn (ins-arg1 i))))
    (when (< (blk-depth (aref (fn-rpo fn) b0)) (blk-depth (aref (fn-rpo fn) b1)))
      (setf b0 b1))
    (if (pinned-ins i) (blk-id b) b0)))

(defun earlyblk (fn bid)
  (let ((b (aref (fn-rpo fn) bid)))
    (dolist (p (blk-phis b))
      (dolist (pa (phi-args p)) (schedearly fn (cdr pa))))
    (dolist (i (blk-ins b))
      (when (pinned-ins i)
        (schedearly fn (ins-arg0 i)) (schedearly fn (ins-arg1 i))))
    (schedearly fn (blk-jmp-arg b))))

;;; --- schedule late: place each value at the LCA of its uses, then hoist out
;;;     of loops toward the earliest block along the way

(defun lcabid (fn b1 b2)
  (cond ((= b1 -1) b2) ((= b2 -1) b1)
        (t (blk-id (lca (aref (fn-rpo fn) b1) (aref (fn-rpo fn) b2))))))

(defun bestbid (fn earlybid latebid)
  (if (= latebid -1)
      -1
      (let* ((earlyb (aref (fn-rpo fn) earlybid))
             (bestb (aref (fn-rpo fn) latebid))
             (curb bestb))
        (loop until (eq curb earlyb) do
          (setf curb (blk-idom curb))
          (when (< (blk-loop curb) (blk-loop bestb)) (setf bestb curb)))
        (blk-id bestb))))

(defun latephi (fn p r)
  (if (null (phi-args p))
      -1
      (let ((latebid -1))
        (dolist (pa (phi-args p))
          (when (eq (cdr pa) r)
            (setf latebid (lcabid fn latebid (blk-id (car pa))))))
        latebid)))

(defun latejmp (b r)
  (declare (ignore r))
  (if (null (blk-jmp-arg b)) -1 (blk-id b)))

(defun lateins (fn b i r)
  (declare (ignore r))
  (let ((latebid (schedlate fn (ins-to i))))
    (cond ((not (pinned-ins i)) latebid)
          ((and (= latebid -1) (canelim i)) -1)
          (t (blk-id b)))))

(defun schedlate (fn r)
  (if (not (tmp-p r))
      -1
      (let ((tm r))
        (if (tmp-visit tm)
            (tmp-gcmbid tm)
            (progn
              (setf (tmp-visit tm) t)
              (let ((earlybid (tmp-gcmbid tm)))
                (if (= earlybid -1)
                    -1
                    (let ((latebid -1))
                      (setf (tmp-gcmbid tm) (tmp-bid tm))
                      (dolist (u (tmp-use tm))
                        (let* ((b (aref (fn-rpo fn) (use-rec-bid u)))
                               (ulb (ecase (use-rec-type u)
                                      (:phi (latephi fn (use-rec-payload u) r))
                                      (:ins (lateins fn b (use-rec-payload u) r))
                                      (:jmp (latejmp b r)))))
                          (setf latebid (lcabid fn latebid ulb))))
                      (when (and (tmp-def tm) (not (pinned-ins (tmp-def tm))))
                        (setf (tmp-gcmbid tm) (bestbid fn earlybid latebid)))
                      (tmp-gcmbid tm)))))))))

(defun lateblk (fn bid)
  (let ((b (aref (fn-rpo fn) bid)))
    (setf (blk-phis b)
          (remove nil
                  (mapcar (lambda (p)
                            (if (= (schedlate fn (phi-to p)) -1)
                                (progn (setf (phi-args p) nil) nil) ; mark unused + drop
                                p))
                          (blk-phis b))))
    (dolist (i (blk-ins b))
      (when (pinned-ins i) (schedlate fn (ins-to i))))))

;;; --- move instructions to their chosen block (appended at the end), then
;;;     reorder each block into dependency (DFS) order.

(defun gcmmove (fn)
  (let ((vins '()))
    (dotimes (tid (fn-ntmp fn))
      (let ((tm (aref (fn-tmp fn) tid)))
        (when (and (tmp-def tm) (/= (tmp-bid tm) (tmp-gcmbid tm)))
          (let ((i (tmp-def tm)))
            (unless (and (pinned-ins i) (not (canelim i)))
              (when (/= (tmp-gcmbid tm) -1) (push (copy-ins i) vins))
              (setf (ins-op i) :nop (ins-cls i) :w (ins-to i) nil
                    (ins-arg0 i) nil (ins-arg1 i) nil))))))
    ;; addgcmins: append each moved copy to the end of its target block
    (dolist (i (nreverse vins))
      (let ((b (aref (fn-rpo fn) (tmp-gcmbid (ins-to i)))))
        (setf (blk-ins b) (nconc (blk-ins b) (list i)))))))

(defun igroup (vec idx)
  "Index range [i0,i1) of the instruction group at VEC[idx] (util.c igroup)."
  (let* ((n (length vec)) (op (ins-op (aref vec idx))))
    (cond
      ((eq op :blit0) (values idx (+ idx 2)))
      ((eq op :blit1) (values (1- idx) (1+ idx)))
      ((par-op-p op)
       (let ((lo idx) (hi idx))
         (loop while (and (> lo 0) (par-op-p (ins-op (aref vec (1- lo))))) do (decf lo))
         (loop while (and (< hi n) (par-op-p (ins-op (aref vec hi)))) do (incf hi))
         (values lo hi)))
      ((or (eq op :call) (arg-op-p op))
       (let ((lo idx) (hi idx))
         (loop while (and (> lo 0) (arg-op-p (ins-op (aref vec (1- lo))))) do (decf lo))
         (loop while (and (< hi n) (not (eq (ins-op (aref vec hi)) :call))) do (incf hi))
         (values lo (1+ hi))))
      (t (values idx (1+ idx))))))

(defun schedins (fn b vec idx idxmap emit)
  (multiple-value-bind (i0 i1) (igroup vec idx)
    ;; schedule the in-block defs of this group's args first (DFS)
    (loop for k from i0 below i1 for i = (aref vec k) do
      (dotimes (n 2)
        (let ((a (ins-arg i n)))
          (when (tmp-p a)
            (let ((tm a))
              (when (and (= (tmp-bid tm) (blk-id b)) (tmp-def tm))
                (let ((j (gethash (tmp-def tm) idxmap)))
                  (when j (schedins fn b vec j idxmap emit)))))))))
    ;; emit the group (copy + nop original, so re-visits are skipped)
    (loop for k from i0 below i1 for i = (aref vec k) do
      (unless (eq (ins-op i) :nop)
        (funcall emit (copy-ins i))
        (setf (ins-op i) :nop (ins-to i) nil (ins-arg0 i) nil (ins-arg1 i) nil)))
    i1))

(defun schedblk (fn)
  (dolist (b (fn-blocks fn))
    (let* ((vec (coerce (blk-ins b) 'vector))
           (idxmap (make-hash-table :test 'eq))
           (out '()))
      (dotimes (k (length vec)) (setf (gethash (aref vec k) idxmap) k))
      (loop with idx = 0 while (< idx (length vec)) do
        (setf idx (schedins fn b vec idx idxmap (lambda (i) (push i out)))))
      (setf (blk-ins b) (nreverse out)))))

;;; --- sink: duplicate trivial ops to their point of use to cut register
;;;     pressure (gcm.c cheap/sinkref/sink).  A value kept in an early block by
;;;     another use is copied (as a fresh "snk" temp) into a block that uses it
;;;     via a load/store address or a jump arg.

(defun isstore-op (op)
  (member op '(:storeb :storeh :storew :storel :stores :stored)))

(defun cheap (i)
  "gcm.c cheap: an integer-result arithmetic op or comparison."
  (and (= 0 (cls-base (ins-cls i)))
       (or (member (ins-op i) '(:neg :add :sub :mul :and :or :xor :sar :shr :shl))
           (int-cmp-p (ins-op i)) (flt-cmp-p (ins-op i)))))

(defvar *sink-emit* nil "Accumulated sunk copies, in qbe emit-buffer order.")

(defun sinkref (fn b r)
  "gcm.c sinkref: if R is a cheap value defined outside B, return a fresh snk
   copy placed in B (emitting it), else R.  The recursive rewrites of the copy's
   own args are DISCARDED (qbe emits by value), so inner sinks become dead
   copies — replicated faithfully."
  (if (not (tmp-p r))
      r
      (let ((tm r))
        (if (or (null (tmp-def tm)) (= (tmp-bid tm) (blk-id b))
                (pinned-ins (tmp-def tm)) (not (cheap (tmp-def tm))))
            r
            (let ((nr (newtmp "snk" (tmp-cls tm) fn))
                  (copy (copy-ins (tmp-def tm))))
              (setf (tmp-gcmbid nr) (blk-id b) (ins-to copy) nr)
              (push copy *sink-emit*)
              (sinkref fn b (ins-arg0 copy))   ; rewrite discarded, emits inner
              (sinkref fn b (ins-arg1 copy))
              nr)))))

(defun sink (fn)
  (let ((*sink-emit* '()))
    (dolist (b (fn-blocks fn))
      (dolist (i (blk-ins b))
        (cond ((isload-op (ins-op i)) (setf (ins-arg0 i) (sinkref fn b (ins-arg0 i))))
              ((isstore-op (ins-op i)) (setf (ins-arg1 i) (sinkref fn b (ins-arg1 i))))))
      (setf (blk-jmp-arg b) (sinkref fn b (blk-jmp-arg b))))
    ;; addgcmins: distribute the emitted copies to their target blocks, in the
    ;; same order qbe's addgcmins walks its emit buffer (= push order here)
    (dolist (i *sink-emit*)
      (let ((tb (aref (fn-rpo fn) (tmp-gcmbid (ins-to i)))))
        (setf (blk-ins tb) (nconc (blk-ins tb) (list i)))))))

(defun gcm (fn)
  "Global code motion (gcm.c).  Requires fill-cfg, fill-use, fill-dom."
  (fill-depth fn)
  (fill-loop fn)
  (dotimes (tid (fn-ntmp fn))
    (let ((tm (aref (fn-tmp fn) tid)))
      (setf (tmp-visit tm) nil (tmp-gcmbid tm) -1)))
  (dotimes (bid (fn-nblk fn)) (earlyblk fn bid))
  (dotimes (bid (fn-nblk fn)) (lateblk fn bid))
  (gcmmove fn)
  (fill-use fn)
  (sink fn)
  (fill-use fn)
  (schedblk fn))
