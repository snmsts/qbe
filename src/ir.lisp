;;;; ir.lisp --- IR data model
;;;;
;;;; DESIGN.md §4: structural graph nodes are CLOS classes (later passes
;;;; dispatch / extend on them); leaf value objects (tmp, con) are structs.
;;;;
;;;; Operands ("Ref" in QBE) are represented directly as Lisp values, not as
;;;; tagged array indices:
;;;;   NIL      -> R (no operand)
;;;;   tmp      -> RTmp
;;;;   con      -> RCon
;;;;   typ      -> RType
;;;;   integer  -> RInt   (blit size, dbgloc line/col)

(in-package #:qbe)

(defclass module ()
  ((funcs :initform nil :accessor module-funcs
          :documentation "Functions, in source order.")
   (types :initform (make-hash-table :test 'equal) :accessor module-types
          :documentation "Aggregate type name -> typ.")))

(defclass typ ()
  ((name    :initarg :name :accessor typ-name)
   ;; aggregate layout (parse.c parsetyp), needed by the amd64 SysV classifier.
   (isdark  :initform nil :accessor typ-isdark)   ; opaque (size only)
   (isunion :initform nil :accessor typ-isunion)
   (align   :initform -1  :accessor typ-align)    ; log2 alignment
   (size    :initform 0   :accessor typ-size)
   (nunion  :initform 0   :accessor typ-nunion)
   ;; fields: vector of NUNION variants; each variant a vector of (ftype . len)
   ;; where ftype is :b/:h/:w/:l/:s/:d/:pad/:typ and len is a byte count (or the
   ;; referenced typ object for :typ).
   (fields  :initform nil :accessor typ-fields)))

(defclass fn ()
  ((name     :initarg :name     :accessor fn-name)
   (export   :initarg :export   :initform nil :accessor fn-export)
   ;; Return class: one of :w :l :s :d :sb :ub :sh :uh :c, or :0 for void.
   (retclass :initarg :retclass :initform :0  :accessor fn-retclass)
   (rettyp   :initarg :rettyp   :initform nil :accessor fn-rettyp) ; typ when retclass :c
   (vararg   :initarg :vararg   :initform nil :accessor fn-vararg)
   (blocks   :initform nil :accessor fn-blocks :documentation "Blocks in order.")
   (start    :initform nil :accessor fn-start)
   ;; temp registry: adjustable vector, id -> tmp (fill-pointer = ntmp).
   (tmp      :initform nil :accessor fn-tmp)
   ;; constant intern table: con-key -> con (shared with parse; getcon interns).
   (cons     :initform nil :accessor fn-cons)
   (ncon     :initform 0   :accessor fn-ncon)
   ;; analysis (filled by cfg.lisp)
   (rpo      :initform nil :accessor fn-rpo  :documentation "Vector: rpo-id -> blk.")
   (nblk     :initform 0   :accessor fn-nblk)
   ;; backend (spill/rega): stack-slot bytes, used-register mask, RMem table
   (slot     :initform 0   :accessor fn-slot)
   (reg      :initform 0   :accessor fn-reg)
   (mem      :initform nil :accessor fn-mem)
   (salign   :initform 0   :accessor fn-salign)
   (dynalloc :initform nil :accessor fn-dynalloc)
   (retr     :initform nil :accessor fn-retr)   ; hidden struct-return pointer (abi)
   (regs?    :initform nil :accessor fn-regs? :documentation "materialize-regs done?")))

(defun fn-ntmp (fn) (fill-pointer (fn-tmp fn)))

(defclass blk ()
  ((name     :initarg :name :accessor blk-name)
   (phis     :initform nil :accessor blk-phis)   ; list of phi, in order
   (ins      :initform nil :accessor blk-ins)    ; list of ins, in order
   ;; Terminator: jmp-type is a keyword (:jmp :jnz :hlt or a :ret* form).
   (jmp-type :initform nil :accessor blk-jmp-type)
   (jmp-arg  :initform nil :accessor blk-jmp-arg)
   (s1       :initform nil :accessor blk-s1)      ; successor blks
   (s2       :initform nil :accessor blk-s2)
   (link     :initform nil :accessor blk-link)    ; next block in layout order
   ;; analysis (filled by cfg.lisp)
   (id       :initform -1  :accessor blk-id       :documentation "Reverse-postorder index.")
   (preds    :initform nil :accessor blk-preds)
   (idom     :initform nil :accessor blk-idom)
   (doms     :initform nil :accessor blk-doms     :documentation "Immediate-dominated children.")
   (fron     :initform nil :accessor blk-fron     :documentation "Dominance frontier.")
   ;; GCM: dominator-tree depth + loop weight (cfg.c filldepth/fillloop).
   (depth    :initform -1  :accessor blk-depth)
   (loop     :initform 1   :accessor blk-loop)
   ;; liveness (filled by fill-live, ssa.lisp): temp-id bitsets + counts.
   (in       :initform nil :accessor blk-in)
   (out      :initform nil :accessor blk-out)
   (gen      :initform nil :accessor blk-gen)
   (nlive    :initform nil :accessor blk-nlive)
   (visit    :initform 0   :accessor blk-visit    :documentation "Scratch for phiins.")))

(defclass ins ()
  ((op   :initarg :op   :accessor ins-op)     ; opcode keyword
   (cls  :initarg :cls  :initform :w :accessor ins-cls)
   (to   :initarg :to   :initform nil :accessor ins-to)
   (arg0 :initarg :arg0 :initform nil :accessor ins-arg0)
   (arg1 :initarg :arg1 :initform nil :accessor ins-arg1)))

(defclass phi ()
  ((to   :initarg :to   :accessor phi-to)
   (cls  :initarg :cls  :accessor phi-cls)
   (args :initarg :args :accessor phi-args)   ; list of (blk . ref)
   (visit :initform 0   :accessor phi-visit))) ; scratch for copy.c width analysis

(defstruct (tmp (:constructor make-tmp (name &optional id)))
  name
  (id 0)
  ;; usage/analysis info, filled by fill-use / phiins / renblk (ssa.lisp)
  (cls   :w)
  (def   nil)                ; defining ins, or NIL
  (bid   -1)                 ; defining block id
  (ndef  0)
  (nuse  0)
  (use   nil)               ; list of use-rec
  (phi   nil)               ; phi-class union-find parent (temp id), or NIL
  (width 0)                 ; copy.c width lattice: 0=WFull, 1..6=W{s,u}{b,h,w}
  (gcmbid -1)               ; GCM target block rpo id (-1 = NOBID)
  (visit nil)               ; SSA-rename tag / GCM visited flag; rega: reg or -1
  ;; backend (spill/rega): spill cost, stack slot, and register hint
  (cost 0)                  ; spill cost (fillcost); UINT_MAX-ish for regs
  (slot -1)                 ; assigned stack slot, -1 = unset
  (hint-r -1)               ; preferred register, -1 = none
  (hint-w 0)                ; hint weight (loop level of last set)
  (hint-m 0)                ; bitmask of registers to avoid
  (alias nil))              ; alias analysis (alias.c); filled by fill-alias

(defstruct (use-rec (:constructor make-use-rec (type bid payload)))
  type                       ; :phi :ins :jmp
  bid
  payload)                   ; the phi or ins, or NIL for :jmp

;;; Backend value refs introduced by ABI lowering / isel (mirrors QBE's
;;; RTmp-with-id<Tmp0, RCall, RSlot).  printref renders reg as "R<id>",
;;; call-ref as a 4-hex mask, slot-ref as "S<n>".
(defstruct (reg (:constructor make-reg (id name &optional (cls :l))))
  id                         ; QBE register id (RAX=1 .. XMM15=32)
  name                       ; asm mnemonic (for emit)
  cls)
(defstruct (call-ref (:constructor make-call-ref (val))) val)  ; RCall bitmask
(defstruct (slot-ref (:constructor make-slot-ref (n))) n)      ; RSlot

;;; RMem: an amd64 addressing mode `[offset + base + scale*index]` (Addr in
;;; all.h), introduced by isel's seladdr.  offset is a con (or NIL = CUndef),
;;; base/index are refs (tmp/reg/slot-ref, or NIL = R), scale an integer.
;;; The struct is itself used as the operand (like con/tmp/reg), so QBE's
;;; `fn->mem` index array is unnecessary.
(defstruct (mem (:constructor make-mem (&key offset base index (scale 1))))
  offset base index (scale 1))

;;; kind: :bits | :addr | :undef
;;;   :bits -> value is an integer (flt NIL) or float; flt is NIL/1/2 (s/d).
;;;   :addr -> symname string, symtype a list of (:ext :thr), off integer.
(defstruct (con (:constructor make-con))
  kind
  value
  (flt nil)
  symname
  (symtype nil)
  (off 0)
  (idx nil))     ; interning order (QBE con index); for rcmp ordering
