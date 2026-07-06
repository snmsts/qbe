;;;; gvn.lisp --- global value numbering (M2/C3), mirrors gvn.c
;;;;
;;;; INCREMENTAL: this first slice implements `normins` (the canonicalization
;;;; QBE applies to every instruction: 32-bit constant truncation for narrow
;;;; arg classes + commutative operand ordering) and the gvn driver skeleton.
;;;; copy propagation (copyref), constant folding (foldref), CSE (gvndup),
;;;; phi dedup (dedupphi), jnz simplification (dedupjmp), and narrowpars are
;;;; added in later slices.  Oracle: `qbe -dG` "> After GVN:".

(in-package #:qbe)

;;; class code + KWIDE (all.h: Kx=-1 Kw=0 Kl=1 Ks=2 Kd=3; parse.c Ke=-2 Km=Kl)
(defun cls-code (k) (ecase k (:w 0) (:l 1) (:s 2) (:d 3) (:x -1) (:e -2) (:m 1)))
(defun kwide (k) (= 1 (logand (cls-code k) 1)))

(defun isconbits (r)
  "Integer value of R if it is an integer bits constant, else NIL."
  (and (con-p r) (eq (con-kind r) :bits) (null (con-flt r)) (con-value r)))

(defun getcon (v fn)
  "Intern the integer constant V (mirrors getcon(): dedup by value)."
  (let* ((v (norm-i64 v)) (key (list :bits v)))
    (or (gethash key (fn-cons fn))
        (let ((c (make-con :kind :bits :value v :idx (fn-ncon fn))))
          (incf (fn-ncon fn))
          (setf (gethash key (fn-cons fn)) c)))))

;;; rcmp: order refs by (type, val); RTmp(0) sorts before RCon(1), so the
;;; canonical commutative form keeps a temp in arg[0] and a constant in arg[1].
(defun ref-rank (r) (cond ((tmp-p r) 0) ((con-p r) 1) (t 2)))
(defun ref-val (r) (cond ((tmp-p r) (tmp-id r)) ((con-p r) (or (con-idx r) 0)) (t 0)))
(defun rcmp (a b)
  (if (/= (ref-rank a) (ref-rank b))
      (- (ref-rank a) (ref-rank b))
      (- (ref-val a) (ref-val b))))

(defun ins-arg (i n) (if (zerop n) (ins-arg0 i) (ins-arg1 i)))
(defun (setf ins-arg) (v i n) (if (zerop n) (setf (ins-arg0 i) v) (setf (ins-arg1 i) v)))

(defun normins (fn i)
  "Canonicalize instruction I in place (gvn.c normins)."
  ;; truncate constant bits to 32 for narrow (non-KWIDE) argument classes
  (dotimes (n 2)
    (let ((arg (ins-arg i n)))
      (when (and arg (not (kwide (argcls (ins-op i) (ins-cls i) n))))
        (let ((v (isconbits arg)))
          (when (and v (/= (logand v #xffffffff) v))
            (setf (ins-arg i n) (getcon (logand v #xffffffff) fn)))))))
  ;; order commutative operands: arg[0] <= arg[1]
  (when (and (op-commutes (ins-op i)) (ins-arg0 i) (ins-arg1 i)
             (> (rcmp (ins-arg0 i) (ins-arg1 i)) 0))
    (rotatef (ins-arg0 i) (ins-arg1 i))))

;;; ------------------------------------------------------- use rewriting
(defvar *con01* #(nil nil) "getcon 0 / 1 for the current fn (copyref identities).")

(defun add-use (tm type b payload)
  (incf (tmp-nuse tm))
  (push (make-use-rec type (blk-id b) payload) (tmp-use tm)))

(defun replaceuse (fn u r1 r2)
  "Rewrite one use U of R1 to R2 (gvn.c replaceuse)."
  (let ((b (aref (fn-rpo fn) (use-rec-bid u)))
        (t2 (when (tmp-p r2) r2)))
    (ecase (use-rec-type u)
      (:phi (let ((p (use-rec-payload u)))
              (setf (phi-args p)
                    (mapcar (lambda (pair) (if (eq (cdr pair) r1) (cons (car pair) r2) pair))
                            (phi-args p)))
              (when t2 (add-use t2 :phi b p))))
      (:ins (let ((i (use-rec-payload u)))
              (when (eq (ins-arg0 i) r1) (setf (ins-arg0 i) r2))
              (when (eq (ins-arg1 i) r1) (setf (ins-arg1 i) r2))
              (when t2 (add-use t2 :ins b i))))
      (:jmp (when (eq (blk-jmp-arg b) r1) (setf (blk-jmp-arg b) r2))
            (when t2 (add-use t2 :jmp b nil))))))

(defun replaceuses (fn r1 r2)
  (let ((t1 (aref (fn-tmp fn) (tmp-id r1))))
    (dolist (u (tmp-use t1)) (replaceuse fn u r1 r2))
    (setf (tmp-nuse t1) 0 (tmp-use t1) nil)))

(defun killins (fn i r)
  (replaceuses fn (ins-to i) r)
  (setf (ins-op i) :nop (ins-cls i) :w (ins-to i) nil (ins-arg0 i) nil (ins-arg1 i) nil))

;;; ----------------------------------------------------------- copyref
;;; copy.c copyref, core cases (width-analysis/zeroval/and-mask deferred).

(defun copyref (fn b i)
  (let ((op (ins-op i)) (a0 (ins-arg0 i)) (a1 (ins-arg1 i)) (cls (ins-cls i)))
    (block nil
      (when (eq op :copy) (return a0))
      ;; op identity value: x+0, x*1, x|0, ...  (integer only; the cmpeqwl `x==1`
      ;; case needs isw1 width analysis, deferred — skip it here)
      (when (and (op-hasid op) (= (cls-base cls) 0)
                 (eq a1 (aref *con01* (op-idval op)))
                 (not (op-cmpeqwl op)))
        (return a0))
      ;; idempotent with identical args: x&x, x|x
      (when (and (op-idemp op) (eq a0 a1)) (return a0))
      ;; integer cmp with identical args -> eqval
      (when (and (or (op-cmpeqwl op) (op-cmplgtewl op)) (eq a0 a1))
        (return (aref *con01* (op-eqval op))))
      ;; cmp eq/ne 0 where the operand is provably 0/non-0 at this point
      (when (and (op-cmpeqwl op) (eq a1 (aref *con01* 0)))
        (multiple-value-bind (found z) (zeroval fn b a0 (argcls op cls 0))
          (when found (return (aref *con01* (logxor (op-eqval op) z 1))))))
      ;; extsw/extuw producing a w result is a copy
      (when (and (eq cls :w) (member op '(:extsw :extuw))) (return a0))
      nil)))

;;; ----------------------------------------------------------- foldref
;;; fold.c: constant-fold an instruction whose args are all constants into a
;;; single con.  foldint handles integer arithmetic, ext/conv-from-float, and
;;; all comparisons (integer AND float — cmps return a w/l result so they go
;;; through the integer path); foldflt handles float arithmetic + int->float.

(defun newcon (c fn)
  "Intern a fully-formed con C (newcon(): dedup by con-key, assign idx)."
  (let ((key (con-key c)))
    (or (gethash key (fn-cons fn))
        (progn (setf (con-idx c) (fn-ncon fn)) (incf (fn-ncon fn))
               (setf (gethash key (fn-cons fn)) c)))))

(defun u32 (x) (logand x #xffffffff))
(defun u64* (x) (logand x #xffffffffffffffff))
(defun s32* (x) (let ((v (u32 x))) (if (>= v #x80000000) (- v #x100000000) v)))
(defun s64* (x) (norm-i64 x))

(defun bits->single (u) (sb-kernel:make-single-float (s32* u)))
(defun bits->double (u)
  (sb-kernel:make-double-float (s32* (ash (u64* u) -32)) (u32 u)))

(defun con-ibits (c)
  "The 64-bit integer union payload bits.i of con C (offset for addr)."
  (ecase (con-kind c)
    (:addr (con-off c))
    (:bits (con-rawbits c))))

(defun symeq (a b)
  (and (equal (con-symname a) (con-symname b))
       (equal (con-symtype a) (con-symtype b))))

(defun iscon= (c w k)
  "Does con C's payload equal K at width W (t=64b / nil=32b)?  (fold.c iscon)"
  (let ((v (con-ibits c))) (if w (= (u64* v) (u64* k)) (= (u32 v) (u32 k)))))

(defun word-cmp-p (op)
  (member op '(:ceqw :cnew :csgew :csgtw :cslew :csltw
               :cugew :cugtw :culew :cultw)))
(defun int-cmp-p (op)
  (or (word-cmp-p op)
      (member op '(:ceql :cnel :csgel :csgtl :cslel :csltl
                   :cugel :cugtl :culel :cultl))))
(defun flt-cmp-p (op)
  (member op '(:ceqs :cges :cgts :cles :clts :cnes :cos :cuos
               :ceqd :cged :cgtd :cled :cltd :cned :cod :cuod)))

(defun icmp-result (op lu ls ru rs)
  (if (case op
        ((:ceqw :ceql) (= lu ru))
        ((:cnew :cnel) (/= lu ru))
        ((:csgew :csgel) (>= ls rs))
        ((:csgtw :csgtl) (> ls rs))
        ((:cslew :cslel) (<= ls rs))
        ((:csltw :csltl) (< ls rs))
        ((:cugew :cugel) (>= lu ru))
        ((:cugtw :cugtl) (> lu ru))
        ((:culew :culel) (<= lu ru))
        ((:cultw :cultl) (< lu ru)))
      1 0))

(defun fcmp-result (op lf rf)
  (if (case op
        ((:ceqs :ceqd) (= lf rf))
        ((:cnes :cned) (/= lf rf))
        ((:cges :cged) (>= lf rf))
        ((:cgts :cgtd) (> lf rf))
        ((:cles :cled) (<= lf rf))
        ((:clts :cltd) (< lf rf))
        ((:cos :cod)   (or (< lf rf) (>= lf rf)))       ; ordered (neither NaN)
        ((:cuos :cuod) (not (or (< lf rf) (>= lf rf)))))  ; unordered
      1 0))

(defun foldint (op w cl cr)
  "Fold integer/compare OP on cons CL,CR.  Returns (values ok x typ sym symt);
   ok=NIL means non-foldable (address illegality or div-by-zero)."
  (let ((cladr (eq (con-kind cl) :addr))
        (cradr (eq (con-kind cr) :addr))
        (typ :bits) (sym nil) (symt nil))
    ;; address-arithmetic legality (fold.c head)
    (cond
      ((eq op :add)
       (cond (cladr (when cradr (return-from foldint (values nil)))
                    (setf typ :addr sym (con-symname cl) symt (con-symtype cl)))
             (cradr (setf typ :addr sym (con-symname cr) symt (con-symtype cr)))))
      ((eq op :sub)
       (cond (cladr (if cradr
                        (unless (symeq cl cr) (return-from foldint (values nil)))
                        (setf typ :addr sym (con-symname cl) symt (con-symtype cl))))
             (cradr (return-from foldint (values nil)))))
      ((or cladr cradr) (return-from foldint (values nil))))
    ;; div/rem guards
    (when (member op '(:div :rem :udiv :urem))
      (when (iscon= cr w 0) (return-from foldint (values nil)))
      (when (member op '(:div :rem))
        (when (and (iscon= cr w -1)
                   (iscon= cl w (if w #x-8000000000000000 #x-80000000)))
          (return-from foldint (values nil)))))
    (let* ((la (con-ibits cl)) (ra (con-ibits cr))
           (lu (u64* la)) (ru (u64* ra))
           (ls (s64* la)) (rs (s64* ra))
           (mask (if w 63 31))
           (x
            (cond
              ((int-cmp-p op)
               (if (word-cmp-p op)
                   (icmp-result op (u64* (s32* la)) (s32* la) (u64* (s32* ra)) (s32* ra))
                   (icmp-result op lu ls ru rs)))
              ((flt-cmp-p op)
               (fcmp-result op (con-value cl) (con-value cr)))
              (t
               (ecase op
                 (:add (+ lu ru)) (:sub (- lu ru)) (:neg (- lu))
                 (:mul (* lu ru)) (:and (logand lu ru))
                 (:or (logior lu ru)) (:xor (logxor lu ru))
                 (:div (if w (truncate ls rs) (truncate (s32* la) (s32* ra))))
                 (:rem (if w (rem ls rs) (rem (s32* la) (s32* ra))))
                 (:udiv (if w (truncate lu ru) (truncate (u32 la) (u32 ra))))
                 (:urem (if w (rem lu ru) (rem (u32 la) (u32 ra))))
                 (:sar (ash (if w ls (s32* la)) (- (logand ru mask))))
                 (:shr (ash (if w lu (u32 la)) (- (logand ru mask))))
                 (:shl (ash lu (logand ru mask)))
                 (:extsb (s32* (logand la #xff)))       ; (int8) then widen
                 (:extub (logand la #xff))
                 (:extsh (let ((v (logand la #xffff))) (if (>= v #x8000) (- v #x10000) v)))
                 (:extuh (logand la #xffff))
                 (:extsw (s32* la)) (:extuw (u32 la))
                 (:stosi (truncate (con-value cl))) (:stoui (truncate (con-value cl)))
                 (:dtosi (truncate (con-value cl))) (:dtoui (truncate (con-value cl)))
                 (:cast lu))))))
      (declare (ignorable la ra lu ru ls rs))
      (values t x typ sym symt))))

(defun foldflt (op w cl cr)
  "Fold a float-result OP; returns a fresh flt con (W = double)."
  (if w
      (let ((ld (con-value cl)) (rd (con-value cr)))
        (declare (ignorable rd))
        (make-con :kind :bits :flt 2 :value
          (ecase op
            (:add (+ ld rd)) (:sub (- ld rd)) (:neg (- ld))
            (:div (/ ld rd)) (:mul (* ld rd))
            (:swtof (coerce (s32* (con-ibits cl)) 'double-float))
            (:uwtof (coerce (u32 (con-ibits cl)) 'double-float))
            (:sltof (coerce (s64* (con-ibits cl)) 'double-float))
            (:ultof (coerce (u64* (con-ibits cl)) 'double-float))
            (:exts (coerce (con-value cl) 'double-float))
            (:cast (bits->double (con-ibits cl))))))
      (let ((ls (con-value cl)) (rs (con-value cr)))
        (declare (ignorable rs))
        (make-con :kind :bits :flt 1 :value
          (coerce
           (ecase op
             (:add (+ ls rs)) (:sub (- ls rs)) (:neg (- ls))
             (:div (/ ls rs)) (:mul (* ls rs))
             (:swtof (coerce (s32* (con-ibits cl)) 'single-float))
             (:uwtof (coerce (u32 (con-ibits cl)) 'single-float))
             (:sltof (coerce (s64* (con-ibits cl)) 'single-float))
             (:ultof (coerce (u64* (con-ibits cl)) 'single-float))
             (:truncd (con-value cl))
             (:cast (bits->single (con-ibits cl))))
           'single-float)))))

(defun opfold (op cls cl cr fn)
  "fold.c opfold: fold OP to a con Ref, or NIL if non-foldable."
  (cond
    ((member cls '(:w :l))
     (multiple-value-bind (ok x typ sym symt) (foldint op (eq cls :l) cl cr)
       (when ok
         (unless (kwide cls) (setf x (u32 x)))
         (newcon (if (eq typ :addr)
                     (make-con :kind :addr :symname sym :symtype symt
                               :off (norm-i64 x))
                     (make-con :kind :bits :value (norm-i64 x)))
                 fn))))
    (t (newcon (foldflt op (eq cls :d) cl cr) fn))))

(defun foldref (fn i)
  "GVN constant folding: if all args of I are cons, return the folded con."
  (when (and (tmp-p (ins-to i)) (op-canfold (ins-op i)) (con-p (ins-arg0 i)))
    (let ((cr (or (ins-arg1 i) (aref *con01* 0))))
      (when (con-p cr)
        (opfold (ins-op i) (ins-cls i) (ins-arg0 i) cr fn)))))

;;; --------------------------------------------------------- gvndup (CSE)
(defvar *gvntbl* nil "equal-hash: value-key -> defining ins (CSE table).")

(defun ref-key (r)
  (cond ((tmp-p r) (cons :t (tmp-id r)))
        ((con-p r) (cons :c (con-idx r)))
        ((null r) nil)
        (t (cons :o r))))

(defun ins-key (i)
  (list (ins-op i) (ins-cls i) (ref-key (ins-arg0 i)) (ref-key (ins-arg1 i))))

(defun gvndup (i insert)
  "Return an existing equivalent ins, or NIL (inserting I when INSERT)."
  (let* ((k (ins-key i)) (found (gethash k *gvntbl*)))
    (or found (progn (when insert (setf (gethash k *gvntbl*) i)) nil))))

;;; --------------------------------------------------------- dedup driver

(defun isdivwl (i)
  "Integer div/rem (Kw/Kl): can trap, so GCM-pinned (gcm.c isdivwl)."
  (and (member (ins-op i) '(:div :rem :udiv :urem))
       (= 0 (cls-base (ins-cls i)))))

(defun pinned-ins (i)
  "gcm.c pinned(): optab pinned flag OR an integer div/rem."
  (or (op-pinned (ins-op i)) (isdivwl i)))

(defun dedupins (fn b i)
  (normins fn i)
  (when (or (eq (ins-op i) :nop) (pinned-ins i))
    (return-from dedupins))
  (let ((r (copyref fn b i)))
    (when r (killins fn i r) (return-from dedupins)))
  (let ((r (foldref fn i)))
    (when r (killins fn i r) (return-from dedupins)))
  (let ((i1 (gvndup i t)))
    (when i1 (killins fn i (ins-to i1)) (return-from dedupins))))

;;; ---------------------------------------------------------- dedupphi
;;; copy.c phicopyref, core: identical args, or same as an earlier phi.

(defun phi-eq (pa pb)
  "Do phis PA and PB have identical (blk->arg) mappings?"
  (and (= (length (phi-args pa)) (length (phi-args pb)))
       (every (lambda (pair)
                (let ((other (assoc (car pair) (phi-args pb) :test #'eq)))
                  (and other (eq (cdr pair) (cdr other)))))
              (phi-args pa))))

(defun phicopyref (b p)
  ;; identical args (ignoring self-references to p->to)
  (let ((r nil) (all t))
    (dolist (pair (phi-args p))
      (let ((a (cdr pair)))
        (unless (eq a (phi-to p))
          (cond ((null r) (setf r a))
                ((not (eq a r)) (setf all nil) (return))))))
    (when all (return-from phicopyref (or r (phi-to p)))))
  ;; same as a previous phi in this block
  (dolist (p1 (blk-phis b))
    (when (eq p1 p) (return))
    (when (phi-eq p1 p) (return-from phicopyref (phi-to p1))))
  nil)

(defun dedupphi (fn b)
  (setf (blk-phis b)
        (remove nil
                (mapcar (lambda (p)
                          (let ((r (phicopyref b p)))
                            (if r (progn (replaceuses fn (phi-to p) r) nil) p)))
                        (blk-phis b)))))

;;; ---------------------------------------------------------- narrowpars
;;; copy.c narrowpars: for functions with loops, insert early extub/extuh for
;;; params used only narrowly (factoring extensions out of loops).  We stub the
;;; width analysis (usewidthle) to NIL — the common case where a param is used
;;; at full width — so each leading par gets a `nop` slot.  (Narrowing rename
;;; for genuinely narrow params is a later refinement.)

(defun par-op-p (op) (member op '(:par :parsb :parub :parsh :paruh :parc :pare)))

(defun has-loop-p (fn)
  "Does FN's CFG contain a back edge (natural loop)?"
  (dolist (b (fn-blocks fn) nil)
    (when (or (and (blk-s1 b) (dom (blk-s1 b) b))
              (and (blk-s2 b) (dom (blk-s2 b) b)))
      (return t))))

(defun narrowpars (fn)
  (when (has-loop-p fn)
    (let ((start (fn-start fn)) (pars '()) (rest '()))
      (dolist (i (blk-ins start))
        (if (and (null rest) (par-op-p (ins-op i))) (push i pars) (push i rest)))
      (setf pars (nreverse pars) rest (nreverse rest))
      (when pars
        (let ((slots (mapcar (lambda (i) (declare (ignore i))
                               (make-instance 'ins :op :nop))
                             pars)))
          (setf (blk-ins start) (append pars slots rest)))))))

;;; ---------------------------------------------------------- dedupjmp
;;; gvn.c dedupjmp + supporting inference: collapse a jnz to a jmp when its
;;; condition is provably constant (literal, s1==s2, or 0/non-0 inferred from a
;;; dominating branch), and propagate the known-0 value into the dominated
;;; branch so later dedupins can fold.

(defun cmpeqz (fn r)
  "If R is defined by a `<cmp>eq/ne <x>, 0` (cmpeqwl op with arg1==0), return
   (values t x argcls eqval); else NIL.  (gvn.c cmpeqz)"
  (declare (ignore fn))
  (when (tmp-p r)
    (let ((i (tmp-def r)))
      (when (and i (op-cmpeqwl (ins-op i)) (eq (ins-arg1 i) (aref *con01* 0)))
        (values t (ins-arg0 i) (argcls (ins-op i) (ins-cls i) 0)
                (op-eqval (ins-op i)))))))

;;; reachability (cfg.c reaches/reachrec/reachesnotvia) via blk-visit scratch.
(defun reachrec (b to)
  (cond ((eq b to) t)
        ((or (null b) (not (zerop (blk-visit b)))) nil)
        (t (setf (blk-visit b) 1)
           (or (reachrec (blk-s1 b) to) (reachrec (blk-s2 b) to)))))

(defun reaches (fn b to)
  (prog1 (reachrec b to)
    (dolist (x (fn-blocks fn)) (setf (blk-visit x) 0))))

(defun reachesnotvia (fn b to excl)
  "Can B reach TO without passing through EXCL?  (cfg.c reachesnotvia)"
  (setf (blk-visit excl) 1)
  (reaches fn b to))

(defun branchdom (fn bif bbr1 bbr2 b)
  "Is B exclusively in the BBR1 branch of the jnz at BIF?  (gvn.c branchdom)"
  (and (not (eq b bif))
       (dom bbr1 b)
       (not (reachesnotvia fn bbr2 b bif))))

(defun domzero (fn d b)
  "If B is dominated by exactly one branch of jnz D, return (values t z) with
   z=0 for the s1 (true) branch, z=1 for the s2 (false) branch."
  (cond ((branchdom fn d (blk-s1 d) (blk-s2 d) b) (values t 0))
        ((branchdom fn d (blk-s2 d) (blk-s1 d) b) (values t 1))
        (t (values nil nil))))

(defun zeroval (fn b r cls)
  "Infer a 0/non-0 value for R at block B from a dominating jnz.  Returns
   (values t z), z=1 meaning R is provably 0 here.  (gvn.c zeroval)"
  (loop for d = (blk-idom b) then (blk-idom d) while d do
    (when (eq (blk-jmp-type d) :jnz)
      (when (and (eq r (blk-jmp-arg d)) (eq cls :w))
        (multiple-value-bind (ok z) (domzero fn d b)
          (when ok (return-from zeroval (values t z)))))
      (multiple-value-bind (ok arg cls1 eqval) (cmpeqz fn (blk-jmp-arg d))
        (when (and ok (eq r arg) (eq cls cls1))
          (multiple-value-bind (dz z) (domzero fn d b)
            (when dz (return-from zeroval (values t (logxor z eqval)))))))))
  (values nil nil))

(defun usecls (u r cls)
  "Class at which use U references R (gvn.c usecls); Km normalized to Kl."
  (ecase (use-rec-type u)
    (:ins (let* ((i (use-rec-payload u)) (k :x))
            (when (eq (ins-arg0 i) r) (setf k (argcls (ins-op i) (ins-cls i) 0)))
            (when (and (eq (ins-arg1 i) r) (or (eq k :x) (not (kwide k))))
              (setf k (argcls (ins-op i) (ins-cls i) 1)))
            (setf k (if (eq k :m) :l k))
            (if (eq k :x) cls k)))
    (:phi (let ((p (use-rec-payload u))) (if (null (phi-to p)) cls (phi-cls p))))
    (:jmp :w)))

(defun propjnz0 (fn bif s0 snon0 r cls)
  "Replace uses of R by 0 in blocks that are exclusively in BIF's S0 branch,
   when S0 is entered only from BIF and the use width matches.  (gvn.c propjnz0)"
  (when (and (= 1 (length (blk-preds s0))) (tmp-p r))
    (dolist (u (copy-list (tmp-use r)))
      (let ((b (aref (fn-rpo fn) (use-rec-bid u))))
        (when (and (eq (usecls u r cls) cls)
                   (branchdom fn bif s0 snon0 b))
          (replaceuse fn u r (aref *con01* 0)))))))

(defun dedupjmp (fn b)
  (when (eq (blk-jmp-type b) :jnz)
    (let ((arg (blk-jmp-arg b)))
      ;; propagate jmp arg as 0 through the s2 (false) branch
      (propjnz0 fn b (blk-s2 b) (blk-s1 b) arg :w)
      ;; propagate the compared value as 0 through a cmp-eq/ne-0 def
      (multiple-value-bind (ok carg ccls ceqval) (cmpeqz fn arg)
        (when ok
          (let ((ps (vector (blk-s1 b) (blk-s2 b))))
            (propjnz0 fn b (aref ps (logxor ceqval 1)) (aref ps ceqval) carg ccls))))
      ;; collapse trivial/constant jnz to jmp
      (let ((v 1) (z 0) (collapse nil) (cv (isconbits arg)))
        (cond
          ((eq (blk-s1 b) (blk-s2 b)) (setf collapse t))
          (cv (setf v cv collapse t))
          (t (multiple-value-bind (found zz) (zeroval fn b arg :w)
               (when found (setf z zz collapse t)))))
        (when collapse
          (when (or (eql v 0) (/= z 0))
            (setf (blk-s1 b) (blk-s2 b)))
          (setf (blk-s2 b) nil (blk-jmp-type b) :jmp (blk-jmp-arg b) nil))))))

;;; ---------------------------------------------------------- rebuildcfg
;;; cfg.c fixphis + gvn.c rebuildcfg: after collapses, refill the CFG (pruning
;;; now-dead blocks) and hoist still-active instructions from dead blocks into
;;; start so their (already CSE'd) values survive.

(defun fixphis (fn live)
  "Drop phi args from predecessors that are dead or no longer branch to B."
  (dolist (b (fn-blocks fn))
    (dolist (p (blk-phis b))
      (setf (phi-args p)
            (remove-if-not
             (lambda (pair)
               (let ((bp (car pair)))
                 (and (gethash bp live)
                      (or (eq (blk-s1 bp) b) (eq (blk-s2 bp) b)))))
             (phi-args p))))))

(defun rebuildcfg (fn)
  (let ((old-rpo (copy-seq (fn-rpo fn))) (start (fn-start fn)))
    (fill-cfg fn)                       ; prunes dead blocks, renumbers, preds
    (let ((live (make-hash-table :test 'eq)))
      (dolist (b (fn-blocks fn)) (setf (gethash b live) t))
      (fixphis fn live)
      ;; hoist active ins out of killed blocks, in rpo order
      (loop for b across old-rpo unless (gethash b live) do
        (dolist (i (blk-ins b))
          (when (and (not (op-pinned (ins-op i))) (eq (gvndup i nil) i))
            (setf (blk-ins start) (nconc (blk-ins start) (list i)))))))))

(defun gvn (fn)
  "Global value numbering (C3): canonicalization + copy-prop + const-fold + CSE
+ phi-dedup + jnz simplification, then rebuild the CFG.  Requires fill-cfg."
  (let ((*con01* (vector (getcon 0 fn) (getcon 1 fn)))
        (*gvntbl* (make-hash-table :test 'equal)))
    (narrowpars fn)
    (fill-use fn)
    (dolist (b (fn-blocks fn)) (setf (blk-visit b) 0))
    (loop for n below (fn-nblk fn)
          for b = (aref (fn-rpo fn) n) do
      (dedupphi fn b)
      (dolist (i (blk-ins b)) (dedupins fn b i))
      (dedupjmp fn b))
    (rebuildcfg fn)))
