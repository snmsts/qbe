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
  ((name :initarg :name :accessor typ-name)))

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
   ;; analysis (filled by cfg.lisp)
   (rpo      :initform nil :accessor fn-rpo  :documentation "Vector: rpo-id -> blk.")
   (nblk     :initform 0   :accessor fn-nblk)))

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
   (args :initarg :args :accessor phi-args)))  ; list of (blk . ref)

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
  (width :full)
  (visit nil))              ; SSA-rename tag: original temp id, or NIL

(defstruct (use-rec (:constructor make-use-rec (type bid payload)))
  type                       ; :phi :ins :jmp
  bid
  payload)                   ; the phi or ins, or NIL for :jmp

;;; kind: :bits | :addr | :undef
;;;   :bits -> value is an integer (flt NIL) or float; flt is NIL/1/2 (s/d).
;;;   :addr -> symname string, symtype a list of (:ext :thr), off integer.
(defstruct (con (:constructor make-con))
  kind
  value
  (flt nil)
  symname
  (symtype nil)
  (off 0))
