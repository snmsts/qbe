;;;; backend.lisp --- M4 backend infrastructure shared by spill / rega / emit.
;;;;
;;;; QBE keeps machine registers in the SAME temp id space as user temps:
;;;; f->tmp[0 .. Tmp0) are register slots (Tmp0 == NBit == 64), user temps
;;;; start at Tmp0.  live.c / spill.c / rega.c all lean on this (the `t >= Tmp0`
;;;; boundary, `v->t[0] |= rglob`, class masks, hint.r = t<Tmp0?t:-1, ...).
;;;;
;;;; The CL mid-end instead keeps user temps at dense ids from 0 and registers
;;;; as separate `reg` structs, which is what made the byte-exact ssa/gvn/gcm/
;;;; isel pipeline clean.  To port spill/rega faithfully we reconcile the two
;;;; ONLY at backend entry: `materialize-regs` prepends Tmp0 register-slot tmps
;;;; and shifts every user temp id by +Tmp0.  Because instruction operands are
;;;; struct pointers (not ids) and liveness bitsets are rebuilt fresh here, this
;;;; touches nothing upstream: the mid-end oracles stay byte-identical.
;;;;
;;;; After materialization a "temp id" t in [0,Tmp0) denotes a register and
;;;; t >= Tmp0 a user temp; fn-tmp[t] is a tmp struct in both cases (register
;;;; slots carry cls/cost/slot/hint for spill & rega).  Instruction operands to
;;;; registers stay `reg` structs (printer renders them "R<id>"); ref<->id
;;;; conversion bridges the two.
;;;;
;;;; Oracles: filllive vs `qbe -dL` "Liveness analysis" (user-temp in/out/gen +
;;;; nlive counts; dumpts hides register bits); fillcost vs `qbe -dS`
;;;; "Spill costs".

(in-package #:qbe)

;;; ------------------------------------------------------ target register model
;;; amd64 register ids (amd64/all.h): RAX=1 .. RSP=16, XMM0=17 .. XMM15=32.

(defconstant +tmp0+ 64 "NBit: first user-temp id; regs occupy [0,+tmp0+).")

;; +rax+ (=1) and +xmm0+ (=17) come from amd64-abi.lisp; the rest are local.
(defconstant +rcx+ 2) (defconstant +rdx+ 3)
(defconstant +rsi+ 4) (defconstant +rdi+ 5) (defconstant +r8+ 6)
(defconstant +r9+ 7) (defconstant +r10+ 8) (defconstant +r11+ 9)
(defconstant +rbp+ 15) (defconstant +rsp+ 16)
(defconstant +xmm15+ 32)

(defconstant +gpr0+ +rax+)  (defconstant +ngpr+ 16)   ; RAX..RSP
(defconstant +fpr0+ +xmm0+) (defconstant +nfpr+ 15)   ; XMM0..XMM14 (reserve XMM15)
(defconstant +rglob+ (logior (ash 1 +rbp+) (ash 1 +rsp+)))
;; caller-save order (amd64_sysv_rsave): gp then sse; the two counts feed nrsave.
(defparameter *sysv-rsave*
  (coerce (append (list +rdi+ +rsi+ +rdx+ +rcx+ +r8+ +r9+ +r10+ +r11+ +rax+)
                  (loop for i below +nfpr+ collect (+ +xmm0+ i)))
          'vector))
(defparameter *nrsave* (vector 9 +nfpr+))   ; {NGPS_SYSV, NFPS}

(defun reg-fp-p (id) (and (<= +fpr0+ id) (< id (+ +fpr0+ +nfpr+))))
(defun kwide (cls) (and (member cls '(:l :d)) t))   ; KWIDE: Kl/Kd occupy 8 bytes
(defparameter +rsave-mask+
  (reduce (lambda (m id) (logior m (ash 1 id))) *sysv-rsave* :initial-value 0)
  "Bitmask of all caller-save registers (rsave).")

;;; amd64 memargs (ops.h X(NMemArgs,...)): how many operands may be a memory
;;; operand (reloaded straight from a slot rather than forced into a register).
(defparameter *memargs*
  (let ((h (make-hash-table)))
    (dolist (op '(:add :sub :mul :and :or :xor)) (setf (gethash op h) 2))
    (dolist (op '(:neg :sar :shr :shl :swap :xidiv :xdiv :xcmp :xtest))
      (setf (gethash op h) 1))
    h))
(defun memargs (op) (gethash op *memargs* 0))

;;; extra bitset ops used by spill/rega (ssa.lisp has make/copy/zero/union/...).
(defun bs-inter (dst src) (bit-and dst src dst))    ; dst &= src
(defun bs-diff (dst src) (bit-andc2 dst src dst))   ; dst &= ~src
(defun bs-count (bs) (count 1 bs))
(defun bs-regmask (bs)
  "Integer of the register bits [0,+tmp0+) of BS (QBE's bs->t[0])."
  (let ((m 0)) (dotimes (i +tmp0+) (when (bs-has bs i) (setf m (logior m (ash 1 i))))) m))
(defun bs-set-regmask (bs mask) (dotimes (i +tmp0+) (when (logbitp i mask) (bs-set bs i))))
(defun bs-clr-regmask (bs mask) (dotimes (i +tmp0+) (when (logbitp i mask) (bs-clr bs i))))

;;; RCall mask decoders (amd64/sysv.c retregs/argregs).  Each returns
;;; (values reg-id-list ngp nfp) where the counts feed nlive bookkeeping.
(defun sysv-retregs (mask)
  (let ((ni (logand mask 3)) (nf (logand (ash mask -2) 3)) (regs '()))
    (when (>= ni 1) (push +rax+ regs))
    (when (>= ni 2) (push +rdx+ regs))
    (when (>= nf 1) (push +xmm0+ regs))
    (when (>= nf 2) (push (+ +xmm0+ 1) regs))
    (values regs ni nf)))

(defun sysv-argregs (mask)
  (let ((ni (logand (ash mask -4) 15))
        (nf (logand (ash mask -8) 15))
        (ra (logand (ash mask -12) 1))
        (regs '()))
    (dotimes (j ni) (push (aref *sysv-rsave* j) regs))
    (dotimes (j nf) (push (+ +xmm0+ j) regs))
    (when (= ra 1) (push +rax+ regs))
    (values regs (+ ni ra) nf)))

;;; ------------------------------------------------------------ ref <-> temp id
;;; An operand is a user temp (tmp struct), a register (reg struct), or other.

(defun ref-tid (r)
  "Temp id of operand R (register id if a reg, shifted user id if a tmp), or NIL."
  (cond ((tmp-p r) (tmp-id r))
        ((reg-p r) (reg-id r))
        (t nil)))

(defun tid-ref (tid fn)
  "The operand denoting temp id TID: a reg struct for a register, else the tmp."
  (if (< tid +tmp0+) (rg tid) (aref (fn-tmp fn) tid)))

;; RMem addressing mode (isel slice d): an operand may be a `mem` struct whose
;; base and index are the live temps contributing to the address.
(defun mem-ref-p (x) (mem-p x))
(defun mem-ref-base (x) (mem-base x))
(defun mem-ref-index (x) (mem-index x))
(defun (setf mem-ref-base) (v x) (setf (mem-base x) v))
(defun (setf mem-ref-index) (v x) (setf (mem-index x) v))

;;; ----------------------------------------------------------- materialize-regs

(defun materialize-regs (fn)
  "Prepend +tmp0+ register-slot temps and shift user temps to ids >= +tmp0+.
Idempotent guard via fn-regs?.  After this, spill/rega/emit see QBE's layout."
  (unless (fn-regs? fn)
    (let* ((old (fn-tmp fn))
           (nuser (fill-pointer old))
           (n (+ +tmp0+ nuser))
           (new (make-array n :adjustable t :fill-pointer n)))
      (dotimes (i +tmp0+)
        (let ((tm (make-tmp nil i)))
          (setf (tmp-cls tm) (if (reg-fp-p i) :d :l))
          (setf (aref new i) tm)))
      (dotimes (i nuser)
        (let ((tm (aref old i)))
          (setf (tmp-id tm) (+ +tmp0+ i))
          ;; tmp-phi is a union-find PARENT temp id; shift it into the new space
          ;; too (else phicls resolves to register slots — breaks rega hints).
          (when (tmp-phi tm) (incf (tmp-phi tm) +tmp0+))
          (setf (aref new (+ +tmp0+ i)) tm)))
      (setf (fn-tmp fn) new (fn-regs? fn) t))))

;;; ------------------------------------------------------------------ filllive
;;; live.c filllive, post-isel (full): register liveness (rglob / RCall
;;; retregs / argregs / caller-save pressure) plus RMem base/index.

(defun be-bset (r b nlv fn)
  "live.c bset: record use of operand R in block B, bumping the nlive[] count
for its class the first time it enters B's live-in."
  (let ((tid (ref-tid r)))
    (when tid
      (bs-set (blk-gen b) tid)
      (unless (bs-has (blk-in b) tid)
        (incf (aref nlv (cls-base (tmp-cls (aref (fn-tmp fn) tid)))))
        (bs-set (blk-in b) tid)))))

(defun be-arg-bset (r b nlv fn)
  "As be-bset, but an RMem operand contributes its base and index temps."
  (if (mem-ref-p r)
      (progn (be-bset (mem-ref-base r) b nlv fn)
             (be-bset (mem-ref-index r) b nlv fn))
      (be-bset r b nlv fn)))

(defun call-ins-p (i)
  (and (eq (ins-op i) :call) (call-ref-p (ins-arg1 i))))

(defun be-fill-live (fn)
  "Backend liveness (requires materialize-regs + rpo).  Fills blk in/out/gen
bitsets (over the register+temp id space) and blk-nlive (gp/fp pressure).
Distinct from ssa.lisp's pre-isel fill-live (which omits registers)."
  (let ((nt (fn-ntmp fn)))
    (dolist (b (fn-blocks fn))
      (setf (blk-in b) (bs-make nt) (blk-out b) (bs-make nt) (blk-gen b) (bs-make nt)))
    (let ((v (bs-make nt)) (u (bs-make nt)) (chg t) (nlv (make-array 2)) (m (make-array 2)))
      (loop while chg do
        (setf chg nil)
        (loop for n from (1- (fn-nblk fn)) downto 0
              for b = (aref (fn-rpo fn) n) do
          (bs-copy u (blk-out b))
          (when (blk-s1 b) (live-on v b (blk-s1 b)) (bs-union (blk-out b) v))
          (when (blk-s2 b) (live-on v b (blk-s2 b)) (bs-union (blk-out b) v))
          (unless (bs-equal (blk-out b) u) (setf chg t))
          (fill nlv 0)
          (bs-set (blk-out b) +rbp+) (bs-set (blk-out b) +rsp+)   ; |= rglob
          (bs-copy (blk-in b) (blk-out b))
          (dotimes (tid nt)
            (when (bs-has (blk-in b) tid)
              (incf (aref nlv (cls-base (tmp-cls (aref (fn-tmp fn) tid)))))))
          (let ((ja (blk-jmp-arg b)))
            (if (call-ref-p ja)
                (multiple-value-bind (regs ni nf) (sysv-retregs (call-ref-val ja))
                  (dolist (rid regs) (bs-set (blk-in b) rid))
                  (setf (aref nlv 0) ni (aref nlv 1) nf))
                (be-bset ja b nlv fn)))
          (setf (blk-nlive b) (list (aref nlv 0) (aref nlv 1)))
          (dolist (i (reverse (blk-ins b)))
            ;; caller-save pressure across a call (retregs off, argregs on)
            (when (call-ins-p i)
              (multiple-value-bind (rr ni nf) (sysv-retregs (call-ref-val (ins-arg1 i)))
                (dolist (rid rr) (bs-clr (blk-in b) rid))
                (decf (aref nlv 0) ni) (decf (aref nlv 1) nf))
              (dotimes (k 2)
                (incf (aref nlv k) (aref *nrsave* k))
                (when (> (aref nlv k) (nth k (blk-nlive b)))
                  (setf (nth k (blk-nlive b)) (aref nlv k))))
              (multiple-value-bind (ar ni nf) (sysv-argregs (call-ref-val (ins-arg1 i)))
                (setf (aref m 0) ni (aref m 1) nf)
                (dolist (rid ar) (bs-set (blk-in b) rid)))
              (dotimes (k 2)
                (decf (aref nlv k) (aref *nrsave* k))
                (incf (aref nlv k) (aref m k))))
            (let ((to (ins-to i)))
              (let ((tid (ref-tid to)))
                (when tid
                  (when (bs-has (blk-in b) tid)
                    (decf (aref nlv (cls-base (tmp-cls (aref (fn-tmp fn) tid))))))
                  (bs-set (blk-gen b) tid)
                  (bs-clr (blk-in b) tid))))
            (be-arg-bset (ins-arg0 i) b nlv fn)
            (be-arg-bset (ins-arg1 i) b nlv fn)
            (dotimes (k 2)
              (when (> (aref nlv k) (nth k (blk-nlive b)))
                (setf (nth k (blk-nlive b)) (aref nlv k))))))))))

;;; ------------------------------------------------------------------- fillcost
;;; spill.c fillcost: aggregate loop info at headers, then spill costs + usage.

(defun be-tmpuse (r use loop fn)
  "spill.c tmpuse: attribute a use/def of operand R (recursing into RMem)."
  (cond
    ((mem-ref-p r)
     (be-tmpuse (mem-ref-base r) 1 loop fn)
     (be-tmpuse (mem-ref-index r) 1 loop fn))
    ((and (tmp-p r) (>= (tmp-id r) +tmp0+))
     (let ((tm (aref (fn-tmp fn) (tmp-id r))))
       (if (= use 1) (incf (tmp-nuse tm)) (incf (tmp-ndef tm)))
       (incf (tmp-cost tm) loop)))))

(defun fill-cost (fn)
  "Spill costs + usage info (requires rpo, preds, loop weights)."
  ;; aggregate looping info at loop headers into hd->gen / hd->nlive
  (loopiter fn
    (lambda (hd b)
      (bs-union (blk-gen hd) (blk-gen b))
      (dotimes (k 2)
        (when (> (nth k (blk-nlive b)) (nth k (blk-nlive hd)))
          (setf (nth k (blk-nlive hd)) (nth k (blk-nlive b)))))))
  (let ((tmps (fn-tmp fn)))
    (dotimes (t* (fn-ntmp fn))
      (let ((tm (aref tmps t*)))
        (setf (tmp-cost tm) (if (< t* +tmp0+) most-positive-fixnum 0)
              (tmp-nuse tm) 0 (tmp-ndef tm) 0)))
    (dolist (b (fn-blocks fn))
      (dolist (p (blk-phis b))
        (let ((tm (aref tmps (tmp-id (phi-to p)))))
          (be-tmpuse (phi-to p) 0 0 fn)
          (dolist (pa (phi-args p))
            (let ((n (blk-loop (car pa))))
              (incf (tmp-cost tm) n)
              (be-tmpuse (cdr pa) 1 n fn)))))
      (let ((n (blk-loop b)))
        (dolist (i (blk-ins b))
          (be-tmpuse (ins-to i) 0 n fn)
          (be-tmpuse (ins-arg0 i) 1 n fn)
          (be-tmpuse (ins-arg1 i) 1 n fn))
        (be-tmpuse (blk-jmp-arg b) 1 n fn)))))
