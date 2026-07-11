;;;; load.lisp --- alias analysis (alias.c) + load elimination (load.c).
;;;;
;;;; C1 of the mid-end.  QBE runs these between ssa and gvn:
;;;;   fillalias -> loadopt -> fillalias -> coalesce -> gvn
;;;; loadopt forwards dominating stores/loads into a load (store-to-load and
;;;; load-to-load forwarding), synthesizing shift/mask/or chains for partial
;;;; overlaps and phis across predecessors.
;;;;
;;;; Oracle: `qbe -dM`'s "> After load elimination:" dump (test/golden-dm/).

(in-package #:qbe)

(defconstant +nbit+ 64)

;;; ------------------------------------------------------------------- Alias
;;; alias.c Alias.  type: :bot :loc :con :esc :sym :unk.  base = temp id,
;;; offset an integer, slot points to the owning stack slot's alias (or NIL).
;;; For a stack local, loc-sz/loc-m hold the tracked size + written-byte mask;
;;; for a symbol, sym-name/sym-type hold the constant's symbol.

(defstruct (alias (:constructor make-alias))
  (type :bot)
  (base -1)
  (offset 0)
  (loc-sz 0)
  (loc-m 0)
  sym-name
  sym-type
  (slot nil))

(defun astack (type) (or (eq type :loc) (eq type :esc)))

(defun con-int-payload (c)
  "The 64-bit union payload (bits.i) of con C: offset for addr, bits for int."
  (ecase (con-kind c) (:bits (con-rawbits c)) (:addr (con-off c)) (:undef 0)))

(defun alias-copy-into (dst src)
  (setf (alias-type dst)     (alias-type src)
        (alias-base dst)     (alias-base src)
        (alias-offset dst)   (alias-offset src)
        (alias-loc-sz dst)   (alias-loc-sz src)
        (alias-loc-m dst)    (alias-loc-m src)
        (alias-sym-name dst) (alias-sym-name src)
        (alias-sym-type dst) (alias-sym-type src)
        (alias-slot dst)     (alias-slot src)))

(defun loadsz (i)
  (ecase (ins-op i)
    ((:loadsb :loadub) 1) ((:loadsh :loaduh) 2) ((:loadsw :loaduw) 4)
    (:load (if (kwide (ins-cls i)) 8 4))))

(defun storesz (i)
  (ecase (ins-op i)
    (:storeb 1) (:storeh 2) ((:storew :stores) 4) ((:storel :stored) 8)))

;;; ------------------------------------------------------------------ getalias

(defun getalias (r fn)
  "alias.c getalias: the (resolved) Alias of operand R, as a fresh struct."
  (declare (ignore fn))
  (let ((a (make-alias)))
    (cond
      ((tmp-p r)
       (alias-copy-into a (tmp-alias r))
       (when (astack (alias-type a))
         (setf (alias-type a) (alias-type (alias-slot a)))))
      ((con-p r)
       (if (eq (con-kind r) :addr)
           (setf (alias-type a) :sym
                 (alias-sym-name a) (con-symname r)
                 (alias-sym-type a) (con-symtype r))
           (setf (alias-type a) :con))
       (setf (alias-offset a) (con-int-payload r) (alias-slot a) nil))
      (t (error "getalias: unreachable ~s" r)))
    a))

(defun sym-eq (an at bn bt)
  (and (equal an bn) (equal at bt)))

(defun aliasing (p op sp q sq fn)
  "alias.c alias: relationship of [P+op, +sp) vs [Q, +sq).
   Returns (values relation delta) with relation :must/:may/:no."
  (let ((ap (getalias p fn)) (aq (getalias q fn)))
    (incf (alias-offset ap) op)
    (let* ((delta (- (alias-offset ap) (alias-offset aq)))
           (ovlap (and (< (alias-offset ap) (+ (alias-offset aq) sq))
                       (< (alias-offset aq) (+ (alias-offset ap) sp)))))
      (values
       (cond
         ((and (astack (alias-type ap)) (astack (alias-type aq)))
          (if (and (= (alias-base ap) (alias-base aq)) ovlap) :must :no))
         ((and (eq (alias-type ap) :sym) (eq (alias-type aq) :sym))
          (cond ((not (sym-eq (alias-sym-name ap) (alias-sym-type ap)
                              (alias-sym-name aq) (alias-sym-type aq))) :may)
                (ovlap :must)
                (t :no)))
         ((or (and (eq (alias-type ap) :con) (eq (alias-type aq) :con))
              (and (eq (alias-type ap) (alias-type aq))
                   (= (alias-base ap) (alias-base aq))))
          (if ovlap :must :no))
         ((and (eq (alias-type ap) :unk) (not (eq (alias-type aq) :loc))) :may)
         ((and (eq (alias-type aq) :unk) (not (eq (alias-type ap) :loc))) :may)
         (t :no))
       delta))))

(defun escapes (r fn)
  (declare (ignore fn))
  (if (not (tmp-p r)) t
      (let ((a (tmp-alias r)))
        (or (not (astack (alias-type a))) (eq (alias-type (alias-slot a)) :esc)))))

(defun alias-esc (r fn)
  (declare (ignore fn))
  (when (tmp-p r)
    (let ((a (tmp-alias r)))
      (when (astack (alias-type a)) (setf (alias-type (alias-slot a)) :esc)))))

(defun alias-store (r sz fn)
  "alias.c store: record that SZ bytes at R's offset are written in its slot."
  (declare (ignore fn))
  (when (tmp-p r)
    (let ((a (tmp-alias r)))
      (when (alias-slot a)
        (let* ((off (alias-offset a))
               (m (if (or (>= sz +nbit+) (< off 0) (>= off +nbit+))
                      -1
                      (ash (1- (ash 1 sz)) off))))
          (setf (alias-loc-m (alias-slot a))
                (logior (alias-loc-m (alias-slot a)) (u64* m))))))))

;;; ------------------------------------------------------------------ fillalias

(defun fill-alias (fn)
  "alias.c fillalias: classify every temp's pointer alias."
  (dotimes (tid (fn-ntmp fn))
    (setf (tmp-alias (aref (fn-tmp fn) tid)) (make-alias :type :bot)))
  (dotimes (n (fn-nblk fn))
    (let ((b (aref (fn-rpo fn) n)))
      (dolist (p (blk-phis b))
        (let ((a (tmp-alias (phi-to p))))
          (setf (alias-type a) :unk (alias-base a) (tmp-id (phi-to p))
                (alias-offset a) 0 (alias-slot a) nil)))
      (let ((ins (coerce (blk-ins b) 'vector)) (k 0))
        (loop while (< k (length ins)) do
          (let* ((i (aref ins k)) (a nil))
            (when (ins-to i)
              (setf a (tmp-alias (ins-to i)))
              (cond
                ((isalloc-op (ins-op i))
                 (setf (alias-type a) :loc (alias-slot a) a (alias-loc-sz a) -1)
                 (when (con-p (ins-arg0 i))
                   (let ((c (ins-arg0 i)))
                     (when (eq (con-kind c) :bits)
                       (let ((x (con-value c)))
                         (when (<= 0 x +nbit+) (setf (alias-loc-sz a) x)))))))
                (t (setf (alias-type a) :unk (alias-slot a) nil)))
              (setf (alias-base a) (tmp-id (ins-to i)) (alias-offset a) 0))
            (when (eq (ins-op i) :copy)
              (alias-copy-into a (getalias (ins-arg0 i) fn)))
            (when (eq (ins-op i) :add)
              (let ((a0 (getalias (ins-arg0 i) fn)) (a1 (getalias (ins-arg1 i) fn)))
                (cond ((eq (alias-type a0) :con)
                       (alias-copy-into a a1) (incf (alias-offset a) (alias-offset a0)))
                      ((eq (alias-type a1) :con)
                       (alias-copy-into a a0) (incf (alias-offset a) (alias-offset a1))))))
            (when (and (or (null (ins-to i)) (eq (alias-type a) :unk))
                       (not (eq (ins-op i) :blit0)))
              (unless (isload-op (ins-op i)) (alias-esc (ins-arg0 i) fn))
              (unless (or (isstore-op (ins-op i)) (eq (ins-op i) :argc))
                (alias-esc (ins-arg1 i) fn)))
            (cond
              ((eq (ins-op i) :blit0)
               (incf k)
               (let ((b1 (aref ins k)))
                 (alias-store (ins-arg1 i) (abs (ins-arg0 b1)) fn)))
              ((isstore-op (ins-op i))
               (alias-store (ins-arg1 i) (storesz i) fn)))
            (incf k))))
      (unless (eq (blk-jmp-type b) :retc)
        (alias-esc (blk-jmp-arg b) fn))))
  (do ((b (fn-start fn) (blk-link b))) ((null b))
    (dolist (p (blk-phis b))
      (dolist (pa (phi-args p)) (alias-esc (cdr pa) fn)))))

;;; ------------------------------------------------------------------ loadopt
;;; load.c: forward dominating stores/loads into loads (def), synthesizing
;;; shift/mask/or chains and phis, logged in *ilog* and spliced back in.

(defstruct (slice (:constructor make-slice (ref off sz cls))) ref off sz cls)
(defstruct (loc (:constructor make-loc (type off blk))) type off blk)  ; :root/:load/:noload
(defstruct (insert (:constructor make-insert))
  (isphi nil) num bid off ins phi-slice phi)

(defvar *curf* nil) (defvar *ilog* nil) (defvar *inum* 0)

(defun ld-maskv (w) (1- (* (ash 1 (1- (* 8 w))) 2)))   ; MASK(w)

(defun iins (cls op a0 a1 l)
  "load.c iins: log a fresh scalar instruction at location L, return its temp."
  (let* ((to (newtmp "ld" cls *curf*))
         (i (make-instance 'ins :op op :cls cls :to to :arg0 a0 :arg1 a1)))
    (vector-push-extend
     (make-insert :isphi nil :num *inum* :bid (blk-id (loc-blk l)) :off (loc-off l) :ins i)
     *ilog*)
    (incf *inum*)
    to))

(defun ld-cast (r cls l)
  "load.c cast: coerce R to class CLS via cast/extuw, returns the new ref."
  (if (con-p r) r
      (let ((cls0 (tmp-cls r)))
        (cond
          ((or (eq cls0 cls) (and (eq cls :w) (eq cls0 :l))) r)
          ((< (if (kwide cls0) 1 0) (if (kwide cls) 1 0))
           (when (eq cls0 :s) (setf r (iins :w :cast r nil l)))
           (setf r (iins :l :extuw r nil l))
           (when (eq cls :d) (setf r (iins :d :cast r nil l)))
           r)
          (t
           (when (and (eq cls0 :d) (not (eq cls :l))) (setf r (iins :l :cast r nil l)))
           (when (or (not (eq cls0 :d)) (not (eq cls :w))) (setf r (iins cls :cast r nil l)))
           r)))))

(defun ld-mask (cls r msk l)
  (setf r (ld-cast r cls l))
  (iins cls :and r (getcon msk *curf*) l))

(defun ld-load (sl msk l)
  "load.c load: emit a real load of slice SL, masked by MSK."
  (let* ((ld (ecase (slice-sz sl) (1 :loadub) (2 :loaduh) (4 :loaduw) (8 :load)))
         (all (= msk (ld-maskv (slice-sz sl))))
         (cls (if all (slice-cls sl) (if (> (slice-sz sl) 4) :l :w)))
         (r (slice-ref sl)))
    (when (tmp-p r)
      (let ((a (tmp-alias r)))
        (ecase (alias-type a)
          ((:loc :esc :unk)
           (setf r (tid-ref* (alias-base a)))
           (unless (zerop (alias-offset a))
             (setf r (iins :l :add r (getcon (alias-offset a) *curf*) l))))
          ((:con :sym)
           (setf r (newcon (if (alias-sym-name a)
                               (make-con :kind :addr :symname (alias-sym-name a)
                                         :symtype (alias-sym-type a) :off (alias-offset a))
                               (make-con :kind :bits :value (alias-offset a)))
                           *curf*))))))
    (setf r (iins cls ld r nil l))
    (unless all (setf r (ld-mask cls r msk l)))
    r))

(defun tid-ref* (tid) (aref (fn-tmp *curf*) tid))   ; TMP(base): user-temp id -> tmp

(defun ld-rebase (sl)
  (when (tmp-p (slice-ref sl))
    (let ((a (tmp-alias (slice-ref sl))))
      (when (and (= (alias-offset a) (s16* (alias-offset a)))
                 (member (alias-type a) '(:loc :esc :unk)))
        (setf (slice-ref sl) (tid-ref* (alias-base a)) (slice-off sl) (alias-offset a))))))

(defun s16* (x) (let ((v (logand x #xffff))) (if (>= v #x8000) (- v #x10000) v)))

(defun killsl (r sl)
  "load.c killsl: does defining R clobber the base of slice SL?"
  (if (not (tmp-p (slice-ref sl))) nil
      (let ((a (tmp-alias (slice-ref sl))))
        (ecase (alias-type a)
          ((:loc :esc :unk) (eq (tid-ref* (alias-base a)) r))
          ((:con :sym) nil)))))

(defun ld-def (sl msk b i il)
  "load.c def: value of slice SL (bits in MSK) as seen at location IL,
   searching block B backward from instruction index I (NIL = block end).
   Returns a ref, or NIL when it fails (and IL is not a load site)."
  (let* ((fn *curf*) (oldl (fill-pointer *ilog*)) (oldt (fn-ntmp fn))
         (bins (coerce (blk-ins b) 'vector))
         (cls (if (> (slice-sz sl) 4) :l :w))
         (msks (ld-maskv (slice-sz sl))))
    (labels ((go-load ()
               (setf (fill-pointer *ilog*) oldl (fill-pointer (fn-tmp fn)) oldt)
               (if (not (eq (loc-type il) :load)) nil (ld-load sl msk il))))
      (block def
        (unless i (setf i (length bins)))
        (loop while (> i 0) do
          (decf i)
          (block iter
            (let* ((ins (aref bins i)) (op (ins-op ins)) sz r1 r (ld nil))
              (when (or (killsl (ins-to ins) sl)
                        (and (eq op :call) (escapes (slice-ref sl) fn)))
                (return-from def (go-load)))
              (cond
                ((setf ld (isload-op op)) (setf sz (loadsz ins) r1 (ins-arg0 ins) r (ins-to ins)))
                ((isstore-op op) (setf sz (storesz ins) r1 (ins-arg1 ins) r (ins-arg0 ins)))
                ((eq op :blit1)          ; step back over the pair; op/ins become blit0
                 (setf sz (abs (ins-arg0 ins))) (decf i)
                 (setf ins (aref bins i) op :blit0 r1 (ins-arg1 ins)))
                (t (return-from iter)))
              (multiple-value-bind (rel off)
                  (aliasing (slice-ref sl) (slice-off sl) (slice-sz sl) r1 sz fn)
                (ecase rel
                  (:must
                   (let ((sl1 nil))
                     (when (eq op :blit0)
                       (setf sl1 (make-slice (ins-arg0 ins) (slice-off sl) (slice-sz sl) (slice-cls sl)))
                       (if (>= off 0)
                           (progn (setf (slice-off sl1) off) (decf sz off) (setf off 0))
                           (progn (setf (slice-off sl1) 0) (incf (slice-sz sl1) off)))
                       (when (> sz (slice-sz sl1)) (setf sz (slice-sz sl1)))
                       (setf (slice-sz sl1) sz))
                     (let (msk1 shop)
                       (if (< off 0)
                           (setf off (- off) msk1 (logand (u64* (ash (ld-maskv sz) (* 8 off))) msks) shop :shl)
                           (setf msk1 (logand (ash (ld-maskv sz) (* -8 off)) msks) shop :shr))
                       (when (zerop (logand msk1 msk)) (return-from iter))
                       (when (eq op :blit0)
                         (setf r (ld-def sl1 (ld-maskv sz) b i il))
                         (when (null r) (return-from def (go-load))))
                       (when (/= off 0)
                         (let ((cls1 cls))
                           (when (and (eq shop :shr) (> (+ off (slice-sz sl)) 4)) (setf cls1 :l))
                           (setf r (ld-cast r cls1 il))
                           (setf r (iins cls1 shop r (getcon (* 8 off) *curf*) il))))
                       (when (or (/= (logand msk1 msk) msk1) (< (+ off sz) (slice-sz sl)))
                         (setf r (ld-mask cls r (logand msk1 msk) il)))
                       (when (/= (logand msk (lognot msk1)) 0)
                         (let ((r2 (ld-def sl (logand msk (u64* (lognot msk1))) b i il)))
                           (when (null r2) (return-from def (go-load)))
                           (setf r (iins cls :or r r2 il))))
                       (when (= msk msks) (setf r (ld-cast r (slice-cls sl) il)))
                       (return-from def r))))
                  (:may (if ld (return-from iter) (return-from def (go-load))))
                  (:no (return-from iter)))))))

        ;; already-synthesized phi for this slice in b?
        (loop for j from 0 below (fill-pointer *ilog*)
              for ist = (aref *ilog* j) do
          (when (and (insert-isphi ist) (= (insert-bid ist) (blk-id b))
                     (let ((m (insert-phi-slice ist)))
                       (and (eq (slice-ref m) (slice-ref sl))
                            (= (slice-off m) (slice-off sl))
                            (= (slice-sz m) (slice-sz sl)))))
            (let ((r (phi-to (insert-phi ist))))
              (if (/= msk msks) (setf r (ld-mask cls r msk il)) (setf r (ld-cast r (slice-cls sl) il)))
              (return-from def r))))

        (dolist (p (blk-phis b))
          (when (killsl (phi-to p) sl) (return-from def (go-load))))

        (let ((preds (blk-preds b)))
          (when (null preds) (return-from def (go-load)))
          (when (= (length preds) 1)
            (let* ((bp (car preds)) (l (make-loc (loc-type il) (loc-off il) (loc-blk il))))
              (when (blk-s2 bp) (setf (loc-type l) :noload))
              (let ((r1 (ld-def sl msk bp nil l)))
                (when (null r1) (return-from def (go-load)))
                (return-from def r1))))

          ;; multiple predecessors: synthesize a phi
          (let* ((r (newtmp "ld" (slice-cls sl) fn))
                 (p (make-instance 'phi :to r :cls (slice-cls sl) :args nil))
                 (ist (make-insert :isphi t :num *inum* :bid (blk-id b)
                                   :phi-slice sl :phi p)))
            (vector-push-extend ist *ilog*)
            (let ((args nil))
              (dolist (bp preds)
                (let ((l (make-loc (if (and (not (blk-s2 bp))
                                            (not (eq (loc-type il) :noload))
                                            (< (blk-loop bp) (blk-loop (loc-blk il))))
                                       :load :noload)
                                   (length (blk-ins bp)) bp)))
                  (let ((r1 (ld-def sl msks bp nil l)))
                    (when (null r1) (return-from def (go-load)))
                    (push (cons bp r1) args))))
              (setf (phi-args p) (nreverse args)))
            (when (/= msk msks) (setf r (ld-mask cls r msk il)))
            (return-from def r)))))))

(defun insert-less-p (a b)
  (cond ((/= (insert-bid a) (insert-bid b)) (< (insert-bid a) (insert-bid b)))
        ((and (insert-isphi a) (insert-isphi b)) nil)
        ((insert-isphi a) t)
        ((insert-isphi b) nil)
        ((/= (insert-off a) (insert-off b)) (< (insert-off a) (insert-off b)))
        (t (< (insert-num a) (insert-num b)))))

(defun loadopt (fn)
  "load.c loadopt: eliminate loads that a dominating store/load makes redundant."
  (let ((*curf* fn) (*ilog* (make-array 0 :adjustable t :fill-pointer 0)) (*inum* 0))
    (do ((b (fn-start fn) (blk-link b))) ((null b))
      (let ((bins (coerce (blk-ins b) 'vector)))
        (dotimes (k (length bins))
          (let ((i (aref bins k)))
            (when (isload-op (ins-op i))
              (let* ((sz (loadsz i))
                     (sl (make-slice (ins-arg0 i) 0 sz (ins-cls i)))
                     (l (make-loc :root k b)))
                (ld-rebase sl)
                (setf (ins-arg1 i) (ld-def sl (ld-maskv sz) b k l))))))))
    (let ((log (stable-sort (coerce *ilog* 'list) #'insert-less-p)))
      (ld-splice fn log))
    (when *loadopt-debug* (format *error-output* "~&> After load elimination:~%~a" (print-fn-to-string fn)))))

(defvar *loadopt-debug* nil)

(defun ld-splice (fn log)
  "Interleave the sorted insertion LOG back into each block (load.c loadopt
   tail): prepend synthesized phis, splice new instructions at their offsets,
   and rewrite forwarded loads (arg1 set) into copy/ext."
  (let ((log (coerce log 'vector)) (ist 0) (nlog 0))
    (setf nlog (length log))
    (dotimes (n (fn-nblk fn))
      (let* ((b (aref (fn-rpo fn) n)) (bins (coerce (blk-ins b) 'vector)))
        (loop while (and (< ist nlog)
                         (= (insert-bid (aref log ist)) n) (insert-isphi (aref log ist)))
              do (push (insert-phi (aref log ist)) (blk-phis b)) (incf ist))
        (let ((out nil) (ni 0))
          (loop
            (cond
              ((and (< ist nlog) (= (insert-bid (aref log ist)) n) (= (insert-off (aref log ist)) ni))
               (push (insert-ins (aref log ist)) out) (incf ist))
              (t
               (when (= ni (length bins)) (return))
               (let ((i (aref bins ni)))
                 (incf ni)
                 (when (and (isload-op (ins-op i)) (ins-arg1 i))
                   (let ((ext (ld-ext-op (ins-op i))))
                     (case (ins-op i)
                       ((:loadsb :loadub :loadsh :loaduh) (setf (ins-op i) ext))
                       ((:loadsw :loaduw)
                        (if (eq (ins-cls i) :l) (setf (ins-op i) ext)
                            (setf (ins-op i) :copy)))
                       (:load (setf (ins-op i) :copy)))
                     (setf (ins-arg0 i) (ins-arg1 i) (ins-arg1 i) nil)))
                 (push i out)))))
          (setf (blk-ins b) (nreverse out)))))))

(defun ld-ext-op (op)
  (ecase op
    (:loadsb :extsb) (:loadub :extub) (:loadsh :extsh) (:loaduh :extuh)
    (:loadsw :extsw) (:loaduw :extuw) (:load :copy)))
