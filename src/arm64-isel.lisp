;;;; arm64-isel.lisp --- arm64 instruction selection (G3), mirrors arm64/isel.c.
;;;;
;;;; Verified against `qbe -t arm64_apple -dI` ("> After instruction selection:").
;;;; Much smaller than amd64/isel.c: no address-matching (arm64 has no complex
;;;; addressing to fold), so it is mostly imm/logimm classification, fixarg
;;;; (constants -> registers / fp-pool loads, fast-local slots -> addr), selcmp
;;;; (Oacmp/Oacmn/Oafcmp + flag/jump-code fixup), and fast-alloc slot assignment.
;;;;
;;;; As elsewhere QBE emits backward; our `emit`/`emiti` push onto *emitted*,
;;;; so emitting in QBE's order yields QBE's final block order.

(in-package #:qbe)

;;; ------------------------------------------------------------------- imm
;;; arm64/isel.c enum Imm: how a constant fits an add/sub/cmp immediate.

(defconstant +a64-iother+ 0)
(defconstant +a64-iplo12+ 1) (defconstant +a64-iphi12+ 2) (defconstant +a64-iplo24+ 3)
(defconstant +a64-inlo12+ 4) (defconstant +a64-inhi12+ 5) (defconstant +a64-inlo24+ 6)

(defun a64-imm (c k)
  "arm64/isel.c imm: classify con C at class K.  Returns (values enum n) where
n is the (possibly negated) magnitude."
  (if (not (eq (con-kind c) :bits))
      (values +a64-iother+ 0)
      (let ((n (con-rawbits c)) (i +a64-iplo12+))
        (when (eq k :w) (setf n (s32* n)))
        (when (< n 0) (setf i +a64-inlo12+ n (u64* (- n))))
        (cond
          ((= (logand n #x000fff) n) (values i n))
          ((= (logand n #xfff000) n) (values (+ i 1) n))
          ((= (logand n #xffffff) n) (values (+ i 2) n))
          (t (values +a64-iother+ n))))))

(defun arm64-logimm (x k)
  "arm64/isel.c arm64_logimm: t if X is a valid logical (and/or/xor) immediate."
  (let ((x (u64* x)))
    (when (eq k :w) (setf x (u64* (logior (logand x #xffffffff) (ash x 32)))))
    (when (logbitp 0 x) (setf x (u64* (lognot x))))
    (cond
      ((= x 0) nil)
      ((= x #xaaaaaaaaaaaaaaaa) t)
      (t (let ((n (block find
                    (let ((n (logand x #xf)))
                      (when (= (u64* (* #x1111111111111111 n)) x) (return-from find n)))
                    (let ((n (logand x #xff)))
                      (when (= (u64* (* #x0101010101010101 n)) x) (return-from find n)))
                    (let ((n (logand x #xffff)))
                      (when (= (u64* (* #x0001000100010001 n)) x) (return-from find n)))
                    (let ((n (logand x #xffffffff)))
                      (when (= (u64* (* #x0000000100000001 n)) x) (return-from find n)))
                    x)))
           (= (logand n (u64* (+ n (logand n (- n))))) 0))))))

;;; ------------------------------------------------------------------ fixarg
;;; arm64/isel.c fixarg: rewrite one operand so the emitter can encode it.
;;; QBE mutates *pr; we return the (possibly new) ref and let callers assign it.

(defun a64-fixarg (r k phi fn)
  "arm64/isel.c fixarg (operand R, class K).  Returns the operand to use."
  ;; QBE's Km (memory-pointer arg class of load/store/addr/call) is #defined to
  ;; Kl, so a Km operand class is just Kl; normalize the distinct :m keyword.
  (when (eq k :m) (setf k :l))
  (cond
    ((con-p r)
     (cond
       ;; extern (GOT, SExt) or Apple thread-local (SThr) address operand.
       ((and (eq (con-kind r) :addr)
             (or (member :ext (con-symtype r))
                 (and (tg-apple) (member :thr (con-symtype r)))))
        (let ((r1 (newtmp "isel" :l fn)) (result nil))
          (setf result r1)
          (when (/= (con-off r) 0)             ; nonzero addend: add it back on
            (let ((r2 (newtmp "isel" :l fn))
                  (r3 (newcon (make-con :kind :bits :value (con-off r)) fn)))
              (emit :add :l r1 r2 r3)
              (setf r1 r2)))
          (when (and (tg-apple) (member :thr (con-symtype r)))
            ;; Apple TLS: call the variable's descriptor (in x0) via tlv helper.
            (emit :copy :l r1 (a64rg +a64-r0+) nil)
            (let ((nr1 (newtmp "isel" :l fn)) (r2 (newtmp "isel" :l fn)))
              (emit :call :w nil nr1 (make-call-ref 33))
              (emit :copy :l (a64rg +a64-r0+) r2 nil)
              (emit :load :l nr1 r2 nil)
              (setf r1 r2)))
          ;; the address itself, with a zeroed addend
          (let ((cc (make-con :kind :addr :symname (con-symname r)
                              :symtype (con-symtype r) :off 0)))
            (emit :copy :l r1 (newcon cc fn) nil))
          result))
       ;; an integer constant destined for a phi in an int class is left alone
       ((and (= (cls-base k) 0) phi) r)
       ((= (cls-base k) 0)
        (let ((r1 (newtmp "isel" k fn)))
          (emit :copy k r1 r nil)
          r1))
       (t
        ;; a float constant is loaded from the "<asloc>fpN" pool slot
        (let* ((n (stashbits (con-rawbits r) (if (kwide k) 8 4)))
               (r1 (newtmp "isel" k fn))
               (r2 (newtmp "isel" :l fn))
               (cc (make-con :kind :addr
                             :symname (format nil "\"~afp~d\"" (tg-asloc) n)
                             :symtype nil :off 0)))
          (emit :load k r1 r2 nil)
          (emit :copy :l r2 (newcon cc fn) nil)
          r1))))
    ((and (tmp-p r) (/= (tmp-slot r) -1))
     (let ((r1 (newtmp "isel" :l fn)))
       (emit :addr :l r1 (make-slot-ref (tmp-slot r)) nil)
       r1))
    (t r)))

;;; ------------------------------------------------------------------ selcmp
(defun a64-selcmp (a0 a1 k fn)
  "arm64/isel.c selcmp: emit the Oacmp/Oacmn/Oafcmp for compare operands A0/A1
at class K.  Returns t if the operands were swapped (caller adjusts the code)."
  (if (= (cls-base k) 1)
      (progn
        (emit :afcmp k nil a0 a1)
        (let ((ci (car *emitted*)))
          (setf (ins-arg0 ci) (a64-fixarg (ins-arg0 ci) k nil fn)
                (ins-arg1 ci) (a64-fixarg (ins-arg1 ci) k nil fn)))
        nil)
      (let ((swap (con-p a0)) (fix t) (cmp :acmp) r)
        (when swap (rotatef a0 a1))
        (setf r a1)
        (when (con-p r)
          (multiple-value-bind (enum n) (a64-imm r k)
            (cond
              ((or (= enum +a64-iplo12+) (= enum +a64-iphi12+)) (setf fix nil))
              ((or (= enum +a64-inlo12+) (= enum +a64-inhi12+))
               (setf cmp :acmn r (getcon n fn) fix nil)))))
        (emit cmp k nil a0 r)
        (let ((ci (car *emitted*)))
          (setf (ins-arg0 ci) (a64-fixarg (ins-arg0 ci) k nil fn))
          (when fix (setf (ins-arg1 ci) (a64-fixarg (ins-arg1 ci) k nil fn))))
        swap)))

;;; ------------------------------------------------------------------ sel
(defun a64-callable (r fn)
  "arm64/isel.c callable: t if R is a direct-callable call target."
  (declare (ignore fn))
  (or (tmp-p r)
      (and (con-p r) (eq (con-kind r) :addr) (= (con-off r) 0))))

(defparameter *a64-alloc-slot*
  '((:alloc4 . 4) (:alloc8 . 8) (:alloc16 . 16))
  "arm64/isel.c fast-alloc slot loop: alloc op -> its byte alignment n.")

(defun a64-sel (i fn)
  "arm64/isel.c sel: lower one instruction I (already popped from the block)."
  (let ((op (ins-op i)))
    (cond
      ((member op '(:alloc4 :alloc8 :alloc16))
       (salloc (ins-to i) (ins-arg0 i) fn)
       ;; salloc emitted a :salloc; fix its size operand (curi-1 in C)
       (let ((i0 (car *emitted*)))
         (setf (ins-arg0 i0) (a64-fixarg (ins-arg0 i0) :l nil fn))))
      ((iscmp op)
       ;; emit Oflag+cc (arm64/isel.c); selcmp runs after and may swap the code.
       ;; We emit a placeholder flag ins, then set its op from the final cc.
       (multiple-value-bind (cc ck) (iscmp op)
         (emit (aref *flag-ops* cc) (ins-cls i) (ins-to i) nil nil)
         (let ((i0 (car *emitted*)))
           (when (a64-selcmp (ins-arg0 i) (ins-arg1 i) ck fn)
             (setf (ins-op i0) (aref *flag-ops* (aref *cmpop-swap* cc)))))))
      ((and (eq op :call) (a64-callable (ins-arg0 i) fn))
       (emiti i))
      ((not (eq op :nop))
       (emiti i)
       (let ((i0 (car *emitted*)))
         (setf (ins-arg0 i0) (a64-fixarg (ins-arg0 i0) (argcls op (ins-cls i) 0) nil fn)
               (ins-arg1 i0) (a64-fixarg (ins-arg1 i0) (argcls op (ins-cls i) 1) nil fn)))))))

;;; ------------------------------------------------------------------ seljmp
(defun a64-seljmp (b fn)
  "arm64/isel.c seljmp: lower B's conditional jump (fold a feeding compare)."
  (let ((jt (blk-jmp-type b)))
    (unless (member jt '(:ret0 :jmp :hlt))
      (let* ((r (blk-jmp-arg b)) (vec (coerce (blk-ins b) 'vector))
             (ir nil) (use -1))
        (setf (blk-jmp-arg b) nil)
        (loop for k from (1- (length vec)) downto 0
              for i = (aref vec k)
              when (eq (ins-to i) r)
                do (setf use (tmp-nuse r) ir i) (return))
        (if (and ir (= use 1) (iscmp (ins-op ir)))
            (multiple-value-bind (cc ck) (iscmp (ins-op ir))
              (when (a64-selcmp (ins-arg0 ir) (ins-arg1 ir) ck fn)
                (setf cc (aref *cmpop-swap* cc)))
              (setf (blk-jmp-type b) (aref *jf-jumps-vec* cc))
              (setf (ins-op ir) :nop (ins-to ir) nil
                    (ins-arg0 ir) nil (ins-arg1 ir) nil (ins-cls ir) :w))
            (progn
              (a64-selcmp r (getcon 0 fn) :w fn)   ; CON_Z
              (setf (blk-jmp-type b) :jfine)))))))

;;; ------------------------------------------------------------------ driver
(defun a64-assign-fast-allocs (fn)
  "arm64/isel.c fast-alloc slots: turn constant-size allocs in the start block
into stack slots (NAlign == 3, so slot units are 4 bytes)."
  (let ((b (fn-start fn)))
    (dolist (entry *a64-alloc-slot*)
      (let ((al (car entry)) (n (cdr entry)))
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
                      (ins-arg0 i) nil (ins-arg1 i) nil (ins-cls i) :w)))))))))

(defun arm64-isel (fn)
  "arm64/isel.c arm64_isel: instruction selection.  Rewrites FN."
  (a64-assign-fast-allocs fn)
  (dolist (b (fn-blocks fn))
    (let ((*emitted* nil))
      ;; fix phi arguments flowing out of B into successor phis
      (dolist (sb (remove nil (list (blk-s1 b) (blk-s2 b))))
        (dolist (p (blk-phis sb))
          (let ((cell (assoc b (phi-args p) :test #'eq)))
            (when cell
              (setf (cdr cell) (a64-fixarg (cdr cell) (phi-cls p) t fn))))))
      (a64-seljmp b fn)
      (let ((vec (coerce (blk-ins b) 'vector)))
        (loop for k from (1- (length vec)) downto 0
              do (a64-sel (aref vec k) fn)))
      (setf (blk-ins b) *emitted*))))
