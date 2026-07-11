;;;; amd64-isel.lisp --- amd64 instruction selection (M3/B3), mirrors amd64/isel.c
;;;;
;;;; Scalar path: pass-through arithmetic/logic/conversion, constant and
;;;; variable shifts, div/rem, sel (cmov), compare selection (standalone ->
;;;; xcmp + flag; feeding jnz -> xcmp + jf<cc>), and dead-code elimination.
;;;;
;;;; SLICE d adds memory: fast-local slot assignment + dynamic salloc, and the
;;;; table-driven addressing-mode recognizer (anumber/refn/opn/runmatch/adisp/
;;;; amatch/seladdr) that folds base + scale*index + displacement into an RMem
;;;; for loads and stores.  fixarg gains the fast-local, indirect-call and
;;;; RMem-elimination cases.  Extern/thread-local symbols and fp-constant
;;;; memory slots remain deferred (abi-unsupported).
;;;;
;;;; Oracle: `qbe -dI`'s "> After instruction selection:" dump.

(in-package #:qbe)

;;; ---- comparison encoding (all.h CmpI/CmpF; iscmp; cmptab swap; flag/jf order)

(defparameter *cmp-codes*
  (let ((h (make-hash-table :test 'eq))
        (iw '(:ceqw :cnew :csgew :csgtw :cslew :csltw :cugew :cugtw :culew :cultw))
        (il '(:ceql :cnel :csgel :csgtl :cslel :csltl :cugel :cugtl :culel :cultl))
        (fs '(:ceqs :cges :cgts :cles :clts :cnes :cos :cuos))
        (fd '(:ceqd :cged :cgtd :cled :cltd :cned :cod :cuod)))
    (loop for op in iw for c from 0 do (setf (gethash op h) (cons c :w)))
    (loop for op in il for c from 0 do (setf (gethash op h) (cons c :l)))
    (loop for op in fs for c from 10 do (setf (gethash op h) (cons c :s)))
    (loop for op in fd for c from 10 do (setf (gethash op h) (cons c :d)))
    h))

(defun iscmp (op)
  "If OP is a comparison return (values c k): c the combined CmpI/CmpF code
   (0..17), k the operand class; else NIL."
  (let ((e (gethash op *cmp-codes*)))
    (when e (values (car e) (cdr e)))))

(defparameter *flag-ops*
  #(:flagieq :flagine :flagisge :flagisgt :flagisle :flagislt
    :flagiuge :flagiugt :flagiule :flagiult
    :flagfeq :flagfge :flagfgt :flagfle :flagflt :flagfne :flagfo :flagfuo))
(defparameter *jf-jumps-vec*
  #(:jfieq :jfine :jfisge :jfisgt :jfisle :jfislt :jfiuge :jfiugt :jfiule :jfiult
    :jffeq :jffge :jffgt :jffle :jfflt :jffne :jffo :jffuo))
(defparameter *xsel-ops*
  #(:xselieq :xseline :xselisge :xselisgt :xselisle :xselislt
    :xseliuge :xseliugt :xseliule :xseliult
    :xselfeq :xselfge :xselfgt :xselfle :xselflt :xselfne :xselfo :xselfuo))

;; cmptab[c][1] — comparison code when the two operands are swapped.
(defparameter *cmpop-swap*
  #(0 1 4 5 2 3 8 9 6 7 10 13 14 11 12 15 16 17))
(defconstant +cine+ 1)      ; Cine, for "jump if nonzero"

;; amd64_op zflag/lflag (amd64/targ.c via ops.h X()) — for flagi.
(defparameter *zflag-ops*
  '(:add :sub :neg :and :or :xor :sar :shr :shl :blit0 :blit1 :xcmp :xtest
    :ceqw :cnew :csgew :csgtw :cslew :csltw :cugew :cugtw :culew :cultw
    :ceql :cnel :csgel :csgtl :cslel :csltl :cugel :cugtl :culel :cultl
    :ceqs :cges :cgts :cles :clts :cnes :cos :cuos
    :ceqd :cged :cgtd :cled :cltd :cned :cod :cuod))
(defun op-zflag (op) (and (member op *zflag-ops*) t))
(defun op-lflag (op)
  (or (isload-op op) (isstore-op op)
      (member op '(:extsb :extub :extsh :extuh :extsw :extuw :exts :truncd
                   :stosi :stoui :dtosi :dtoui :swtof :uwtof :sltof :ultof
                   :cast :copy :dbgloc :nop :addr))
      (and (>= (length (symbol-name op)) 4)
           (string= (symbol-name op) "FLAG" :end1 4))))

;;; ---------------------------------------------------------------- helpers

(defun noimm (r)
  "Is R a constant that can't be an x86 immediate (not a 32-bit signed int)?"
  (and (con-p r)
       (ecase (con-kind r)
         (:addr nil)
         (:bits (let ((v (con-value r)))
                  (or (< v #x-80000000) (> v #x7fffffff)))))))

(defun chuse (r du)
  (when (tmp-p r) (incf (tmp-nuse r) du)))

(defun emiti (i) (push i *emitted*))

(defun rslot (r)
  "The stack slot of R if it is a fast-local temp, else NIL (amd64/isel.c rslot)."
  (and (tmp-p r) (>= (tmp-slot r) 0) (tmp-slot r)))

(defun hascon (r)
  "The con backing operand R (RCon -> itself, RMem -> its offset), else NIL."
  (cond ((con-p r) r) ((mem-p r) (mem-offset r)) (t nil)))

;;; ------------------------------------------------------------------ fixarg

(defun fixarg (r op k fn &optional argn icls)
  "Fix operand R (arg ARGN, class K) of an OP instruction, emitting any load it
   needs, and return the ref to use (amd64/isel.c fixarg).  Branch order mirrors
   the C so mutually-exclusive cases resolve identically."
  (let ((s (rslot r)))
    (cond
      ((null r) r)
      ;; [A] floating-point constants must be loaded from memory (later slice)
      ((and (con-p r) (eq (con-kind r) :bits) (con-flt r))
       (abi-unsupported "float constant operand"))
      ;; [B] a constant (non-address) call target becomes an indirect call
      ((and (eq op :call) (eql argn 0) (con-p r) (not (eq (con-kind r) :addr)))
       (let ((tm (newtmp "isel" :l fn))) (emit :copy :l tm r nil) tm))
      ;; [C] a constant too large for a 32-bit immediate must live in a register
      ((and (not (eq op :copy)) (eq k :l) (noimm r))
       (let ((tm (newtmp "isel" :l fn))) (emit :copy :l tm r nil) tm))
      ;; [D] load a fast local's address into a temporary right before the use
      (s
       (let ((tm (newtmp "isel" :l fn))) (emit :addr :l tm (make-slot-ref s) nil) tm))
      ;; [E] extern / thread-local symbols need GOT/TLS access (later slice)
      ((and (not (eq op :call)) (hascon r)
            (eq (con-kind (hascon r)) :addr)
            (or (member :ext (con-symtype (hascon r)))
                (member :thr (con-symtype (hascon r)))))
       (abi-unsupported "extern/thread-local address operand"))
      ;; [F] turn a (local) address operand into an lea/mov into a temporary
      ((and (con-p r) (eq (con-kind r) :addr)
            (not (eq op :call)) (not (isload-op op))
            (not (and (isstore-op op) (eql argn 1))))
       (let ((tm (newtmp "isel" :l fn))) (emit :addr :l tm r nil) tm))
      ;; [G] eliminate a memory operand of the form $foo(%rip, ...)
      ((mem-p r)
       (when (and (null (mem-base r)) (mem-offset r)
                  (eq (con-kind (mem-offset r)) :addr))
         (let ((tm (newtmp "isel" :l fn)))
           (emit :addr :l tm (newcon (mem-offset r) fn) nil)
           (setf (mem-offset r) (make-con :kind :undef :value 0)
                 (mem-base r) tm)))
       r)
      ;; [H] a conditional-move (cmov) can't take an immediate operand
      ((and (con-p r) (find op *xsel-ops*))
       (let ((tm (newtmp "isel" (or icls k) fn))) (emit :copy (or icls k) tm r nil) tm))
      (t r))))

;;; ------------------------------------------------------------------ compares

(defun cmpswap (c arg0)
  "Should the two compare operands be swapped?  (amd64/isel.c cmpswap)"
  (cond ((or (= c 13) (= c 14)) 1)          ; float le / lt
        ((or (= c 11) (= c 12)) 0)          ; float ge / gt
        ((con-p arg0) 1)
        (t 0)))

(defun selcmp (a0 a1 k swap fn)
  "Emit the xcmp for a comparison of A0,A1 at class K (amd64/isel.c selcmp)."
  (when (= swap 1) (rotatef a0 a1))
  (emit :xcmp k nil a1 a0)                    ; note: xcmp reverses the operands
  (let ((icmp (car *emitted*)))
    (when (con-p a0)
      (let ((tm (newtmp "isel" k fn)))
        (setf (ins-arg1 icmp) tm)
        (emit :copy k tm a0 nil)
        (setf (ins-arg0 (car *emitted*))
              (fixarg (ins-arg0 (car *emitted*)) :copy k fn))))
    (setf (ins-arg0 icmp) (fixarg (ins-arg0 icmp) :xcmp k fn))
    (setf (ins-arg1 icmp) (fixarg (ins-arg1 icmp) :xcmp k fn))))

;;; ------------------------------------------------ addressing-mode recognition
;;; amd64/isel.c seladdr/amatch/adisp/anumber/opn/refn/runmatch + util.c addcon.
;;; A per-block `Num` array (indexed by temp id) numbers each temp by the shape
;;; of its defining add/mul, driving a table-driven matcher (mgen output).

(defstruct (num (:constructor make-num)) (n 0) (nl 0) (nr 0) (l nil) (r nil))

(defvar *num* nil "Current block's Num array (temp id -> num).")

(defconstant +addr-int-min+ -1000000000
  "Sentinel for refn's INT_MIN (regs/other): never a valid match index.")

;; addressing pattern ids (amd64/isel.c enum Pob..Pobi1).
(defconstant +pob+ 0) (defconstant +pbis+ 1) (defconstant +pois+ 2)
(defconstant +pobis+ 3) (defconstant +pbi1+ 4) (defconstant +pobi1+ 5)

(defun addcon (c0 c1 m)
  "util.c addcon: fold constant/symbol C1 (scaled by M) into accumulator C0.
   Returns NIL (0) on an impossible combination, else T."
  (labels ((biti (c) (ecase (con-kind c) (:bits (con-value c)) (:addr (con-off c)) (:undef 0)))
           (set-biti (c v) (ecase (con-kind c)
                             (:bits (setf (con-value c) (norm-i64 v)))
                             (:addr (setf (con-off c) (norm-i64 v))))))
    (cond
      ((and (/= m 1) (eq (con-kind c1) :addr)) nil)
      ((eq (con-kind c0) :undef)
       (setf (con-kind c0) (con-kind c1) (con-flt c0) (con-flt c1)
             (con-value c0) (con-value c1) (con-off c0) (con-off c1)
             (con-symname c0) (con-symname c1) (con-symtype c0) (con-symtype c1))
       (set-biti c0 (* (biti c0) m))
       t)
      (t
       (let ((add (* (biti c1) m)))
         (when (eq (con-kind c1) :addr)
           (when (eq (con-kind c0) :addr) (return-from addcon nil))
           (let ((old (biti c0)))
             (setf (con-kind c0) :addr
                   (con-symname c0) (con-symname c1) (con-symtype c0) (con-symtype c1)
                   (con-off c0) (norm-i64 old))))
         (set-biti c0 (+ (biti c0) add)))
       t))))

(defun refn (r tn)
  "amd64/isel.c refn: number a ref for the addressing matcher."
  (cond
    ((tmp-p r)
     (let ((nm (aref tn (tmp-id r))))
       (when (= (num-n nm) 0) (setf (num-n nm) 2))
       (num-n nm)))
    ((con-p r)
     (if (not (eq (con-kind r) :bits)) 1
         (if (member (con-rawbits r) '(8 4 2 1)) 0 1)))
    (t +addr-int-min+)))

(defparameter *oaddtbl*
  #(2
    2 2
    4 4 5
    6 6 8 8
    4 4 9 10 9
    7 7 5 8 9 5
    4 4 12 10 12 12 12
    4 4 9 10 9 9 12 9
    11 11 5 8 9 5 12 9 5
    7 7 5 8 9 5 12 9 5 5
    11 11 5 8 9 5 12 9 5 5 5
    4 4 9 10 9 9 12 9 9 9 9 9
    7 7 5 8 9 5 12 9 5 5 5 9 5))

(defun opn (op l r)
  "amd64/isel.c opn: numbering for an add/mul from its operand numbers."
  (when (< l r) (rotatef l r))
  (case op
    (:mul (if (and (<= 2 l) (= r 0)) 3 2))
    (:add (let ((idx (+ (truncate (+ l (* l l)) 2) r)))
            (if (<= 0 idx 90) (aref *oaddtbl* idx) 2)))
    (t 2)))

(defun anumber (tn b)
  "amd64/isel.c anumber: fill TN for block B's temps (forward order)."
  (dolist (i (blk-ins b))
    (when (tmp-p (ins-to i))
      (let ((nm (aref tn (tmp-id (ins-to i)))))
        (setf (num-l nm) (ins-arg0 i) (num-r nm) (ins-arg1 i)
              (num-nl nm) (refn (ins-arg0 i) tn)
              (num-nr nm) (refn (ins-arg1 i) tn)
              (num-n nm) (opn (ins-op i) (num-nl nm) (num-nr nm)))))))

(defparameter *match*
  (let ((v (make-array 13 :initial-element 0)))
    (flet ((b (p) (ash 1 p)))
      (setf (aref v 4)  (b +pob+)
            (aref v 5)  (b +pbi1+)
            (aref v 6)  (logior (b +pob+) (b +pois+))
            (aref v 7)  (logior (b +pob+) (b +pobi1+))
            (aref v 8)  (logior (b +pbi1+) (b +pbis+))
            (aref v 9)  (logior (b +pbi1+) (b +pobi1+))
            (aref v 10) (logior (b +pbi1+) (b +pbis+) (b +pobi1+) (b +pobis+))
            (aref v 11) (logior (b +pob+) (b +pobi1+) (b +pobis+))
            (aref v 12) (logior (b +pbi1+) (b +pobi1+) (b +pobis+))))
    v))

(defun matchbits (n) (if (<= 0 n 12) (aref *match* n) 0))

(defparameter *matcher*
  (let ((v (make-array 6)))
    (setf (aref v +pbi1+)  #(1 3 1 3 2 0)
          (aref v +pbis+)  #(5 1 8 5 27 1 5 1 2 5 13 3 1 1 3 3 3 2 0 1
                             3 3 3 2 3 1 0 1 29)
          (aref v +pob+)   #(1 3 0 3 1 0)
          (aref v +pobi1+) #(5 3 9 9 10 33 12 35 45 1 5 3 11 9 7 9 4 9
                             17 1 3 0 3 1 3 2 0 3 1 1 3 0 34 1 37 1 5 2
                             5 7 2 7 8 37 29 1 3 0 1 32)
          (aref v +pobis+) #(5 2 10 7 11 19 49 1 1 3 3 3 2 1 3 0 3 1 0
                             1 3 0 5 1 8 5 25 1 5 1 2 5 13 3 1 1 3 3 3
                             2 0 1 3 3 3 2 26 1 51 1 5 1 6 5 9 1 3 0 51
                             3 1 1 3 0 45)
          (aref v +pois+)  #(1 3 0 1 3 3 3 2 0))
    v))

(defun runmatch (code tn ref var)
  "util.c runmatch: interpret the mgen bytecode, filling VAR (a 4-vector)."
  (let ((stk (make-array 20)) (sp 0) (pc 0))
    (loop
      (let ((bc (aref code pc)))
        (when (= bc 0) (return))
        (cond
          ((or (= bc 1) (= bc 2))            ; pushsym / push
           (let* ((nm (aref tn (tmp-id ref))) (nl (num-nl nm)) (nr (num-nr nm)))
             (if (and (= bc 1) (> nl nr))
                 (progn (setf (aref stk sp) (num-l nm)) (setf ref (num-r nm)))
                 (progn (setf (aref stk sp) (num-r nm)) (setf ref (num-l nm))))
             (incf sp) (incf pc)))
          ((= bc 3)                          ; set (maybe fall through to pop)
           (incf pc)
           (setf (aref var (aref code pc)) ref)
           (if (= (aref code (1+ pc)) 0)
               (return)
               (progn (decf sp) (setf ref (aref stk sp)) (incf pc))))
          ((= bc 4)                          ; pop
           (decf sp) (setf ref (aref stk sp)) (incf pc))
          ((= bc 5)                          ; switch
           (let ((n (num-n (aref tn (tmp-id ref)))) (s (1+ pc)))
             (let ((cnt (aref code s)))
               (incf s)
               (dotimes (k cnt)
                 (if (= n (aref code s)) (progn (incf s) (return)) (incf s 2)))
               (incf pc (aref code s)))))
          (t (setf pc (- bc 10))))))))       ; jump

(defun adisp (c tn r fn s)
  "amd64/isel.c adisp: peel constant displacements off address chain R into C."
  (declare (ignore fn))
  (loop while r do
    (let ((n (refn r tn)))
      (unless (logtest (matchbits n) (ash 1 +pob+)) (return))
      (let ((v (make-array 4 :initial-element nil)))
        (runmatch (aref *matcher* +pob+) tn r v)
        (addcon c (aref v 0) s)
        (setf r (aref v 1)))))
  r)

(defun amatch (a tn r fn)
  "amd64/isel.c amatch: fill addressing struct A for address R; T on success."
  (when (not (tmp-p r)) (return-from amatch nil))
  (let ((n (refn r tn)) (v (make-array 4 :initial-element nil)) (found nil))
    (dolist (p (list +pobis+ +pobi1+ +pbis+ +pois+ +pbi1+))
      (when (logtest (matchbits n) (ash 1 p))
        (runmatch (aref *matcher* p) tn r v) (setf found t) (return)))
    (unless found (setf (aref v 1) r))
    (let* ((co (make-con :kind :undef :value 0 :off 0))
           (ro (aref v 0))
           (rb (adisp co tn (aref v 1) fn 1))
           (ri (aref v 2))
           (rs (aref v 3))
           (s 1))
      (when (and (not found) (not (eq (con-kind co) :undef)))
        (when (amatch a tn rb fn)
          (return-from amatch (addcon (mem-offset a) co 1))))
      (when ro (unless (addcon co ro 1) (return-from amatch nil)))
      (when rs (setf s (con-value rs)))
      (setf ri (adisp co tn ri fn s))
      (setf (mem-offset a) co (mem-base a) rb (mem-index a) ri (mem-scale a) s)
      ;; a stack slot can only be the base, and only at scale 1
      (when (and (tmp-p ri) (>= (tmp-slot ri) 0))
        (when (or (/= (mem-scale a) 1) (and (tmp-p rb) (>= (tmp-slot rb) 0)))
          (return-from amatch nil))
        (setf (mem-base a) ri (mem-index a) rb))
      (let ((b (mem-base a)))
        (when (and (tmp-p b) (>= (tmp-slot b) 0))
          (setf (mem-base a) (make-slot-ref (tmp-slot b)))))
      t)))

(defun seladdr (r fn)
  "amd64/isel.c seladdr: rewrite address operand R into an RMem if it matches."
  (if (not (tmp-p r))
      r
      (let ((a (make-mem :offset (make-con :kind :undef :value 0) :scale 0)))
        (if (not (amatch a *num* r fn))
            r
            (progn
              ;; a symbol offset combined with a base register: rewrite
              ;; $foo(%base) into $foo(,%base,1), or bail if impossible
              (when (and (mem-base a) (mem-offset a)
                         (eq (con-kind (mem-offset a)) :addr))
                (if (or (mem-index a) (not (tmp-p (mem-base a))))
                    (return-from seladdr r)
                    (setf (mem-index a) (mem-base a) (mem-scale a) 1 (mem-base a) nil)))
              (chuse r -1)
              (chuse (mem-base a) 1)
              (chuse (mem-index a) 1)
              a)))))

;;; ------------------------------------------------------------------- salloc
;;; util.c salloc: lower a non-fast (dynamic-size or overflow) alloc.

(defun salloc (rt rs fn)
  (setf (fn-dynalloc fn) t)
  (if (con-p rs)
      (let ((sz (con-value rs)))
        (when (or (< sz 0) (>= sz (- most-positive-fixnum 15)))
          (abi-unsupported "invalid alloc size"))
        (setf sz (logand (+ sz 15) -16))
        (emit :salloc :l rt (getcon sz fn) nil))
      (let ((r0 (newtmp "isel" :l fn)) (r1 (newtmp "isel" :l fn)))
        (emit :salloc :l rt r0 nil)
        (emit :and :l r0 r1 (getcon -16 fn))
        (emit :add :l r1 rs (getcon 15 fn))
        (when (and (tmp-p rs) (>= (tmp-slot rs) 0))
          (abi-unsupported "unlikely alloc argument")))))

;;; --------------------------------------------------------------------- sel

(defparameter *sel-passthrough*
  '(:copy :add :sub :neg :mul :and :or :xor
    :stosi :dtosi :swtof :sltof :exts :truncd :cast
    :extsb :extub :extsh :extuh :extsw :extuw :call :dbgloc :salloc))

(defun emit-fix (ic fn)
  "Emit already-prepared instruction IC, then fix up both operands (the C
   `Emit:` label: emiti(i) then fixarg(&arg[0]) / fixarg(&arg[1]))."
  (let ((op (ins-op ic)) (k (ins-cls ic)))
    (emiti ic)
    (setf (ins-arg0 ic) (fixarg (ins-arg0 ic) op (argcls op k 0) fn 0 k))
    (setf (ins-arg1 ic) (fixarg (ins-arg1 ic) op (argcls op k 1) fn 1 k))))

(defun sel-emit (i fn) (emit-fix (copy-ins i) fn))

;; loads / stores: recognize a complex addressing mode on the address operand
;; (amd64/isel.c sel Oload / Ostore cases -> seladdr -> goto Emit).
(defun sel-load (i fn)
  (let ((ic (copy-ins i)))
    (setf (ins-arg0 ic) (seladdr (ins-arg0 ic) fn))
    (emit-fix ic fn)))

(defun sel-store (i fn)
  (let ((ic (copy-ins i)))
    ;; an fp immediate can't be stored directly: reinterpret its bits and
    ;; store as the same-width integer instead
    (when (con-p (ins-arg0 ic))
      (case (ins-op ic)
        (:stored (setf (ins-op ic) :storel))
        (:stores (setf (ins-op ic) :storew))))
    (setf (ins-arg1 ic) (seladdr (ins-arg1 ic) fn))
    (emit-fix ic fn)))

;; x86 integer division: dividend in RAX, sign/zero-extended into RDX, quotient
;; back in RAX and remainder in RDX (amd64/isel.c sel Odiv/Orem case).
(defun sel-divrem (i fn)
  (let* ((op (ins-op i)) (k (ins-cls i))
         (signed (member op '(:div :rem)))
         (quo (member op '(:div :udiv)))
         (r0 (if quo (rg 1) (rg 3)))          ; result register (RAX / RDX)
         (r1 (if quo (rg 3) (rg 1)))          ; the other (clobbered) register
         (divisor (ins-arg1 i)) (dcon (con-p divisor))
         (dvr (if dcon (newtmp "isel" k fn) divisor)))
    (emit :copy k (ins-to i) r0 nil)
    (emit :copy k nil r1 nil)
    (if signed
        (progn (emit :xidiv k nil dvr nil)
               (emit :sign k (rg 3) (rg 1) nil))
        (progn (emit :xdiv k nil dvr nil)
               (emit :copy k (rg 3) (getcon 0 fn) nil)))
    (emit :copy k (rg 1) (ins-arg0 i) nil)
    (setf (ins-arg0 (car *emitted*)) (fixarg (ins-arg0 (car *emitted*)) :copy k fn))
    (when dcon (emit :copy k dvr divisor nil))))

;; variable shift amounts must be in CL (RCX) (amd64/isel.c sel Osar/Oshr/Oshl).
(defun sel-shift (i fn)
  (let ((k (ins-cls i)) (amt (ins-arg1 i)) (ic (copy-ins i)))
    (setf (ins-arg1 ic) (rg 2))               ; RCX
    (emit :copy :w nil (rg 2) nil)            ; clobber RCX
    (emiti ic)
    (emit :copy :w (rg 2) amt nil)            ; load the shift amount into RCX
    (setf (ins-arg0 ic)
          (fixarg (ins-arg0 ic) (ins-op ic) (argcls (ins-op ic) k 0) fn))))

;; unsigned word -> float: zero-extend to long, then signed long->float.
(defun sel-uwtof (i fn)
  (let ((k (ins-cls i)) (r0 (newtmp "utof" :l fn)))
    (emit :sltof k (ins-to i) r0 nil)
    (emit :extuw :l r0 (ins-arg0 i) nil)
    (let ((cur (car *emitted*)))
      (setf (ins-arg0 cur) (fixarg (ins-arg0 cur) (ins-op cur) k fn)))))

;; unsigned long -> float (amd64/isel.c Oultof): halve-if-big then signed
;; convert and fix up, so the top bit doesn't misread as a sign.
(defun sel-ultof (i fn)
  (let* ((k (ins-cls i)) (r0 (newtmp "utof" k fn))
         (kc (if (eq k :s) :w :l)) (sh (if (eq k :s) 23 52))
         (tp (make-array 7)))
    (dotimes (j 4) (setf (aref tp j) (newtmp "utof" :l fn)))
    (loop for j from 4 to 6 do (setf (aref tp j) (newtmp "utof" kc fn)))
    (emit :cast k (ins-to i) (aref tp 6) nil)
    (emit :add kc (aref tp 6) (aref tp 4) (aref tp 5))
    (emit :shl kc (aref tp 5) (aref tp 1) (getcon sh fn))
    (emit :cast kc (aref tp 4) r0 nil)
    (emit :sltof k r0 (aref tp 3) nil)
    (emit :or :l (aref tp 3) (aref tp 0) (aref tp 2))
    (emit :shr :l (aref tp 2) (ins-arg0 i) (aref tp 1))
    (sel (pop *emitted*) fn)                ; re-select the variable shift
    (emit :shr :l (aref tp 1) (ins-arg0 i) (getcon 63 fn))
    (let ((cur (car *emitted*)))
      (setf (ins-arg0 cur) (fixarg (ins-arg0 cur) :shr :l fn)))
    (emit :and :l (aref tp 0) (ins-arg0 i) (getcon 1 fn))
    (let ((cur (car *emitted*)))
      (setf (ins-arg0 cur) (fixarg (ins-arg0 cur) :and :l fn)))))

(defun sel (i fn)
  ;; dead-code elimination: an unused pure result is dropped
  (when (and (tmp-p (ins-to i))
             (not (reg-p (ins-to i)))
             (not (reg-p (ins-arg0 i))) (not (reg-p (ins-arg1 i)))
             (= 0 (tmp-nuse (ins-to i))))
    (chuse (ins-arg0 i) -1) (chuse (ins-arg1 i) -1)
    (return-from sel))
  (let ((op (ins-op i)) (k (ins-cls i)))
    (cond
      ((eq op :nop))
      ((member op *sel-passthrough*) (sel-emit i fn))
      ((member op '(:div :rem :udiv :urem))
       (if (= (cls-base k) 1) (sel-emit i fn) (sel-divrem i fn)))
      ((member op '(:sar :shr :shl))
       (if (con-p (ins-arg1 i)) (sel-emit i fn) (sel-shift i fn)))
      ((iscmp op)
       (multiple-value-bind (c kc) (iscmp op)
         (let ((to (ins-to i)))
           ;; float eq/ne must also test orderedness (NaN): eq = feq AND fo,
           ;; ne = fne OR fuo (amd64/isel.c sel cmp case)
           (cond
             ((= c 10)
              (let ((r0 (newtmp "isel" :w fn)) (r1 (newtmp "isel" :w fn)))
                (emit :and :w to r0 r1) (emit :flagfo k r1 nil nil) (setf to r0)))
             ((= c 15)
              (let ((r0 (newtmp "isel" :w fn)) (r1 (newtmp "isel" :w fn)))
                (emit :or :w to r0 r1) (emit :flagfuo k r1 nil nil) (setf to r0))))
           (let* ((swap (cmpswap c (ins-arg0 i)))
                  (cc (if (= swap 1) (aref *cmpop-swap* c) c)))
             (emit (aref *flag-ops* cc) k to nil nil)
             (selcmp (ins-arg0 i) (ins-arg1 i) kc swap fn)))))
      ((member op '(:xselieq :xseline :xselisge :xselisgt :xselisle :xselislt
                    :xseliuge :xseliugt :xseliule :xseliult
                    :xselfeq :xselfge :xselfgt :xselfle :xselflt :xselfne
                    :xselfo :xselfuo))
       (sel-emit i fn))
      ((member op '(:sel0 :sel1)) (abi-unsupported "stray sel"))
      ((isload-op op) (sel-load i fn))
      ((isstore-op op) (sel-store i fn))
      ((member op '(:alloc4 :alloc8 :alloc16)) (salloc (ins-to i) (ins-arg0 i) fn))
      ((eq op :uwtof) (sel-uwtof i fn))
      ((eq op :ultof) (sel-ultof i fn))
      ((member op '(:stoui :dtoui)) (abi-unsupported "float->uint conv"))
      (t (abi-unsupported (format nil "isel op ~a" op))))))

;;; --------------------------------------------------------------------- seljmp

(defun flagi (ins)
  "Last flag-setting instruction in INS (a list, program order), skipping
   flag-transparent ops; NIL if an opaque op intervenes (amd64/isel.c flagi)."
  (dolist (i (reverse ins) nil)
    (cond ((op-zflag (ins-op i)) (return i))
          ((op-lflag (ins-op i)))
          (t (return nil)))))

(defun seljmp (b fn)
  (when (eq (blk-jmp-type b) :jnz)
    (let* ((r (blk-jmp-arg b)) (tm r))
      (setf (blk-jmp-arg b) nil)
      (cond
        ((eq (blk-s1 b) (blk-s2 b))
         (chuse r -1) (setf (blk-jmp-type b) :jmp (blk-s2 b) nil))
        (t
         (let ((fi (flagi (blk-ins b))))
           (cond
             ((or (null fi) (not (eq (ins-to fi) r)))
              (selcmp r (getcon 0 fn) :w 0 fn)
              (setf (blk-jmp-type b) (aref *jf-jumps-vec* +cine+)))
             ((multiple-value-bind (c kc) (iscmp (ins-op fi))
                (and c (/= c 10) (/= c 15)   ; not float eq/ne (see sel)
                     (progn
                       (let* ((swap (cmpswap c (ins-arg0 fi)))
                              (cc (if (= swap 1) (aref *cmpop-swap* c) c)))
                         (when (= 1 (tmp-nuse tm))
                           (selcmp (ins-arg0 fi) (ins-arg1 fi) kc swap fn)
                           (setf (ins-op fi) :nop (ins-to fi) nil
                                 (ins-arg0 fi) nil (ins-arg1 fi) nil))
                         (setf (blk-jmp-type b) (aref *jf-jumps-vec* cc)))
                       t))))
             ((and (eq (ins-op fi) :and) (= 1 (tmp-nuse tm))
                   (or (tmp-p (ins-arg0 fi)) (tmp-p (ins-arg1 fi))))
              (setf (ins-op fi) :xtest (ins-to fi) nil
                    (blk-jmp-type b) (aref *jf-jumps-vec* +cine+))
              (when (con-p (ins-arg1 fi)) (rotatef (ins-arg0 fi) (ins-arg1 fi))))
             (t
              (when (= 1 (tmp-nuse tm)) (emit :copy :w nil r nil))
              (setf (blk-jmp-type b) (aref *jf-jumps-vec* +cine+))))))))))

;;; ----------------------------------------------------------------- selsel
;;; amd64/isel.c selsel: turn an ifconvert sel0/sel1 group into conditional
;;; moves (xsel<cc>), taking the condition from the flag-setter before sel0.

(defun selsel (fn b vec k)
  "Lower the sel0/sel1 group ending at VEC[k] (a sel1); return the sel0 index."
  (declare (ignore b))
  (let ((i0 k))
    (loop while (and (> i0 0) (not (eq (ins-op (aref vec i0)) :sel0))) do (decf i0))
    (let* ((sel0 (aref vec i0))
           (r (ins-arg0 sel0)) (rt r)
           (fi (flagi (coerce (subseq vec 0 i0) 'list)))
           (cr0 nil) (cr1 nil) (gencmp nil) (gencpy nil) (swap 0) (kc :w) (c +cine+))
      (cond
        ((or (null fi) (not (eq (ins-to fi) r)))
         (setf gencmp t cr0 r cr1 (getcon 0 fn)))
        ((iscmp (ins-op fi))
         (multiple-value-bind (cc k2) (iscmp (ins-op fi))
           (if (or (= cc 10) (= cc 15))       ; float eq/ne -> checked with Cine
               (when (= 1 (tmp-nuse rt)) (setf gencpy t))
               (progn
                 (setf swap (cmpswap cc (ins-arg0 fi)))
                 (setf c (if (= swap 1) (aref *cmpop-swap* cc) cc) kc k2)
                 (when (= 1 (tmp-nuse rt))
                   (setf gencmp t cr0 (ins-arg0 fi) cr1 (ins-arg1 fi))
                   (setf (ins-op fi) :nop (ins-to fi) nil
                         (ins-arg0 fi) nil (ins-arg1 fi) nil))))))
        ((and (eq (ins-op fi) :and) (= 1 (tmp-nuse rt))
              (or (tmp-p (ins-arg0 fi)) (tmp-p (ins-arg1 fi))))
         (setf (ins-op fi) :xtest (ins-to fi) nil)
         (when (con-p (ins-arg1 fi)) (rotatef (ins-arg0 fi) (ins-arg1 fi))))
        (t (when (= 1 (tmp-nuse rt)) (setf gencpy t))))
      ;; each sel1 (from k down to i0+1) becomes an xsel<c>
      (loop for j from k downto (1+ i0) do
        (setf (ins-op (aref vec j)) (aref *xsel-ops* c))
        (sel (aref vec j) fn))
      (when gencmp (selcmp cr0 cr1 kc swap fn))
      (when gencpy (emit :copy :w nil r nil))
      i0)))

;;; ---------------------------------------------------------------------- simpl
;;; simpl.c runs between abi1 and isel.  The scalar-relevant transform: an
;;; unsigned divide/remainder by a constant power of two becomes a shift/mask.
;;; (blit expansion is deferred — blit isn't in the scalar isel subset.)

(defun ispow2 (v) (and (> v 0) (zerop (logand v (1- v)))))
(defun ulog2 (v) (1- (integer-length v)))

(defun simpl (fn)
  (dolist (b (fn-blocks fn))
    (dolist (i (blk-ins b))
      (when (and (member (ins-op i) '(:udiv :urem))
                 (= 0 (cls-base (ins-cls i)))
                 (con-p (ins-arg1 i)) (eq (con-kind (ins-arg1 i)) :bits)
                 (null (con-flt (ins-arg1 i)))
                 (ispow2 (con-value (ins-arg1 i))))
        (let ((n (ulog2 (con-value (ins-arg1 i)))))
          (if (eq (ins-op i) :urem)
              (setf (ins-op i) :and (ins-arg1 i) (getcon (1- (ash 1 n)) fn))
              (setf (ins-op i) :shr (ins-arg1 i) (getcon n fn))))))))

;;; --------------------------------------------------------------------- driver

(defun assign-fast-locals (fn)
  "amd64_isel prologue: give the leading run of constant-size allocX in the
   start block a stack slot (fn-slot / fn-salign) and nop the instruction.
   A non-constant size stops that alloc class (it becomes a dynamic salloc)."
  (let ((b (fn-start fn)))
    (loop for al in '(:alloc4 :alloc8 :alloc16)
          for n in '(4 8 16)
          for align from 2 do
      (block scan
        (dolist (i (blk-ins b))
          (when (eq (ins-op i) al)
            (unless (con-p (ins-arg0 i)) (return-from scan))
            (let ((sz (con-value (ins-arg0 i))))
              (when (or (< sz 0) (>= sz (- most-positive-fixnum 15)))
                (abi-unsupported "invalid alloc size"))
              (setf sz (truncate (logand (+ sz (1- n)) (- n)) 4))
              (setf (tmp-slot (ins-to i)) (fn-slot fn))
              (incf (fn-slot fn) sz)
              (setf (fn-salign fn) align)
              (setf (ins-op i) :nop (ins-to i) nil
                    (ins-arg0 i) nil (ins-arg1 i) nil))))))))

(defun amd64-isel (fn)
  "amd64 instruction selection (M3/B3 + slice d: addressing modes / fast locals)."
  (assign-fast-locals fn)
  (let ((ntmp (fn-ntmp fn)))
    (dolist (b (fn-blocks fn))
      (let ((*emitted* nil)
            (*num* (let ((v (make-array ntmp)))
                     (dotimes (i ntmp) (setf (aref v i) (make-num))) v)))
        ;; fix up phi arguments coming from this block
        (dolist (s (remove-duplicates (remove nil (list (blk-s1 b) (blk-s2 b)))))
          (dolist (p (blk-phis s))
            (let ((pair (assoc b (phi-args p) :test #'eq)))
              (when pair (setf (cdr pair) (fixarg (cdr pair) :copy (phi-cls p) fn))))))
        (anumber *num* b)
        (seljmp b fn)
        (let* ((vec (coerce (blk-ins b) 'vector)) (k (1- (length vec))))
          (loop while (>= k 0) do
            (let ((i (aref vec k)))
              (if (eq (ins-op i) :sel1)
                  (setf k (1- (selsel fn b vec k)))
                  (progn (sel i fn) (decf k))))))
        (setf (blk-ins b) *emitted*)))))
