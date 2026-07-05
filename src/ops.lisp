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
