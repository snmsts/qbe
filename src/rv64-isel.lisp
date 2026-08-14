;;;; rv64-isel.lisp --- rv64 instruction selection, mirrors rv64/isel.c.
;;;;
;;;; Verified against `qbe -t rv64 -dI` ("> After instruction selection:").
;;;; The smallest of the isels: no address matching and no compare/branch
;;;; fusion (upstream TODO) -- just fixarg (12-bit immediates, fp-pool loads,
;;;; fast-local slots), selcmp (seqz/snez + slt/sltu with operand swap/negate),
;;;; and the shared fast-alloc slot assignment.
;;;;
;;;; As elsewhere QBE emits backward; `emit`/`emiti` push onto *emitted*.

(in-package #:qbe)

;;; rv64/all.h Rv64Op.imm (the V() column of ops.h): ops whose second operand
;;; may be a 12-bit signed immediate.
(defparameter *rv64-imm-ops*
  '(:add :and :or :xor :sar :shr :shl :csltw :cultw :csltl :cultl))

(defun rv-immarg-op-p (op) (and (member op *rv64-imm-ops*) t))

(defun rv-memarg-p (argn op)
  "rv64/isel.c memarg: may arg ARGN of OP stay a memory reference?"
  (cond
    ((or (isload-op op) (eq op :call)) (= argn 0))
    ((isstore-op op) (= argn 1))
    (t nil)))

;;; ------------------------------------------------------------------ fixarg

(defun rv-fixarg (r k argn i fn)
  "rv64/isel.c fixarg: rewrite operand R (arg ARGN of ins I, or a phi/jump arg
when I is NIL) at class K so the emitter can encode it.  Returns the operand."
  (when (eq k :m) (setf k :l))                     ; Km is #defined to Kl
  (let ((op (if i (ins-op i) :copy)))
    (cond
      ((con-p r)
       (cond
         ((and (eq (con-kind r) :addr) (rv-memarg-p argn op)) r)
         ((and (= (cls-base k) 0) (eq (con-kind r) :bits)
               (rv-immarg-op-p op) (= argn 1)
               (<= -2048 (con-rawbits r) 2047))
          r)
         ((= (cls-base k) 1)
          ;; load floating points from memory slots, they can't be immediates
          (assert (eq (con-kind r) :bits))
          (let* ((n (stashbits (con-rawbits r) (if (kwide k) 8 4)))
                 (r1 (newtmp "isel" k fn))
                 (cc (make-con :kind :addr
                               :symname (format nil "\"~afp~d\"" (tg-asloc) n)
                               :symtype nil :off 0)))
            (emit :load k r1 (newcon cc fn) nil)
            r1))
         (t
          (let ((r1 (newtmp "isel" k fn)))
            (emit :copy k r1 r nil)
            r1))))
      ((tmp-p r)
       (cond
         ((/= (tmp-slot r) -1)
          ;; aggregate passed by value on stack, or fast local address:
          ;; replace with the slot if we can
          (if (rv-memarg-p argn op)
              (make-slot-ref (tmp-slot r))
              (let ((r1 (newtmp "isel" k fn)))
                (emit :addr k r1 (make-slot-ref (tmp-slot r)) nil)
                r1)))
         ((and (eq k :w) (eq (tmp-cls r) :l))
          ;; TODO (upstream): this sign extension isn't needed for 32-bit
          ;; arithmetic instructions
          (let ((r1 (newtmp "isel" k fn)))
            (emit :extsw :l r1 r nil)
            r1))
         (t (assert (eq k (tmp-cls r))) r)))
      (t r))))

(defun rv-fix-ins-args (ic fn)
  "The C `icmp = curi; fixarg(&icmp->arg[0/1], ...)` tail: fix both operands of
the just-emitted instruction IC in place."
  (let ((op (ins-op ic)) (k (ins-cls ic)))
    (setf (ins-arg0 ic) (rv-fixarg (ins-arg0 ic) (argcls op k 0) 0 ic fn))
    (setf (ins-arg1 ic) (rv-fixarg (ins-arg1 ic) (argcls op k 1) 1 ic fn))))

;;; ------------------------------------------------------------------ selcmp

(defun rv-negate (to fn)
  "rv64/isel.c negate: define TO as `xor r, 1`; return the fresh temp r the
compare should now define."
  (let ((r (newtmp "isel" :w fn)))
    (emit :xor :w to r (getcon 1 fn))
    r))

(defun rv-selcmp (i ck cc fn)
  "rv64/isel.c selcmp: lower comparison ins I (combined code CC, operand class
CK).  I is a fresh copy the caller made -- it is mutated and emitted here."
  (let ((k ck))
    (case cc
      (0                                             ; Cieq: xor + seqz
       (let ((r (newtmp "isel" k fn)))
         (emit :reqz (ins-cls i) (ins-to i) r nil)
         (emit :xor k r (ins-arg0 i) (ins-arg1 i))
         (rv-fix-ins-args (car *emitted*) fn))
       (return-from rv-selcmp))
      (1                                             ; Cine: xor + snez
       (let ((r (newtmp "isel" k fn)))
         (emit :rnez (ins-cls i) (ins-to i) r nil)
         (emit :xor k r (ins-arg0 i) (ins-arg1 i))
         (rv-fix-ins-args (car *emitted*) fn))
       (return-from rv-selcmp))
      (16                                            ; Cfo: both args ordered
       (let ((r0 (newtmp "isel" (ins-cls i) fn))
             (r1 (newtmp "isel" (ins-cls i) fn))
             (op (if (kwide k) :ceqd :ceqs)))
         (emit :and (ins-cls i) (ins-to i) r0 r1)
         (emit op (ins-cls i) r0 (ins-arg0 i) (ins-arg0 i))
         (rv-fix-ins-args (car *emitted*) fn)
         (emit op (ins-cls i) r1 (ins-arg1 i) (ins-arg1 i))
         (rv-fix-ins-args (car *emitted*) fn))
       (return-from rv-selcmp))
      (17                                            ; Cfuo: negated Cfo
       (setf (ins-to i) (rv-negate (ins-to i) fn))
       (let ((r0 (newtmp "isel" (ins-cls i) fn))
             (r1 (newtmp "isel" (ins-cls i) fn))
             (op (if (kwide k) :ceqd :ceqs)))
         (emit :and (ins-cls i) (ins-to i) r0 r1)
         (emit op (ins-cls i) r0 (ins-arg0 i) (ins-arg0 i))
         (rv-fix-ins-args (car *emitted*) fn)
         (emit op (ins-cls i) r1 (ins-arg1 i) (ins-arg1 i))
         (rv-fix-ins-args (car *emitted*) fn))
       (return-from rv-selcmp)))
    (multiple-value-bind (sign swap neg)
        (case cc
          (2 (values 1 0 1)) (3 (values 1 1 0))      ; sge / sgt
          (4 (values 1 1 1)) (5 (values 1 0 0))      ; sle / slt
          (6 (values 0 0 1)) (7 (values 0 1 0))      ; uge / ugt
          (8 (values 0 1 1)) (9 (values 0 0 0))      ; ule / ult
          ((10 11 12 13 14) (values nil 0 0))        ; feq/fge/fgt/fle/flt
          (15 (setf (ins-op i) (if (kwide k) :ceqd :ceqs))
              (values nil 0 1))                      ; Cfne: !(a == b)
          (t (error "rv64 isel: unknown comparison ~d" cc)))
      (when (< cc 10)
        (setf (ins-op i) (if (= sign 1) :csltl :cultl)))
      (when (= swap 1) (rotatef (ins-arg0 i) (ins-arg1 i)))
      (when (= neg 1) (setf (ins-to i) (rv-negate (ins-to i) fn)))
      (emiti i)
      ;; NB: the C fixarg pair passes the COMPARE class k for both operands
      ;; (not argcls of the rewritten op).
      (setf (ins-arg0 i) (rv-fixarg (ins-arg0 i) k 0 i fn))
      (setf (ins-arg1 i) (rv-fixarg (ins-arg1 i) k 1 i fn)))))

;;; --------------------------------------------------------------------- sel

(defun rv-sel (i fn)
  "rv64/isel.c sel: lower one instruction (already popped from the block)."
  (let ((op (ins-op i)))
    (cond
      ((member op '(:alloc4 :alloc8 :alloc16))
       (let ((n (length *emitted*)))
         (salloc (ins-to i) (ins-arg0 i) fn)
         ;; the C `i0 = curi - 1`: the first ins salloc emitted (the :salloc)
         (let ((i0 (nth (- (length *emitted*) n 1) *emitted*)))
           (setf (ins-arg0 i0) (rv-fixarg (ins-arg0 i0) :l 0 i0 fn)))))
      ((iscmp op)
       (multiple-value-bind (cc ck) (iscmp op)
         (rv-selcmp (copy-ins i) ck cc fn)))
      ((not (eq op :nop))
       (let ((ic (copy-ins i)))
         (emiti ic)
         (rv-fix-ins-args ic fn))))))

(defun rv-seljmp (b fn)
  "rv64/isel.c seljmp: only jnz needs its argument fixed.
TODO (upstream): replace cmp+jnz with beq/bne/blt[u]/bge[u]."
  (when (eq (blk-jmp-type b) :jnz)
    (setf (blk-jmp-arg b) (rv-fixarg (blk-jmp-arg b) :w 0 nil fn))))

;;; ------------------------------------------------------------------ driver

(defun rv-assign-fast-allocs (fn)
  "rv64/isel.c: turn constant-size allocs in the start block into stack slots
(NAlign == 3: slot units are 4 bytes)."
  (let ((b (fn-start fn)))
    (loop for al in '(:alloc4 :alloc8 :alloc16) for n = 4 then (* n 2) do
      (block per-op
        (dolist (i (blk-ins b))
          (when (eq (ins-op i) al)
            (unless (con-p (ins-arg0 i)) (return-from per-op))
            (let ((sz (con-value (ins-arg0 i))))
              (when (or (< sz 0) (>= sz (- most-positive-fixnum 15)))
                (abi-unsupported "invalid alloc size"))
              (setf sz (floor (logand (+ sz n -1) (- n)) 4))
              (setf (tmp-slot (ins-to i)) (fn-slot fn))
              (incf (fn-slot fn) sz)
              (setf (ins-op i) :nop (ins-to i) nil
                    (ins-arg0 i) nil (ins-arg1 i) nil (ins-cls i) :w))))))))

(defun rv64-isel (fn)
  "rv64/isel.c rv64_isel: instruction selection.  Rewrites FN."
  (rv-assign-fast-allocs fn)
  (dolist (b (fn-blocks fn))
    (let ((*emitted* nil))
      ;; fix phi arguments flowing out of B into successor phis (NB: unlike
      ;; arm64, constants do NOT survive in rv64 phis -- fixarg is called with
      ;; no ins, so integer constants are copied into fresh temps here).
      (dolist (sb (remove nil (list (blk-s1 b) (blk-s2 b))))
        (dolist (p (blk-phis sb))
          (let ((cell (assoc b (phi-args p) :test #'eq)))
            (when cell
              (setf (cdr cell) (rv-fixarg (cdr cell) (phi-cls p) 0 nil fn))))))
      (rv-seljmp b fn)
      (let ((vec (coerce (blk-ins b) 'vector)))
        (loop for k from (1- (length vec)) downto 0
              do (rv-sel (aref vec k) fn)))
      (setf (blk-ins b) *emitted*))))
