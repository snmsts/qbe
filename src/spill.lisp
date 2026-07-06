;;;; spill.lisp --- M4 spill code insertion (spill.c), post-fillcost.
;;;;
;;;; Restricts register pressure to the target's gp/fp register counts by
;;;; spilling excess temporaries to stack slots: inserts loads/stores, assigns
;;;; slots (packed 4/8-byte), and REPLACES liveness in/out with the set of
;;;; temporaries that must be in registers at block borders (rega consumes it).
;;;;
;;;; Emission mirrors QBE's backward `emit`: pushing onto *emitted* in QBE's
;;;; emit()-call order yields the block's forward instruction list (see abi).
;;;;
;;;; Oracle: `qbe -dS` "> After spilling:" printfn dump.

(in-package #:qbe)

;;; spill-local statics (spill.c file-scope): bound per spill() call.
(defvar *sp-fn*)
(defvar *sp-mask*)      ; #(gp-mask fp-mask), class masks over the id space
(defvar *sp-locs*)      ; stack bytes already used by locals (fn->slot)
(defvar *sp-slot4*)     ; next 4-byte slot
(defvar *sp-slot8*)     ; next 8-byte slot
(defvar *sp-fst*)       ; BSet to prioritise in registers (tcmp1)

(defun emiti (ins) (push ins *emitted*))   ; emit an existing instruction

(defun sp-tmp (tid) (aref (fn-tmp *sp-fn*) tid))

;;; ---------------------------------------------------------------- slot(t)
(defun sp-slot (tid)
  "Assign (or reuse) TID's stack slot, returning an RSlot ref (spill.c slot)."
  (assert (>= tid +tmp0+) () "cannot spill register")
  (let* ((tm (sp-tmp tid)) (s (tmp-slot tm)))
    (when (= s -1)
      (if (kwide (tmp-cls tm))
          (progn
            (setf s *sp-slot8*)
            (when (= *sp-slot4* *sp-slot8*) (incf *sp-slot4* 2))
            (incf *sp-slot8* 2))
          (progn
            (setf s *sp-slot4*)
            (if (= *sp-slot4* *sp-slot8*)
                (progn (incf *sp-slot8* 2) (incf *sp-slot4* 1))
                (setf *sp-slot4* *sp-slot8*))))
      (incf s *sp-locs*)
      (setf (tmp-slot tm) s))
    (make-slot-ref s)))

;;; --------------------------------------------------------------- tcmp / limit
(defun tcmp0-lt (a b)
  "spill.c tcmp0: order by cost DESCENDING (higher-cost kept in registers)."
  (> (tmp-cost (sp-tmp a)) (tmp-cost (sp-tmp b))))

(defun tcmp1-lt (a b)
  "spill.c tcmp1: members of *sp-fst* first, then by tcmp0."
  (let ((ha (if (bs-has *sp-fst* a) 1 0)) (hb (if (bs-has *sp-fst* b) 1 0)))
    (cond ((/= ha hb) (> ha hb))
          (t (tcmp0-lt a b)))))

(defun sp-limit (bs k f)
  "Restrict BS to at most K temps, preferring those in F then highest cost;
spill the rest (spill.c limit)."
  (let ((nt (bs-count bs)))
    (when (<= nt k) (return-from sp-limit))
    (let ((tarr (make-array nt)) (i 0))
      (dotimes (tid (fn-ntmp *sp-fn*))
        (when (bs-has bs tid) (bs-clr bs tid) (setf (aref tarr i) tid) (incf i)))
      (when (> nt 1)
        (if (null f)
            (setf tarr (stable-sort tarr #'tcmp0-lt))
            (progn (setf *sp-fst* f) (setf tarr (stable-sort tarr #'tcmp1-lt)))))
      (loop for j from 0 below (min k nt) do (bs-set bs (aref tarr j)))
      (loop for j from (min k nt) below nt do (sp-slot (aref tarr j))))))

(defun sp-limit2 (b1 k1 k2 f)
  "spill.c limit2: split B1 by class, limit gp to ngpr-k1 and fp to nfpr-k2."
  (let ((b2 (bs-copy-new b1)))
    (bs-inter b1 (aref *sp-mask* 0))
    (bs-inter b2 (aref *sp-mask* 1))
    (sp-limit b1 (- +ngpr+ k1) f)
    (sp-limit b2 (- +nfpr+ k2) f)
    (bs-union b1 b2)))

;;; ------------------------------------------------------- hints / reloads / store
(defun sp-sethint (u r)
  "OR register-mask R into hint.m of every temp's phi-class rep in U (spill.c)."
  (loop for tid from +tmp0+ below (fn-ntmp *sp-fn*)
        when (bs-has u tid)
        do (let ((pc (phicls tid (fn-tmp *sp-fn*))))
             (setf (tmp-hint-m (sp-tmp pc)) (logior (tmp-hint-m (sp-tmp pc)) r)))))

(defun sp-reloads (u v)
  "Emit a load for each temp in U not in V (reload from its slot)."
  (loop for tid from +tmp0+ below (fn-ntmp *sp-fn*)
        when (and (bs-has u tid) (not (bs-has v tid)))
        do (emit :load (tmp-cls (sp-tmp tid)) (tid-ref tid *sp-fn*) (sp-slot tid) nil)))

(defun sp-store (r s)
  "Emit a store of temp R to slot S (spill.c store; no-op if S=-1)."
  (when (/= s -1)
    (emit (ecase (tmp-cls (sp-tmp (ref-tid r)))
            (:w :storew) (:l :storel) (:s :stores) (:d :stored))
          :w nil r (make-slot-ref s))))

(defun sp-regcpy (i) (and (eq (ins-op i) :copy) (reg-p (ins-arg0 i))))

;;; ----------------------------------------------------------------- merge / dopm
(defun sp-merge (u bu v bv)
  "spill.c merge: at a forward edge, either union V into U (if BU is at least as
loopy as BV) or bring only V's still-unspilled temps."
  (if (<= (blk-loop bu) (blk-loop bv))
      (bs-union u v)
      (dotimes (tid (fn-ntmp *sp-fn*))
        (when (and (bs-has v tid) (= (tmp-slot (sp-tmp tid)) -1))
          (bs-set u tid)))))

(defun sp-dopm (vec k v)
  "Handle a run of consecutive register-copies ending at VEC[K] as one unit
(spill.c dopm).  Returns the index of the first copy in the run."
  (let ((u (bs-make (fn-ntmp *sp-fn*))) (i k) (r 0))
    ;; scan the run backward, storing spilled copy results, marking sources live
    (loop
      (let* ((ins (aref vec i)) (to (ins-to ins)) (tid (ref-tid to)))
        (when (and tid (bs-has v tid))
          (bs-clr v tid)
          (sp-store to (tmp-slot (sp-tmp tid))))
        (bs-set v (ref-tid (ins-arg0 ins))))
      (if (and (> i 0) (sp-regcpy (aref vec (1- i)))) (decf i) (return)))
    (bs-copy u v)
    (if (and (> i 0) (eq (ins-op (aref vec (1- i))) :call))
        (let ((mask (call-ref-val (ins-arg1 (aref vec (1- i))))))
          (dolist (rid (sysv-retregs mask)) (bs-clr v rid))
          (sp-limit2 v (aref *nrsave* 0) (aref *nrsave* 1) nil)
          (setf r +rsave-mask+)
          (dolist (rid (sysv-argregs mask)) (bs-set v rid)))
        (progn (sp-limit2 v 0 0 nil) (setf r (bs-regmask v))))
    (sp-sethint v r)
    (sp-reloads u v)
    (loop for j from k downto i do (emiti (aref vec j)))   ; emit copies in order
    i))

;;; --------------------------------------------------------------------- spill
(defun spill (fn)
  "Spill code insertion (requires spill costs, rpo, liveness).  Rewrites blocks
in place and replaces in/out with register-resident sets (spill.c spill)."
  (let* ((*sp-fn* fn) (nt (fn-ntmp fn))
         (*sp-mask* (vector (bs-make nt) (bs-make nt)))
         (*sp-locs* (fn-slot fn)) (*sp-slot4* 0) (*sp-slot8* 0) (*sp-fst* nil)
         (u (bs-make nt)) (v (bs-make nt)) (w (bs-make nt)))
    ;; class masks: reg gp/fp by id range, user temps by KBASE(cls)
    (dotimes (tid nt)
      (let ((k 0))
        (when (and (>= tid +fpr0+) (< tid (+ +fpr0+ +nfpr+))) (setf k 1))
        (when (>= tid +tmp0+) (setf k (cls-base (tmp-cls (aref (fn-tmp fn) tid)))))
        (bs-set (aref *sp-mask* k) tid)))
    (loop for n from (1- (fn-nblk fn)) downto 0
          for b = (aref (fn-rpo fn) n) do
      ;; 1. registers live at the end of b -> v
      (let ((s1 (blk-s1 b)) (s2 (blk-s2 b)) (hd nil))
        (when (and s1 (<= (blk-id s1) (blk-id b))) (setf hd s1))
        (when (and s2 (<= (blk-id s2) (blk-id b)) (or (null hd) (>= (blk-id s2) (blk-id hd))))
          (setf hd s2))
        (cond
          (hd                             ; back-edge into a loop header
           (bs-zero v)
           (bs-set (blk-gen hd) +rbp+) (bs-set (blk-gen hd) +rsp+)   ; don't spill regs
           (dotimes (k 2)
             (let ((count (if (= k 0) +ngpr+ +nfpr+)))
               (bs-copy u (blk-out b)) (bs-inter u (aref *sp-mask* k))
               (bs-copy w u) (bs-inter u (blk-gen hd)) (bs-diff w (blk-gen hd))
               (if (< (bs-count u) count)
                   (let ((j (bs-count w)) (l (nth k (blk-nlive hd))))
                     (sp-limit w (- count (- l j)) nil)
                     (bs-union u w))
                   (sp-limit u count nil))
               (bs-union v u))))
          (s1                             ; forward edge(s)
           (bs-zero v)
           (live-on w b s1) (sp-merge v b w s1)
           (when s2 (live-on u b s2) (sp-merge v b u s2) (bs-inter w u))
           (sp-limit2 v 0 0 w))
          (t                              ; return / no successor
           (bs-copy v (blk-out b))
           (when (call-ref-p (blk-jmp-arg b))
             (dolist (rid (sysv-retregs (call-ref-val (blk-jmp-arg b)))) (bs-set v rid))))))
      ;; jump argument (jnz/switch cond) must be in a register
      (let ((ja (blk-jmp-arg b)))
        (when (tmp-p ja)
          (let ((tid (tmp-id ja)))
            (assert (= (cls-base (tmp-cls (sp-tmp tid))) 0))
            (bs-set v tid)
            (sp-limit2 v 0 0 nil)
            (unless (bs-has v tid) (setf (blk-jmp-arg b) (sp-slot tid))))))
      ;; spill temps live-out but not register-resident
      (loop for tid from +tmp0+ below nt
            when (and (bs-has (blk-out b) tid) (not (bs-has v tid)))
            do (sp-slot tid))
      (bs-copy (blk-out b) v)
      ;; 2. process instructions backward
      (let ((*emitted* nil) (vec (coerce (blk-ins b) 'vector)) (lvarg (make-array 2)))
        (let ((k (length vec)))
          (loop while (> k 0) do
            (decf k)
            (let ((i (aref vec k)))
              (cond
                ((sp-regcpy i) (setf k (sp-dopm vec k v)))
                (t
                 (bs-zero w)
                 (let ((to (ins-to i)))
                   (when to
                     (let ((tid (ref-tid to)))
                       (if (bs-has v tid)
                           (bs-clr v tid)
                           (progn (assert (>= tid +tmp0+))
                                  (bs-set v tid) (bs-set w tid))))))
                 (let ((j (memargs (ins-op i))))
                   (dolist (a (list (ins-arg0 i) (ins-arg1 i)))
                     (when (mem-ref-p a) (decf j)))
                   (loop for slot-k from 0 below 2
                         for a = (if (= slot-k 0) (ins-arg0 i) (ins-arg1 i)) do
                     (cond
                       ((mem-ref-p a)
                        (when (tmp-p (mem-ref-base a))
                          (bs-set v (tmp-id (mem-ref-base a))) (bs-set w (tmp-id (mem-ref-base a))))
                        (when (tmp-p (mem-ref-index a))
                          (bs-set v (tmp-id (mem-ref-index a))) (bs-set w (tmp-id (mem-ref-index a)))))
                       ((or (tmp-p a) (reg-p a))
                        (let ((tid (ref-tid a)))
                          (setf (aref lvarg slot-k) (bs-has v tid))
                          (bs-set v tid)
                          (when (<= (prog1 j (decf j)) 0) (bs-set w tid)))))))
                 (bs-copy u v)
                 (sp-limit2 v 0 0 w)
                 (loop for slot-k from 0 below 2
                       for a = (if (= slot-k 0) (ins-arg0 i) (ins-arg1 i)) do
                   (when (or (tmp-p a) (reg-p a))
                     (let ((tid (ref-tid a)))
                       (unless (bs-has v tid)
                         (unless (aref lvarg slot-k) (bs-clr u tid))
                         (let ((sl (sp-slot tid)))
                           (if (= slot-k 0) (setf (ins-arg0 i) sl) (setf (ins-arg1 i) sl)))))))
                 (sp-reloads u v)
                 (let ((to (ins-to i)))
                   (when to
                     (let ((tid (ref-tid to)))
                       (sp-store to (tmp-slot (sp-tmp tid)))
                       (when (>= tid +tmp0+) (bs-clr v tid)))))
                 (emiti i)
                 (let ((r (bs-regmask v))) (unless (zerop r) (sp-sethint v r))))))))
        ;; invariant: only rglob (+ params at start) remain in registers
        (if (eq b (fn-start fn))
            (assert (= (bs-regmask v) (logior +rglob+ (fn-reg fn))))
            (assert (= (bs-regmask v) +rglob+)))
        ;; phis: store if register-resident, else demote live phi to a slot
        (dolist (p (blk-phis b))
          (let ((tid (tmp-id (phi-to p))))
            (cond ((bs-has v tid) (bs-clr v tid) (sp-store (phi-to p) (tmp-slot (sp-tmp tid))))
                  ((bs-has (blk-in b) tid) (setf (phi-to p) (sp-slot tid))))))
        (bs-copy (blk-in b) v)
        (setf (blk-ins b) *emitted*)))
    ;; align locals to 16 bytes (NAlign==3)
    (incf *sp-slot8* (logand *sp-slot8* 3))
    (incf (fn-slot fn) *sp-slot8*)))
