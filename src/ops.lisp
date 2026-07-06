;;;; ops.lisp --- opcode data, transliterated from QBE's ops.h
;;;;
;;;; DESIGN decision (see DESIGN.md §4.1): opcodes are NOT CLOS subclasses.
;;;; QBE itself keeps `Ins` a single struct with an `op` field + a shared
;;;; property table `optab[]`.  We mirror that: an opcode is a keyword and
;;;; its properties live in a data table.  M0 only needs names + the
;;;; keyword-recognition table for the parser and the print-name mapping.

(in-package #:qbe)

;;; Public operations a user may write as instructions (ops.h, before Onop).
;;; Order preserved for reference; only names matter at M0.
(defparameter *public-op-names*
  '("add" "sub" "neg" "div" "rem" "udiv" "urem" "mul"
    "and" "or" "xor" "sar" "shr" "shl"
    "ceqw" "cnew" "csgew" "csgtw" "cslew" "csltw" "cugew" "cugtw" "culew" "cultw"
    "ceql" "cnel" "csgel" "csgtl" "cslel" "csltl" "cugel" "cugtl" "culel" "cultl"
    "ceqs" "cges" "cgts" "cles" "clts" "cnes" "cos" "cuos"
    "ceqd" "cged" "cgtd" "cled" "cltd" "cned" "cod" "cuod"
    "storeb" "storeh" "storew" "storel" "stores" "stored"
    "loadsb" "loadub" "loadsh" "loaduh" "loadsw" "loaduw" "load"
    "extsb" "extub" "extsh" "extuh" "extsw" "extuw"
    "exts" "truncd" "stosi" "stoui" "dtosi" "dtoui"
    "swtof" "uwtof" "sltof" "ultof" "cast"
    "alloc4" "alloc8" "alloc16"
    "vaarg" "vastart"
    "copy"
    "dbgloc"))

;;; Token-level aliases the parser normalizes at parse time (parse.c parseline).
;;; alias-name -> final op keyword.
(defparameter *op-aliases*
  '(("loadw" . :loadsw)
    ("loadl" . :load)
    ("loads" . :load)
    ("loadd" . :load)
    ("alloc1" . :alloc4)
    ("alloc2" . :alloc4)))

;;; name string -> op keyword, for the generic-instruction parse path.
;;; (phi / call / blit are handled specially by the parser, not here.)
(defparameter *writable-op*
  (let ((h (make-hash-table :test 'equal)))
    (dolist (n *public-op-names*)
      (setf (gethash n h) (intern (string-upcase n) :keyword)))
    (loop for (name . kw) in *op-aliases* do (setf (gethash name h) kw))
    h))

(defun writable-op (name)
  "Op keyword for an instruction mnemonic NAME, or NIL if not a known op."
  (values (gethash name *writable-op*)))

(defun op-name (op-keyword)
  "The textual mnemonic printed for an op keyword (matches optab[].name)."
  (string-downcase (symbol-name op-keyword)))

;;; Result-less ops that printfn suffixes with the class char (ktoc[cls]).
;;; Of these only :arg occurs pre-isel; the rest are backend-generated.
(defparameter *classchar-ops*
  '(:arg :swap :xcmp :acmp :acmn :afcmp :xtest :xdiv :xidiv))

(defun classchar-op-p (op) (and (member op *classchar-ops*) t))

;;; Value classes.  Keywords mirror Kw/Kl/Ks/Kd and the sub-word/aggregate
;;; classes used by params/args/returns.
(defun class-char (cls)
  "The ktoc[] character for a base class."
  (ecase cls (:w #\w) (:l #\l) (:s #\s) (:d #\d)))

;;; ------------------------------------------------------- op property table
;;; The `Op optab[]` of ops.h/all.h: per-opcode argument classes + the boolean
;;; flags the mid-end passes read.  argcls0/1 are indexed by result class
;;; (:w=0 :l=1 :s=2 :d=3) and hold a class keyword or :e (none) / :m (memory)
;;; / :x (any).  Rows are transliterated verbatim from ops.h:
;;;   (:op (a0.w a0.l a0.s a0.d) (a1...) canfold hasid idval commutes assoc
;;;        idemp cmpeqwl cmplgtewl eqval pinned)

(defstruct (opdesc (:constructor %make-opdesc))
  argcls0 argcls1
  canfold hasid idval commutes assoc idemp cmpeqwl cmplgtewl eqval pinned)

(defparameter *optab-data*
  '((:add (:w :l :s :d) (:w :l :s :d) 1 1 0 1 1 0 0 0 0 0)
    (:sub (:w :l :s :d) (:w :l :s :d) 1 1 0 0 0 0 0 0 0 0)
    (:neg (:w :l :s :d) (:x :x :x :x) 1 0 0 0 0 0 0 0 0 0)
    (:div (:w :l :s :d) (:w :l :s :d) 1 1 1 0 0 0 0 0 0 0)
    (:rem (:w :l :e :e) (:w :l :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:udiv (:w :l :e :e) (:w :l :e :e) 1 1 1 0 0 0 0 0 0 0)
    (:urem (:w :l :e :e) (:w :l :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:mul (:w :l :s :d) (:w :l :s :d) 1 1 1 1 0 0 0 0 0 0)
    (:and (:w :l :e :e) (:w :l :e :e) 1 0 0 1 1 1 0 0 0 0)
    (:or (:w :l :e :e) (:w :l :e :e) 1 1 0 1 1 1 0 0 0 0)
    (:xor (:w :l :e :e) (:w :l :e :e) 1 1 0 1 1 0 0 0 0 0)
    (:sar (:w :l :e :e) (:w :w :e :e) 1 1 0 0 0 0 0 0 0 0)
    (:shr (:w :l :e :e) (:w :w :e :e) 1 1 0 0 0 0 0 0 0 0)
    (:shl (:w :l :e :e) (:w :w :e :e) 1 1 0 0 0 0 0 0 0 0)
    (:ceqw (:w :w :e :e) (:w :w :e :e) 1 1 1 1 0 0 1 0 1 0)
    (:cnew (:w :w :e :e) (:w :w :e :e) 1 1 0 1 0 0 1 0 0 0)
    (:csgew (:w :w :e :e) (:w :w :e :e) 1 0 0 0 0 0 0 1 1 0)
    (:csgtw (:w :w :e :e) (:w :w :e :e) 1 0 0 0 0 0 0 1 0 0)
    (:cslew (:w :w :e :e) (:w :w :e :e) 1 0 0 0 0 0 0 1 1 0)
    (:csltw (:w :w :e :e) (:w :w :e :e) 1 0 0 0 0 0 0 1 0 0)
    (:cugew (:w :w :e :e) (:w :w :e :e) 1 0 0 0 0 0 0 1 1 0)
    (:cugtw (:w :w :e :e) (:w :w :e :e) 1 0 0 0 0 0 0 1 0 0)
    (:culew (:w :w :e :e) (:w :w :e :e) 1 0 0 0 0 0 0 1 1 0)
    (:cultw (:w :w :e :e) (:w :w :e :e) 1 0 0 0 0 0 0 1 0 0)
    (:ceql (:l :l :e :e) (:l :l :e :e) 1 0 0 1 0 0 1 0 1 0)
    (:cnel (:l :l :e :e) (:l :l :e :e) 1 0 0 1 0 0 1 0 0 0)
    (:csgel (:l :l :e :e) (:l :l :e :e) 1 0 0 0 0 0 0 1 1 0)
    (:csgtl (:l :l :e :e) (:l :l :e :e) 1 0 0 0 0 0 0 1 0 0)
    (:cslel (:l :l :e :e) (:l :l :e :e) 1 0 0 0 0 0 0 1 1 0)
    (:csltl (:l :l :e :e) (:l :l :e :e) 1 0 0 0 0 0 0 1 0 0)
    (:cugel (:l :l :e :e) (:l :l :e :e) 1 0 0 0 0 0 0 1 1 0)
    (:cugtl (:l :l :e :e) (:l :l :e :e) 1 0 0 0 0 0 0 1 0 0)
    (:culel (:l :l :e :e) (:l :l :e :e) 1 0 0 0 0 0 0 1 1 0)
    (:cultl (:l :l :e :e) (:l :l :e :e) 1 0 0 0 0 0 0 1 0 0)
    (:ceqs (:s :s :e :e) (:s :s :e :e) 1 0 0 1 0 0 0 0 0 0)
    (:cges (:s :s :e :e) (:s :s :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:cgts (:s :s :e :e) (:s :s :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:cles (:s :s :e :e) (:s :s :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:clts (:s :s :e :e) (:s :s :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:cnes (:s :s :e :e) (:s :s :e :e) 1 0 0 1 0 0 0 0 0 0)
    (:cos (:s :s :e :e) (:s :s :e :e) 1 0 0 1 0 0 0 0 0 0)
    (:cuos (:s :s :e :e) (:s :s :e :e) 1 0 0 1 0 0 0 0 0 0)
    (:ceqd (:d :d :e :e) (:d :d :e :e) 1 0 0 1 0 0 0 0 0 0)
    (:cged (:d :d :e :e) (:d :d :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:cgtd (:d :d :e :e) (:d :d :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:cled (:d :d :e :e) (:d :d :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:cltd (:d :d :e :e) (:d :d :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:cned (:d :d :e :e) (:d :d :e :e) 1 0 0 1 0 0 0 0 0 0)
    (:cod (:d :d :e :e) (:d :d :e :e) 1 0 0 1 0 0 0 0 0 0)
    (:cuod (:d :d :e :e) (:d :d :e :e) 1 0 0 1 0 0 0 0 0 0)
    (:storeb (:w :e :e :e) (:m :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:storeh (:w :e :e :e) (:m :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:storew (:w :e :e :e) (:m :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:storel (:l :e :e :e) (:m :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:stores (:s :e :e :e) (:m :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:stored (:d :e :e :e) (:m :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:loadsb (:m :m :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:loadub (:m :m :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:loadsh (:m :m :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:loaduh (:m :m :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:loadsw (:m :m :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:loaduw (:m :m :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:load (:m :m :m :m) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:extsb (:w :w :e :e) (:x :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:extub (:w :w :e :e) (:x :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:extsh (:w :w :e :e) (:x :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:extuh (:w :w :e :e) (:x :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:extsw (:e :w :e :e) (:e :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:extuw (:e :w :e :e) (:e :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:exts (:e :e :e :s) (:e :e :e :x) 1 0 0 0 0 0 0 0 0 0)
    (:truncd (:e :e :d :e) (:e :e :x :e) 1 0 0 0 0 0 0 0 0 0)
    (:stosi (:s :s :e :e) (:x :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:stoui (:s :s :e :e) (:x :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:dtosi (:d :d :e :e) (:x :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:dtoui (:d :d :e :e) (:x :x :e :e) 1 0 0 0 0 0 0 0 0 0)
    (:swtof (:e :e :w :w) (:e :e :x :x) 1 0 0 0 0 0 0 0 0 0)
    (:uwtof (:e :e :w :w) (:e :e :x :x) 1 0 0 0 0 0 0 0 0 0)
    (:sltof (:e :e :l :l) (:e :e :x :x) 1 0 0 0 0 0 0 0 0 0)
    (:ultof (:e :e :l :l) (:e :e :x :x) 1 0 0 0 0 0 0 0 0 0)
    (:cast (:s :d :w :l) (:x :x :x :x) 1 0 0 0 0 0 0 0 0 0)
    (:alloc4 (:e :l :e :e) (:e :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:alloc8 (:e :l :e :e) (:e :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:alloc16 (:e :l :e :e) (:e :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:vaarg (:m :m :m :m) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:vastart (:m :e :e :e) (:x :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:copy (:w :l :s :d) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 0)
    (:dbgloc (:w :e :e :e) (:w :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:nop (:x :x :x :x) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 0)
    (:addr (:m :m :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:blit0 (:m :e :e :e) (:m :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:blit1 (:w :e :e :e) (:x :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:sel0 (:w :e :e :e) (:x :e :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:sel1 (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:swap (:w :l :s :d) (:w :l :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:sign (:w :l :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:salloc (:e :l :e :e) (:e :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xidiv (:w :l :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xdiv (:w :l :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xcmp (:w :l :s :d) (:w :l :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:xtest (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:acmp (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:acmn (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:afcmp (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:reqz (:w :l :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:rnez (:w :l :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:par (:x :x :x :x) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:parsb (:x :x :x :x) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:parub (:x :x :x :x) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:parsh (:x :x :x :x) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:paruh (:x :x :x :x) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:parc (:e :x :e :e) (:e :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:pare (:e :x :e :e) (:e :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:arg (:w :l :s :d) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:argsb (:w :e :e :e) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:argub (:w :e :e :e) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:argsh (:w :e :e :e) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:arguh (:w :e :e :e) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:argc (:e :x :e :e) (:e :l :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:arge (:e :l :e :e) (:e :x :e :e) 0 0 0 0 0 0 0 0 0 1)
    (:argv (:x :x :x :x) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    (:call (:m :m :m :m) (:x :x :x :x) 0 0 0 0 0 0 0 0 0 1)
    ;; isel-internal flag-setting ops (result of a compare feeding a value).
    (:flagieq  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagine  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagisge (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagisgt (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagisle (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagislt (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagiuge (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagiugt (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagiule (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagiult (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagfeq  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagfge  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagfgt  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagfle  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagflt  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagfne  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagfo   (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:flagfuo  (:x :x :e :e) (:x :x :e :e) 0 0 0 0 0 0 0 0 0 0)
    ;; isel-internal conditional-select (cmov) ops.
    (:xselieq  (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xseline  (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xselisge (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xselisgt (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xselisle (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xselislt (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xseliuge (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xseliugt (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xseliule (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xseliult (:w :l :e :e) (:w :l :e :e) 0 0 0 0 0 0 0 0 0 0)
    (:xselfeq  (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:xselfge  (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:xselfgt  (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:xselfle  (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:xselflt  (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:xselfne  (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:xselfo   (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0)
    (:xselfuo  (:e :e :s :d) (:e :e :s :d) 0 0 0 0 0 0 0 0 0 0))
  "ops.h optab rows.  (Remaining isel-internal ops are omitted; not needed
pre-isel.)")

(defparameter *optab*
  (let ((h (make-hash-table :test 'eq)))
    (dolist (row *optab-data* h)
      (destructuring-bind (name a0 a1 cf hi id co as im ic lg cv pn) row
        (setf (gethash name h)
              (%make-opdesc
               :argcls0 (coerce a0 'vector) :argcls1 (coerce a1 'vector)
               :canfold (= cf 1) :hasid (= hi 1) :idval id
               :commutes (= co 1) :assoc (= as 1) :idemp (= im 1)
               :cmpeqwl (= ic 1) :cmplgtewl (= lg 1) :eqval cv :pinned (= pn 1)))))))

(defun opdesc (op)
  (or (gethash op *optab*) (error "qbe: no optab entry for ~s" op)))

(defun op-canfold   (op) (opdesc-canfold   (opdesc op)))
(defun op-hasid     (op) (opdesc-hasid     (opdesc op)))
(defun op-idval     (op) (opdesc-idval     (opdesc op)))   ; 0/1 value
(defun op-commutes  (op) (opdesc-commutes  (opdesc op)))
(defun op-assoc     (op) (opdesc-assoc     (opdesc op)))
(defun op-idemp     (op) (opdesc-idemp     (opdesc op)))
(defun op-cmpeqwl   (op) (opdesc-cmpeqwl   (opdesc op)))
(defun op-cmplgtewl (op) (opdesc-cmplgtewl (opdesc op)))
(defun op-eqval     (op) (opdesc-eqval     (opdesc op)))   ; 0/1 value
(defun op-pinned    (op) (opdesc-pinned    (opdesc op)))

(defun cls-idx (cls) (ecase cls (:w 0) (:l 1) (:s 2) (:d 3)))

(defun argcls (op cls n)
  "Class of arg N (0/1) of an OP whose result class is CLS (mirrors argcls())."
  (aref (if (zerop n) (opdesc-argcls0 (opdesc op)) (opdesc-argcls1 (opdesc op)))
        (cls-idx cls)))
