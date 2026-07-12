;;;; amd64-encode.lisp --- M3b: machine-code encoder (bytes + fixups).
;;;;
;;;; Sibling of amd64-emit.lisp: consumes the SAME backend-pipelined IR, but
;;;; emits x86-64 *machine code* + a relocation list instead of AT&T text -- the
;;;; "as-less" JIT path that feeds solder's bytes+fixups loader directly.
;;;;
;;;; Verified byte-exact against `as` by test/encode.lisp (curated cases) AND by
;;;; test/encode-corpus.lisp (EVERY function in test/corpus -- 180/180 identical).
;;;; Reloc kinds needed (readelf -r on emit.c output): PLT32 / PC32 / R_X86_64_64,
;;;; all solder-supported.
;;;;
;;;; STATUS: covers the scalar int+float subset end-to-end.
;;;;   int ALU: reg/imm mov/add/sub/and/or/xor; shl/shr/sar; imul; neg; div/rem
;;;;     (cltd/cqto + idiv/div); cmp + setcc/movzx; movslq/movl (ext*).
;;;;   frames (push rbp / sub rsp / callee-save) + epilogue; calls (E8+PLT32, FF/2).
;;;;   control flow: real jmp/jcc with `as`-matching branch relaxation
;;;;     (short<->near to a fixpoint) and `.p2align 4` NOP fill at loop headers.
;;;;   memory: loads/stores (all widths, sign/zero-ext) + lea over a general
;;;;     ModRM+SIB+disp operand (reg base, index*scale, frame slots, RIP-relative
;;;;     globals -> PC32).  cmov (xsel).
;;;;   floats/SSE: movss/movsd, add/sub/mul/div, cvt* int<->float & s<->d, ucomi
;;;;     compares, movd/movq cast; float const loads via RIP.
;;;;   data (enc-data / enc-stash): a `dat` -> octets + symbols + ABS64 ptr relocs;
;;;;     the fp-const pool -> a rodata blob of size-aligned `.LfpN` -- so the JIT's
;;;;     RIP-relative loads (globals + float consts) resolve at run time.
;;;;   misc: cmov (xsel), test, xchg (swap), byte/half ext, div/rem, salloc
;;;;     (dynalloc frame), varargs (176B reg-save area), wide-immediate
;;;;     materialization (movl / movq $imm32 / movabs).  Aggregates + blit fall
;;;;     out of the mem-operand path.  The whole test/corpus encodes byte-exact.
;;;;   Every unhandled form signals "enc: TODO ..." so the next gap is obvious.
;;;;   Next (rare): 4-byte data refs (needs solder ABS32); thread-local data.

(in-package #:qbe)

;;; forward references: the dispatch/helpers below call these, which are defined
;;; later in the file (loaded top-to-bottom).  Declared so `load` doesn't warn.
(declaim (ftype function enc-call enc-fcopy enc-store-imm alu-imm-hw hwid))

;;; qbe register id (1..16) -> hardware number (0..15); XMM0..15 (17..32) map to
;;; SSE hw 0..15 (same ModRM/REX numbering).
(defparameter *reg-hw*
  #(nil 0 1 2 6 7 8 9 10 11 3 12 13 14 15 5 4))
(defun rhw (ref)
  (let ((id (reg-id ref))) (if (>= id +xmm0+) (- id +xmm0+) (aref *reg-hw* id))))

;;; ---- encoder state -------------------------------------------------------
(defstruct (enc (:conc-name enc-))
  (buf (make-array 64 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0))
  (fixups '())        ; reversed list of FIXUP plists (:offset :symbol :kind :addend)
  es)                 ; emit-state (frame layout: fp/fsz/nclob) for slot resolution

(defun e8 (e b)  (vector-push-extend (logand b #xff) (enc-buf e)))
(defun e16 (e v) (e8 e v) (e8 e (ash v -8)))
(defun e32 (e v) (dotimes (k 4) (e8 e (ldb (byte 8 (* 8 k)) v))))
(defun here (e)  (fill-pointer (enc-buf e)))

;;; ---- primitive x86-64 encoding ------------------------------------------
(defun modrm (mod reg rm)
  (logior (ash mod 6) (ash (logand reg 7) 3) (logand rm 7)))

(defun maybe-rex (e w r x b)
  "Emit a REX prefix iff any of W/R/X/B is set (W = 64-bit operand)."
  (let ((rex (logior (ash w 3) (ash r 2) (ash x 1) b)))
    (unless (zerop rex) (e8 e (logior #x40 rex)))))

(defun wbit (cls) (if (kwide cls) 1 0))

(defun rr (e opcode reg-ref rm-ref cls)
  "One-byte-opcode /r form: REX? OPCODE ModRM(11, reg=reg-ref, rm=rm-ref)."
  (let ((w (wbit cls)) (rn (rhw reg-ref)) (mn (rhw rm-ref)))
    (maybe-rex e w (ash rn -3) 0 (ash mn -3))
    (e8 e opcode)
    (e8 e (modrm 3 rn mn))))

(defun rr2 (e op0 op1 reg-ref rm-ref cls)
  "Two-byte-opcode /r form (e.g. 0F AF): reg=reg-ref, rm=rm-ref."
  (let ((w (wbit cls)) (rn (rhw reg-ref)) (mn (rhw rm-ref)))
    (maybe-rex e w (ash rn -3) 0 (ash mn -3))
    (e8 e op0) (e8 e op1)
    (e8 e (modrm 3 rn mn))))

;;; ---- operand-level helpers ----------------------------------------------
(defun con-bits-p (r) (and (con-p r) (eq (con-kind r) :bits)))

(defun enc-mov-imm (e imm dst)
  "movl $imm32, %dst  (B8+rd id32; zero-extends -- emit.c's copy path for :l too)."
  (let ((dr (rhw dst)))
    (maybe-rex e 0 0 0 (ash dr -3))
    (e8 e (logior #xb8 (logand dr 7)))
    (e32 e imm)))

(defun enc-movq-imm32 (e imm dst)      ; movq $imm32, %dst (REX.W C7 /0 id, sign-ext)
  (let ((dr (rhw dst)))
    (maybe-rex e 1 0 0 (ash dr -3))
    (e8 e #xc7) (e8 e (modrm 3 0 dr)) (e32 e imm)))

(defun enc-movabs (e imm dst)          ; movabs $imm64, %dst (REX.W B8+rd io)
  (let ((dr (rhw dst)))
    (maybe-rex e 1 0 0 (ash dr -3))
    (e8 e (logior #xb8 (logand dr 7)))
    (dotimes (k 8) (e8 e (ldb (byte 8 (* 8 k)) imm)))))

(defun enc-load-imm (e v dst cls)
  "Materialize integer constant V into %dst (be-emit-copyins): movl for :w and for
   :l in [0,2^32); else movq $imm32 (sign-ext) or movabs for a full 64-bit value."
  (cond ((and (eq cls :l) (not (<= 0 v #xffffffff)))
         (if (typep v '(signed-byte 32)) (enc-movq-imm32 e v dst) (enc-movabs e v dst)))
        (t (enc-mov-imm e v dst))))     ; movl (zero-extends); covers :w and small :l

;;; ---- memory operands: ModRM + SIB + disp (mirrors emit-addr / be-slot) -----
(defun sib (scale index base)
  (logior (ash (ecase scale (1 0) (2 1) (4 2) (8 3)) 6)
          (ash (logand index 7) 3) (logand base 7)))

(defun resolve-mem (ref es)
  "Decode a memory r/m operand -> (values disp base-hw index-hw scale rip? sym-con).
   Mirrors emit-addr/be-slot: a slot base folds into a frame-relative disp."
  (cond
    ((slot-ref-p ref) (values (be-slot ref es) (aref *reg-hw* (es-fp es)) nil 1 nil nil))
    ((reg-p ref)      (values 0 (rhw ref) nil 1 nil nil))          ; (%reg)
    ((con-p ref) (if (eq (con-kind ref) :addr)
                     (values (con-off ref) nil nil 1 t ref)          ; sym(%rip)
                     (values (con-rawbits ref) nil nil 1 nil nil)))  ; absolute disp32
    ((mem-p ref)
     (let ((disp 0) (base nil) (index (mem-index ref)) (sym nil) (off (mem-offset ref)))
       (cond ((slot-ref-p (mem-base ref))
              (incf disp (be-slot (mem-base ref) es)) (setf base (aref *reg-hw* (es-fp es))))
             ((reg-p (mem-base ref)) (setf base (rhw (mem-base ref)))))
       (when off (ecase (con-kind off)
                   (:undef) (:bits (incf disp (con-rawbits off)))
                   (:addr (setf sym off) (incf disp (con-off off)))))
       (let ((rip (and sym (null base) (null index))))
         (values disp base (and index (rhw index)) (mem-scale ref) rip sym))))
    (t (error "enc: bad mem operand ~s" ref))))

(defun enc-rm-mem (e reg-hw rm-ref w opcodes &key prefix rex8 (tail 0))
  "Emit `prefix? REX? opcodes ModRM/SIB/disp` for reg field REG-HW over a memory
   r/m operand.  RIP-relative operands record a PC32 fixup (disp32 left 0); TAIL
   is the count of instruction bytes that follow the disp (e.g. a trailing imm),
   which the RIP addend must skip."
  (multiple-value-bind (disp base index scale rip sym) (resolve-mem rm-ref (enc-es e))
    (when prefix (e8 e prefix))
    (let ((rexr (ash reg-hw -3)) (rexx (if index (ash index -3) 0))
          (rexb (if base (ash base -3) 0)))
      (if (and rex8 (<= 4 reg-hw 7) (zerop (logior w rexr rexx rexb)))
          (e8 e #x40)                                   ; force REX to reach spl/bpl/sil/dil
          (maybe-rex e w rexr rexx rexb)))
    (dolist (op opcodes) (e8 e op))
    (cond
      (rip (e8 e (modrm 0 reg-hw 5))
           (let ((pos (here e))) (e32 e 0)
             (push (list :offset pos :symbol (con-symname sym) :kind :pc32 :addend (- disp 4 tail))
                   (enc-fixups e))))
      ((null base)                                      ; index-only: SIB base=101 + disp32
       (e8 e (modrm 0 reg-hw 4)) (e8 e (sib scale (or index 4) 5)) (e32 e disp))
      (t (let* ((b7 (logand base 7))
                (md (cond ((and (zerop disp) (/= b7 5)) 0) ((<= -128 disp 127) 1) (t 2))))
           (cond (index (e8 e (modrm md reg-hw 4)) (e8 e (sib scale (logand index 7) b7)))
                 ((= b7 4) (e8 e (modrm md reg-hw 4)) (e8 e (sib 1 4 b7)))  ; rsp/r12 base
                 (t (e8 e (modrm md reg-hw b7))))
           (case md (1 (e8 e (logand disp #xff))) (2 (e32 e disp))))))))

(defun mem-operand-p (r) (or (mem-p r) (slot-ref-p r)))

(defun enc-copy (e to a0 cls)
  (unless (or (null to) (null a0) (ref= to a0))
    (cond
      ((and (reg-p to) (con-bits-p a0)) (enc-load-imm e (con-rawbits a0) to cls))
      ((and (reg-p to) (con-p a0) (eq (con-kind a0) :addr))          ; lea sym(%rip), %to
       (enc-rm-mem e (rhw to) a0 (wbit cls) '(#x8d)))
      ((and (reg-p to) (reg-p a0))          (rr e #x89 a0 to cls))
      ((and (reg-p to) (mem-operand-p a0))  (enc-rm-mem e (rhw to) a0 (wbit cls) '(#x8b)))  ; load
      ((and (mem-operand-p to) (reg-p a0))  (enc-rm-mem e (rhw a0) to (wbit cls) '(#x89)))  ; store
      ((and (mem-operand-p to) (con-bits-p a0))                    ; movl/q $imm, slot
       (enc-store-imm e (if (kwide cls) :storel :storew) (con-rawbits a0) to))
      ((and (mem-operand-p to) (mem-operand-p a0))                 ; mem<-mem: bounce via xmm15
       (let ((x15 (rg (+ +xmm0+ 15))) (fc (if (kwide cls) :d :s)))
         (enc-fcopy e x15 a0 fc) (enc-fcopy e to x15 fc)))
      (t (error "enc: TODO copy ~s <- ~s" to a0)))))

;;; ---- floats / SSE (scalar single/double) ---------------------------------
(defun fcls-p (cls) (member cls '(:s :d)))
(defun fpfx (cls) (if (eq cls :d) #xf2 #xf3))          ; scalar sd / ss mandatory prefix

(defun sse-rr (e prefix op reg-ref rm-ref &optional (w 0))
  "prefix? REX? 0F op ModRM(11, reg=reg-ref, rm=rm-ref) -- reg/rm are xmm or gpr."
  (when prefix (e8 e prefix))
  (let ((rn (rhw reg-ref)) (mn (rhw rm-ref)))
    (maybe-rex e w (ash rn -3) 0 (ash mn -3))
    (e8 e #x0f) (e8 e op) (e8 e (modrm 3 rn mn))))

(defun sse-op (e prefix op reg-ref rm-ref &optional (w 0))
  "SSE /r with a register OR memory r/m operand."
  (if (mem-operand-p rm-ref)
      (enc-rm-mem e (rhw reg-ref) rm-ref w (list #x0f op) :prefix prefix)
      (sse-rr e prefix op reg-ref rm-ref w)))

(defun enc-fcopy (e to a0 cls)
  "Float copy/load/store: movss/movsd (F3/F2 0F 10 load-form, 0F 11 store-form)."
  (unless (or (null to) (null a0) (ref= to a0))
    (let ((pfx (fpfx cls)))
      (cond
        ((and (reg-p to) (reg-p a0))          (sse-rr e pfx #x10 to a0))
        ((and (reg-p to) (or (mem-operand-p a0) (con-p a0)))       ; load (incl .Lfp rip)
         (enc-rm-mem e (rhw to) a0 0 (list #x0f #x10) :prefix pfx))
        ((and (mem-operand-p to) (reg-p a0))                       ; store
         (enc-rm-mem e (rhw a0) to 0 (list #x0f #x11) :prefix pfx))
        (t (error "enc: TODO fcopy ~s <- ~s" to a0))))))

(defun enc-fbin (e i op commutative)
  "addss/subss/mulss/divss and the sd forms: copy arg0->to, then op %arg1,%to."
  (when (and commutative (ref= (ins-arg1 i) (ins-to i))) (rotatef (ins-arg0 i) (ins-arg1 i)))
  (enc-fcopy e (ins-to i) (ins-arg0 i) (ins-cls i))
  (sse-op e (fpfx (ins-cls i)) op (ins-to i) (ins-arg1 i)))

(defun enc-fconv (e i)
  "int<->float and float<->float conversions (omap cvt* family)."
  (let ((cls (ins-cls i)) (to (ins-to i)) (a0 (ins-arg0 i)))
    (ecase (ins-op i)
      (:swtof  (sse-op e (fpfx cls) #x2a to a0 0))          ; cvtsi2s*  (32-bit src)
      (:sltof  (sse-op e (fpfx cls) #x2a to a0 1))          ; cvtsi2s*  (64-bit src)
      (:stosi  (sse-op e #xf3 #x2c to a0 (wbit cls)))       ; cvttss2si
      (:dtosi  (sse-op e #xf2 #x2c to a0 (wbit cls)))       ; cvttsd2si
      (:exts   (sse-op e #xf3 #x5a to a0 0))                ; cvtss2sd
      (:truncd (sse-op e #xf2 #x5a to a0 0)))))             ; cvtsd2ss

(defun enc-cast (e i)
  "cast: reinterpret bits via movq between a gpr and an xmm.  QBE's omap always
   moves the full 64-bit union (%D0/%L=), so REX.W is always set even for w/s."
  (let ((cls (ins-cls i)) (to (ins-to i)) (a0 (ins-arg0 i)))
    (if (fcls-p cls)
        (sse-rr e #x66 #x6e to a0 1)      ; movq gpr->xmm  (reg=xmm to, rm=gpr a0)
        (sse-rr e #x66 #x7e a0 to 1))))   ; movq xmm->gpr  (reg=xmm a0, rm=gpr to)

;;; group-1 ALU: op -> (values reg-opcode  imm-/digit  commutative)
(defun alu-codes (op)
  (ecase op
    (:add (values #x01 0 t)) (:or  (values #x09 1 t)) (:and (values #x21 4 t))
    (:sub (values #x29 5 nil)) (:xor (values #x31 6 t))))

(defun enc-alu-imm (e digit imm dst cls)
  "op $imm, %dst  ->  83 /digit ib (imm8), the accumulator short form (op %rAX,
   imm32, opcode (digit<<3)|5, no ModRM -- what `as` picks for rAX), or 81 /digit."
  (let ((w (wbit cls)) (dr (rhw dst)))
    (maybe-rex e w 0 0 (ash dr -3))
    (cond ((<= -128 imm 127)
           (e8 e #x83) (e8 e (modrm 3 digit dr)) (e8 e (logand imm #xff)))
          ((zerop dr) (e8 e (logior (ash digit 3) 5)) (e32 e imm))   ; op %rAX, imm32
          (t (e8 e #x81) (e8 e (modrm 3 digit dr)) (e32 e imm)))))

(defun enc-alu (e i)
  (multiple-value-bind (rop dig commutative) (alu-codes (ins-op i))
    (when (and commutative (ref= (ins-arg1 i) (ins-to i)))
      (rotatef (ins-arg0 i) (ins-arg1 i)))
    (enc-copy e (ins-to i) (ins-arg0 i) (ins-cls i))
    (let ((a1 (ins-arg1 i)))
      (cond ((reg-p a1)      (rr e rop a1 (ins-to i) (ins-cls i)))
            ((con-bits-p a1) (enc-alu-imm e dig (con-rawbits a1) (ins-to i) (ins-cls i)))
            ((mem-operand-p a1)                              ; op mem, %to  (r,r/m form = rop+2)
             (enc-rm-mem e (rhw (ins-to i)) a1 (wbit (ins-cls i)) (list (+ rop 2))))
            (t (error "enc: TODO alu ~s arg1 ~s" (ins-op i) a1))))))

;;; sub (be-emit-sub): when the result reg IS the subtrahend (to==arg1, arg0!=to)
;;; a plain `copy arg0; sub arg1` would clobber arg1 -- emit `neg %to; add %arg0,%to`.
(defun enc-sub (e i)
  (if (and (ref= (ins-to i) (ins-arg1 i)) (not (ref= (ins-arg0 i) (ins-to i))))
      (let ((w (wbit (ins-cls i))) (dr (rhw (ins-to i))) (a0 (ins-arg0 i)))
        (maybe-rex e w 0 0 (ash dr -3)) (e8 e #xf7) (e8 e (modrm 3 3 dr))   ; neg %to
        (cond ((reg-p a0)          (rr e #x01 a0 (ins-to i) (ins-cls i)))   ; add %arg0, %to
              ((con-bits-p a0)     (enc-alu-imm e 0 (con-rawbits a0) (ins-to i) (ins-cls i)))
              ((mem-operand-p a0)  (enc-rm-mem e dr a0 w '(#x03)))
              (t (error "enc: TODO sub arg0 ~s" a0))))
      (enc-alu e i)))

;;; shifts (by imm8: C1 /digit ib; by cl: D3 /digit).  digit: shl4 shr5 sar7.
(defun enc-shift (e i digit)
  (enc-copy e (ins-to i) (ins-arg0 i) (ins-cls i))
  (let ((w (wbit (ins-cls i))) (dr (rhw (ins-to i))) (a1 (ins-arg1 i)))
    (maybe-rex e w 0 0 (ash dr -3))
    (cond ((and (con-bits-p a1) (= (con-rawbits a1) 1))    ; shift by 1: the short D1 /digit
           (e8 e #xD1) (e8 e (modrm 3 digit dr)))
          ((con-bits-p a1)
           (e8 e #xC1) (e8 e (modrm 3 digit dr)) (e8 e (logand (con-rawbits a1) #xff)))
          ((reg-p a1) (e8 e #xD3) (e8 e (modrm 3 digit dr)))     ; shift by %cl
          (t (error "enc: TODO shift arg1 ~s" a1)))))

;;; imul: reg form 0F AF /r (reg=dst); imm form 6B/69 /r (reg=dst, rm=src).
(defun enc-imul-imm (e dst src imm cls)
  (let ((w (wbit cls)) (dr (rhw dst)) (sr (rhw src)))
    (maybe-rex e w (ash dr -3) 0 (ash sr -3))
    (cond ((<= -128 imm 127) (e8 e #x6B) (e8 e (modrm 3 dr sr)) (e8 e (logand imm #xff)))
          (t (e8 e #x69) (e8 e (modrm 3 dr sr)) (e32 e imm)))))

(defun enc-mul (e i)
  (when (con-p (ins-arg1 i)) (rotatef (ins-arg0 i) (ins-arg1 i)))
  (if (and (member (ins-cls i) '(:w :l)) (con-bits-p (ins-arg0 i)) (reg-p (ins-arg1 i)))
      (enc-imul-imm e (ins-to i) (ins-arg1 i) (con-rawbits (ins-arg0 i)) (ins-cls i))
      (progn
        (when (ref= (ins-arg1 i) (ins-to i)) (rotatef (ins-arg0 i) (ins-arg1 i)))
        (enc-copy e (ins-to i) (ins-arg0 i) (ins-cls i))
        (rr2 e #x0F #xAF (ins-to i) (ins-arg1 i) (ins-cls i)))))   ; reg=dst, rm=src

;;; neg (F7 /3), after copying arg0 into to.
(defun enc-unary-digit (e i opcode digit)
  (enc-copy e (ins-to i) (ins-arg0 i) (ins-cls i))
  (let ((w (wbit (ins-cls i))) (dr (rhw (ins-to i))))
    (maybe-rex e w 0 0 (ash dr -3))
    (e8 e opcode) (e8 e (modrm 3 digit dr))))

;;; cmp (omap "cmp%k %0, %1"): reg/reg -> 39 /r (reg=arg0, rm=arg1); an immediate
;;; operand -> 81|83 /7 ib/id over the register; a folded memory operand -> 39/3B.
(defun enc-cmp (e i)
  (let ((a0 (ins-arg0 i)) (a1 (ins-arg1 i)) (cls (ins-cls i)))
    (cond
      ((fcls-p cls)                                         ; ucomiss/ucomisd %0, %1
       (sse-op e (if (eq cls :d) #x66 nil) #x2e a1 a0 0))
      ((and (reg-p a0) (reg-p a1))      (rr e #x39 a0 a1 cls))
      ((and (con-bits-p a0) (reg-p a1)) (enc-alu-imm e 7 (con-rawbits a0) a1 cls))
      ((and (reg-p a0) (con-bits-p a1)) (enc-alu-imm e 7 (con-rawbits a1) a0 cls))
      ((and (reg-p a0) (mem-operand-p a1)) (enc-rm-mem e (rhw a0) a1 (wbit cls) '(#x39)))
      ((and (mem-operand-p a0) (reg-p a1)) (enc-rm-mem e (rhw a1) a0 (wbit cls) '(#x3b)))
      (t (error "enc: TODO cmp ~s ~s" a0 a1)))))

;;; condition-suffix -> setcc/jcc opcode low nibble.
(defparameter *cc-nibble*
  '(("o" . 0) ("no" . 1) ("b" . 2) ("c" . 2) ("ae" . 3) ("nb" . 3)
    ("e" . 4) ("z" . 4) ("ne" . 5) ("nz" . 5) ("be" . 6) ("a" . 7)
    ("s" . 8) ("ns" . 9) ("p" . #xA) ("np" . #xB)
    ("l" . #xC) ("ge" . #xD) ("le" . #xE) ("g" . #xF)))
(defun cc-nibble (suf)
  (or (cdr (assoc suf *cc-nibble* :test #'string=))
      (error "enc: unknown cc suffix ~s" suf)))

;;; flag op: setcc %B= ; movzb%k %B=, %=  (emit.c flag-op path).  The byte target
;;; needs a forced REX to reach spl/bpl/sil/dil (else the field names ah/ch/dh/bh).
(defun enc-flag (e i)
  (let* ((c   (gethash (ins-op i) *flag-op-code*))
         (nib (cc-nibble (aref (aref *cc-suffix* c) 0)))
         (dr  (rhw (ins-to i))))
    (if (<= 4 dr 7) (e8 e #x40) (maybe-rex e 0 0 0 (ash dr -3)))    ; setcc %B= (0F 90+cc /0)
    (e8 e #x0F) (e8 e (+ #x90 nib)) (e8 e (modrm 3 0 dr))
    (let ((w (wbit (ins-cls i))))                                   ; movzb%k %B=, %=
      (if (and (zerop w) (<= 4 dr 7)) (e8 e #x40)
          (maybe-rex e w (ash dr -3) 0 (ash dr -3))))
    (e8 e #x0F) (e8 e #xB6) (e8 e (modrm 3 dr dr))))

;;; movslq %arg0, %to   (REX.W 63 /r, reg=to, rm=arg0).
(defun enc-movslq (e i)
  (let ((dr (rhw (ins-to i))) (sr (rhw (ins-arg0 i))))
    (maybe-rex e 1 (ash dr -3) 0 (ash sr -3))
    (e8 e #x63) (e8 e (modrm 3 dr sr))))

;;; ---- integer division: sign-extend + (i)div (rax:rdx implicit) -----------
(defun enc-sign (e i)                        ; cltd (99) / cqto (REX.W 99)
  (when (kwide (ins-cls i)) (e8 e #x48)) (e8 e #x99))

(defun enc-xdiv (e i digit)                  ; div%k /6 or idiv%k /7 over arg0
  (let ((a0 (ins-arg0 i)) (w (wbit (ins-cls i))))
    (if (mem-operand-p a0)
        (enc-rm-mem e digit a0 w '(#xf7))
        (progn (maybe-rex e w 0 0 (ash (rhw a0) -3))
               (e8 e #xf7) (e8 e (modrm 3 digit (rhw a0)))))))

;;; ---- loads / stores / addr (omap mov* + lea over a memory operand) --------
(defun enc-load (e i)
  "Load a memory operand into a register (mirrors omap load*)."
  (let ((cls (ins-cls i)) (dst (rhw (ins-to i))) (src (ins-arg0 i)))
    (ecase (ins-op i)
      (:load   (if (fcls-p cls)                                       ; movss/movsd
                   (enc-rm-mem e dst src 0 (list #x0f #x10) :prefix (fpfx cls))
                   (enc-rm-mem e dst src (wbit cls) '(#x8b))))         ; mov%k
      (:loaduw (enc-rm-mem e dst src 0 '(#x8b)))                       ; movl (zero-ext)
      (:loadsw (if (kwide cls) (enc-rm-mem e dst src 1 '(#x63))        ; movslq
                   (enc-rm-mem e dst src 0 '(#x8b))))                  ; movl
      (:loadsh (enc-rm-mem e dst src (wbit cls) '(#x0f #xbf)))         ; movsw%k
      (:loaduh (enc-rm-mem e dst src (wbit cls) '(#x0f #xb7)))         ; movzw%k
      (:loadsb (enc-rm-mem e dst src (wbit cls) '(#x0f #xbe)))         ; movsb%k
      (:loadub (enc-rm-mem e dst src (wbit cls) '(#x0f #xb6))))))      ; movzb%k

(defun enc-store-imm (e op imm mem)
  "Store an immediate into a memory operand: movb/w/l/q $imm, mem (C6/C7 /0)."
  (ecase op
    (:storeb (enc-rm-mem e 0 mem 0 '(#xc6) :tail 1) (e8 e (logand imm #xff)))
    (:storeh (enc-rm-mem e 0 mem 0 '(#xc7) :prefix #x66 :tail 2) (e16 e imm))
    (:storew (enc-rm-mem e 0 mem 0 '(#xc7) :tail 4) (e32 e imm))
    (:storel (enc-rm-mem e 0 mem 1 '(#xc7) :tail 4) (e32 e imm))))    ; imm32 sign-ext to 64

(defun xmm-ref-p (r) (and (reg-p r) (>= (reg-id r) +xmm0+)))

(defun enc-store (e i)
  "Store a register (or immediate) into a memory operand (mirrors omap store*).
   An xmm source stored as a raw int word uses the SSE movq/movd store."
  (let ((a0 (ins-arg0 i)) (mem (ins-arg1 i)) (op (ins-op i)))
    (cond
      ((con-bits-p a0) (enc-store-imm e op (con-rawbits a0) mem))
      ((and (xmm-ref-p a0) (member op '(:storel :storew)))
       (if (eq op :storel)
           (enc-rm-mem e (rhw a0) mem 0 '(#x0f #xd6) :prefix #x66)        ; movq %xmm, m64
           (enc-rm-mem e (rhw a0) mem 0 '(#x0f #x7e) :prefix #x66)))      ; movd %xmm, m32
      (t (let ((val (rhw a0)))
           (ecase op
             (:storel (enc-rm-mem e val mem 1 '(#x89)))                    ; movq
             (:storew (enc-rm-mem e val mem 0 '(#x89)))                    ; movl
             (:storeh (enc-rm-mem e val mem 0 '(#x89) :prefix #x66))       ; movw
             (:storeb (enc-rm-mem e val mem 0 '(#x88) :rex8 t))            ; movb
             (:stores (enc-rm-mem e val mem 0 '(#x0f #x11) :prefix #xf3))  ; movss
             (:stored (enc-rm-mem e val mem 0 '(#x0f #x11) :prefix #xf2))))))))  ; movsd

;;; cmov (be-emit-xsel): cmov%cc %src, %dst = 0F 40+cc /r (reg=dst, rm=src),
;;; the src being a register or a folded memory operand.
(defun enc-xsel (e i)
  (let* ((c (position (ins-op i) *xsel-ops*)) (cls (ins-cls i)) (to (ins-to i)))
    (flet ((cmov (suf src)
             (let ((nib (cc-nibble suf)))
               (if (mem-operand-p src)
                   (enc-rm-mem e (rhw to) src (wbit cls) (list #x0f (+ #x40 nib)))
                   (rr2 e #x0f (+ #x40 nib) to src cls)))))
      (if (ref= to (ins-arg1 i))
          (cmov (aref (aref *cc-suffix* c) 0) (ins-arg0 i))
          (progn (unless (ref= to (ins-arg0 i)) (enc-copy e to (ins-arg0 i) cls))
                 (cmov (aref (aref *cc-suffix* c) 1) (ins-arg1 i)))))))

;;; test (omap "test%k %0, %1"): 85 /r; an immediate -> A9 id (rAX) or F7 /0 id.
(defun enc-test-imm (e imm dst cls)
  (let ((w (wbit cls)) (dr (rhw dst)))
    (maybe-rex e w 0 0 (ash dr -3))
    (cond ((zerop dr) (e8 e #xa9) (e32 e imm))                        ; test %rAX, imm32
          (t (e8 e #xf7) (e8 e (modrm 3 0 dr)) (e32 e imm)))))        ; test /0
(defun enc-test (e i)
  (let ((a0 (ins-arg0 i)) (a1 (ins-arg1 i)) (cls (ins-cls i)))
    (cond
      ((and (reg-p a0) (reg-p a1))         (rr e #x85 a0 a1 cls))
      ((and (con-bits-p a1) (reg-p a0))    (enc-test-imm e (con-rawbits a1) a0 cls))
      ((and (con-bits-p a0) (reg-p a1))    (enc-test-imm e (con-rawbits a0) a1 cls))
      ((and (reg-p a0) (mem-operand-p a1)) (enc-rm-mem e (rhw a0) a1 (wbit cls) '(#x85)))
      ((and (mem-operand-p a0) (reg-p a1)) (enc-rm-mem e (rhw a1) a0 (wbit cls) '(#x85)))
      (t (error "enc: TODO test ~s ~s" a0 a1)))))

;;; swap (be-emit-swap): xchg%k %0, %1 (87 /r) for ints; xmm15 bounce for floats.
(defun enc-swap (e i)
  (let ((cls (ins-cls i)))
    (if (fcls-p cls)
        (let ((x15 (rg (+ +xmm0+ 15))))
          (enc-fcopy e x15 (ins-arg0 i) cls)
          (enc-fcopy e (ins-arg0 i) (ins-arg1 i) cls)
          (enc-fcopy e (ins-arg1 i) x15 cls))
        (rr e #x87 (ins-arg0 i) (ins-arg1 i) cls))))

;;; byte/half extends (movsx/movzx reg or mem source); BYTE forces REX to reach a
;;; low-byte source (sil/dil/spl/bpl).  Same opcodes as the byte/half loads.
(defun enc-ext2 (e i op0 op1 &key byte)
  (let ((to (ins-to i)) (a0 (ins-arg0 i)) (cls (ins-cls i)))
    (if (mem-operand-p a0)
        (enc-rm-mem e (rhw to) a0 (wbit cls) (list op0 op1))
        (let ((rn (rhw to)) (mn (rhw a0)) (w (wbit cls)))
          (if (and byte (<= 4 mn 7) (zerop (logior w (ash rn -3) (ash mn -3))))
              (e8 e #x40) (maybe-rex e w (ash rn -3) 0 (ash mn -3)))
          (e8 e op0) (e8 e op1) (e8 e (modrm 3 rn mn))))))

;;; salloc (dynamic stack alloc): subq %arg0, %rsp; movq %rsp, %to.
(defun enc-salloc (e i)
  (let ((a0 (ins-arg0 i)))
    (if (con-bits-p a0)
        (alu-imm-hw e 5 (con-rawbits a0) (hwid +rsp+) 1)     ; subq $imm, %rsp
        (rr e #x29 a0 (rg +rsp+) :l)))                     ; subq %arg0, %rsp
  (when (ins-to i) (enc-copy e (ins-to i) (rg +rsp+) :l)))

;;; ---- instruction dispatch (mirrors be-emitins) ---------------------------
(defun enc-ins (e i)
  (let ((op (ins-op i)))
    (cond
      ((eq op :nop))
      ((eq op :call) (enc-call e i))
      ((and (fcls-p (ins-cls i)) (member op '(:add :sub :mul :div)))
       (enc-fbin e i (ecase op (:add #x58) (:sub #x5c) (:mul #x59) (:div #x5e))
                 (member op '(:add :mul))))
      ((member op '(:swtof :sltof :stosi :dtosi :exts :truncd)) (enc-fconv e i))
      ((eq op :cast) (enc-cast e i))
      ((eq op :copy) (if (fcls-p (ins-cls i))
                         (enc-fcopy e (ins-to i) (ins-arg0 i) (ins-cls i))
                         (enc-copy e (ins-to i) (ins-arg0 i) (ins-cls i))))
      ((eq op :sub) (enc-sub e i))
      ((member op '(:add :or :and :xor)) (enc-alu e i))
      ((eq op :shl) (enc-shift e i 4))
      ((eq op :shr) (enc-shift e i 5))
      ((eq op :sar) (enc-shift e i 7))
      ((eq op :mul) (enc-mul e i))
      ((eq op :neg) (enc-unary-digit e i #xF7 3))
      ((eq op :xcmp) (enc-cmp e i))
      ((eq op :extsw) (enc-movslq e i))
      ((eq op :extuw) (rr e #x89 (ins-arg0 i) (ins-to i) :w))    ; movl zero-extends
      ((eq op :extsb) (enc-ext2 e i #x0f #xbe :byte t))          ; movsb%k
      ((eq op :extub) (enc-ext2 e i #x0f #xb6 :byte t))          ; movzb%k
      ((eq op :extsh) (enc-ext2 e i #x0f #xbf))                  ; movsw%k
      ((eq op :extuh) (enc-ext2 e i #x0f #xb7))                  ; movzw%k
      ((member op '(:load :loaduw :loadsw :loadsh :loaduh :loadsb :loadub)) (enc-load e i))
      ((member op '(:storel :storew :storeh :storeb :stores :stored)) (enc-store e i))
      ((eq op :addr) (enc-rm-mem e (rhw (ins-to i)) (ins-arg0 i) (wbit (ins-cls i)) '(#x8d)))
      ((eq op :sign) (enc-sign e i))
      ((eq op :xdiv) (enc-xdiv e i 6))
      ((eq op :xidiv) (enc-xdiv e i 7))
      ((eq op :xtest) (enc-test e i))
      ((eq op :swap) (enc-swap e i))
      ((eq op :salloc) (enc-salloc e i))
      ((find op *xsel-ops*) (enc-xsel e i))
      ((gethash op *flag-op-code*) (enc-flag e i))
      (t (error "enc: TODO op ~s (cls ~s)" op (ins-cls i))))))

;;; ---- calls (be-emit-call) ------------------------------------------------
;;; callq sym -> E8 rel32 (field 0) + a PLT32 fixup; solder patches it, resolving
;;; internal symbols directly and externs through a stub.  Reg call = FF /2.
(defun enc-call (e i)
  (let ((a0 (ins-arg0 i)))
    (cond
      ((con-p a0)
       (e8 e #xe8)
       (let ((pos (here e)))
         (e32 e 0)
         (push (list :offset pos :symbol (con-symname a0) :kind :plt32 :addend -4)
               (enc-fixups e))))
      ((reg-p a0)
       (maybe-rex e 0 0 0 (ash (rhw a0) -3))
       (e8 e #xff) (e8 e (modrm 3 2 (rhw a0))))
      (t (error "enc: invalid call argument ~s" a0)))))

;;; ---- register-number-level prims for frame code --------------------------
(defun hwid (id) (aref *reg-hw* id))

(defun rr-hw (e opcode reg rm w)
  (maybe-rex e w (ash reg -3) 0 (ash rm -3))
  (e8 e opcode) (e8 e (modrm 3 reg rm)))

(defun alu-imm-hw (e digit imm dr w)
  (maybe-rex e w 0 0 (ash dr -3))
  (cond ((<= -128 imm 127) (e8 e #x83) (e8 e (modrm 3 digit dr)) (e8 e (logand imm #xff)))
        (t (e8 e #x81) (e8 e (modrm 3 digit dr)) (e32 e imm))))

(defun enc-push (e hw) (when (>= hw 8) (e8 e #x41)) (e8 e (logior #x50 (logand hw 7))))
(defun enc-pop  (e hw) (when (>= hw 8) (e8 e #x41)) (e8 e (logior #x58 (logand hw 7))))

;;; ---- p2align NOP fill -----------------------------------------------------
;;; gas's amd64 code-alignment NOP table (verified byte-exact via `.nops N` and
;;; against a real loop's `.p2align 4`): greedy single NOP up to 11 bytes, then
;;; chain 11-byte fills + the remainder.
(defparameter *nop-patt*
  #(#()
    #(#x90)
    #(#x66 #x90)
    #(#x0F #x1F #x00)
    #(#x0F #x1F #x40 #x00)
    #(#x0F #x1F #x44 #x00 #x00)
    #(#x66 #x0F #x1F #x44 #x00 #x00)
    #(#x0F #x1F #x80 #x00 #x00 #x00 #x00)
    #(#x0F #x1F #x84 #x00 #x00 #x00 #x00 #x00)
    #(#x66 #x0F #x1F #x84 #x00 #x00 #x00 #x00 #x00)
    #(#x66 #x2E #x0F #x1F #x84 #x00 #x00 #x00 #x00 #x00)
    #(#x66 #x66 #x2E #x0F #x1F #x84 #x00 #x00 #x00 #x00 #x00)))

(defun emit-nop-fill (e n)
  (loop while (> n 0) for k = (min n 11)
        do (loop for b across (aref *nop-patt* k) do (e8 e b)) (decf n k)))

;;; ---- span-dependent items (jumps + aligns) relaxed to a fixpoint ----------
;;; A function body is a list of ITEMs in layout order; jumps start optimistic
;;; (short, 2 B) and grow to near only when the displacement overflows int8, so
;;; the result matches `as`'s jump relaxation byte-for-byte.
(defstruct (item (:conc-name it-))
  kind                 ; :bytes :label :align :jmp :jcc
  bytes fix            ; :bytes -> octet vector + local fixup plists
  id                   ; :label -> block id
  target nib           ; :jmp/:jcc -> target block id (+ jcc opcode low nibble)
  (size 0) (off 0))

(defun chunk-item (es thunk)
  "Encode THUNK into a fresh enc (carrying ES for slot resolution); wrap its bytes
   + chunk-local fixups as a :bytes item."
  (let ((e (make-enc :es es)))
    (funcall thunk e)
    (make-item :kind :bytes :bytes (copy-seq (enc-buf e))
               :fix (nreverse (enc-fixups e)))))

;;; epilogue (mirrors be-emit-epilogue): pop callee-saves, leave/add, ret.
(defun enc-epilogue (e es)
  (let ((fn (es-fn es)))
    (when (fn-dynalloc fn)                        ; rsp moved by salloc: restore it first
      (rr-hw e #x89 (hwid +rbp+) (hwid +rsp+) 1)  ; movq %rbp, %rsp
      (alu-imm-hw e 5 (+ (es-fsz es) (* (es-nclob es) 8)) (hwid +rsp+) 1))  ; subq $..,%rsp
    (loop for k from (1- (length *rclob*)) downto 0
          for rc = (aref *rclob* k)
          when (logbitp rc (fn-reg fn))
            do (enc-pop e (hwid rc)))
    (cond ((= (es-fp es) +rbp+) (e8 e #xc9))                       ; leave
          ((> (es-fsz es) 0) (alu-imm-hw e 0 (es-fsz es) (hwid +rsp+) 1)))  ; addq $fsz,%rsp
    (e8 e #xc3)))                                                  ; ret

;;; plan a block's terminator -> (values list-of-items next-lbl?), mirroring
;;; be-emit-jmp exactly (successor rotate, cc-suffix selection, fallthrough).
(defun plan-term (b es)
  (case (blk-jmp-type b)
    (:hlt  (values (list (make-item :kind :bytes :bytes #(#x0f #x0b))) t))
    (:ret0 (values (list (chunk-item es (lambda (e) (enc-epilogue e es)))) t))
    (:jmp  (if (eq (blk-s1 b) (blk-link b))
               (values nil nil)
               (values (list (make-item :kind :jmp :target (blk-id (blk-s1 b)))) t)))
    (t (let ((c (gethash (blk-jmp-type b) *jf-jump-code*)) s1 s2 n)
         (unless c (error "enc: unhandled jump ~s" (blk-jmp-type b)))
         (if (eq (blk-link b) (blk-s2 b))
             (setf s1 (blk-s2 b) s2 (blk-s1 b) n 0)     ; rotatef: fallthrough is s2
             (setf s1 (blk-s1 b) s2 (blk-s2 b) n 1))
         (let* ((nib (cc-nibble (aref (aref *cc-suffix* c) n)))
                (jcc (make-item :kind :jcc :nib nib :target (blk-id s2))))
           (if (eq s1 (blk-link b))
               (values (list jcc) nil)
               (values (list jcc (make-item :kind :jmp :target (blk-id s1))) t)))))))

(defun relax-items (items)
  "Assign each item a size+offset to a fixpoint; return a blk-id -> offset table."
  (dolist (it items)
    (setf (it-size it) (ecase (it-kind it)
                         (:bytes (length (it-bytes it)))
                         ((:label :align) 0)
                         ((:jmp :jcc) 2))))          ; optimistic short
  (let ((labels (make-hash-table)))
    (dotimes (pass 100 (error "enc: jump relaxation did not converge"))
      (let ((pos 0) (changed nil))
        (dolist (it items)                            ; assign offsets, size aligns
          (when (eq (it-kind it) :align)
            (let ((pad (logand (- pos) 15)))          ; bytes to next 16-boundary
              (unless (= pad (it-size it)) (setf (it-size it) pad changed t))))
          (setf (it-off it) pos)
          (when (eq (it-kind it) :label) (setf (gethash (it-id it) labels) pos))
          (incf pos (it-size it)))
        (dolist (it items)                            ; grow jumps that overflow int8
          (when (member (it-kind it) '(:jmp :jcc))
            (let ((disp (- (gethash (it-target it) labels) (+ (it-off it) (it-size it)))))
              (when (and (= (it-size it) 2) (not (<= -128 disp 127)))
                (setf (it-size it) (if (eq (it-kind it) :jmp) 5 6) changed t)))))
        (unless changed (return labels))))))

(defun emit-items (fn items)
  "Relax ITEMS, then emit final bytes -> (values code symbols fixups)."
  (let ((labels (relax-items items)) (e (make-enc)))
    (dolist (it items)
      (ecase (it-kind it)
        (:label)
        (:align (emit-nop-fill e (it-size it)))
        (:bytes (let ((base (here e)))
                  (loop for b across (it-bytes it) do (e8 e b))
                  (dolist (fx (it-fix it))
                    (push (list :offset (+ base (getf fx :offset)) :symbol (getf fx :symbol)
                                :kind (getf fx :kind) :addend (getf fx :addend))
                          (enc-fixups e)))))
        (:jmp (let ((tgt (gethash (it-target it) labels)))
                (cond ((= (it-size it) 2) (e8 e #xeb) (e8 e (logand (- tgt (+ (here e) 1)) #xff)))
                      (t (e8 e #xe9) (e32 e (- tgt (+ (here e) 4)))))))
        (:jcc (let ((tgt (gethash (it-target it) labels)))
                (cond ((= (it-size it) 2)
                       (e8 e (+ #x70 (it-nib it))) (e8 e (logand (- tgt (+ (here e) 1)) #xff)))
                      (t (e8 e #x0f) (e8 e (+ #x80 (it-nib it))) (e32 e (- tgt (+ (here e) 4)))))))))
    (values (coerce (enc-buf e) '(simple-array (unsigned-byte 8) (*)))
            (list (cons (fn-name fn) 0))
            (nreverse (enc-fixups e)))))

;;; ---- function level (mirrors be-emit-fn / be-emit-epilogue) --------------
(defun enc-vararg-save (e)
  "amd64 SysV vararg register-save area at -176(%rbp): the six integer arg regs
   (movq) then xmm0..7 (movaps), so va_start can spill them."
  (flet ((rbpm (o) (make-mem :base (rg +rbp+) :offset (make-con :kind :bits :value o))))
    (let ((o -176))
      (dolist (rid (list +rdi+ +rsi+ +rdx+ +rcx+ +r8+ +r9+))
        (enc-rm-mem e (hwid rid) (rbpm o) 1 '(#x89))       ; movq %reg, o(%rbp)
        (incf o 8))
      (dotimes (n 8)
        (enc-rm-mem e n (rbpm o) 0 '(#x0f #x29))           ; movaps %xmmN, o(%rbp)
        (incf o 16)))))

(defun enc-prologue (e es)
  (let ((fn (es-fn es)))
    (e8 e #xf3) (e8 e #x0f) (e8 e #x1e) (e8 e #xfa)       ; endbr64
    (when (= (es-fp es) +rbp+)
      (enc-push e (hwid +rbp+))                           ; pushq %rbp
      (rr-hw e #x89 (hwid +rsp+) (hwid +rbp+) 1))         ; movq %rsp, %rbp
    (when (> (es-fsz es) 0)
      (alu-imm-hw e 5 (es-fsz es) (hwid +rsp+) 1))        ; subq $fsz, %rsp
    (when (fn-vararg fn) (enc-vararg-save e))             ; spill arg regs (va_start)
    (loop for rc across *rclob*                            ; callee-save pushes
          when (logbitp rc (fn-reg fn))
            do (enc-push e (hwid rc)) (incf (es-nclob es)))))

(defun enc-fn (fn)
  "Encode a backend-pipelined FN to (values code-bytes symbols fixups)."
  (let* ((leaf (notany (lambda (b) (some (lambda (i) (eq (ins-op i) :call)) (blk-ins b)))
                       (fn-blocks fn)))
         (es (make-es :fn fn :leaf leaf))
         (items '()) (lbl nil))
    ;; a non-leaf, vararg, or dynalloc function needs the rbp frame (be-emit-fn)
    (setf (es-fp es) (if (and leaf (not (fn-vararg fn)) (not (fn-dynalloc fn))) +rsp+ +rbp+))
    (be-framesz es)                                       ; -> es-fsz (reuse emit.c logic)
    (push (chunk-item es (lambda (e) (enc-prologue e es))) items)
    ;; body, layout order.  A block gets a label when the prior block didn't fall
    ;; through into it or it has >1 preds; a loop header (some pred id >= its own)
    ;; additionally gets a `.p2align 4`.  (Mirrors be-emit-fn's label placement.)
    (loop for b = (fn-start fn) then (blk-link b) while b do
      (when (and (or lbl (> (length (blk-preds b)) 1))
                 (some (lambda (p) (>= (blk-id p) (blk-id b))) (blk-preds b)))
        (push (make-item :kind :align) items))
      (push (make-item :kind :label :id (blk-id b)) items)
      (push (chunk-item es (lambda (e) (dolist (i (blk-ins b)) (enc-ins e i)))) items)
      (multiple-value-bind (titems next-lbl) (plan-term b es)
        (dolist (it titems) (push it items))
        (setf lbl next-lbl)))
    (emit-items fn (nreverse items))))

;;; ---- data sections (mirrors be-emit-data / emit-fin) ----------------------
;;; The as-less analogue of emitting `.data`/`.rodata`: a `dat` (or the fp-const
;;; pool) becomes bytes + defined symbols + relocations, ready for a solder obj.
(defun make-octets () (make-array 16 :element-type '(unsigned-byte 8)
                                     :adjustable t :fill-pointer 0))
(defun push-int (buf value size)
  (dotimes (k size) (vector-push-extend (ldb (byte 8 (* 8 k)) value) buf)))

(defun unescape-str (s)
  "S is a GAS `.ascii` literal including its surrounding quotes; return its octets."
  (let ((out (make-octets)) (n (length s)) (i 1))          ; skip the opening quote
    (loop while (< i (1- n)) do                             ; stop before the closing quote
      (let ((c (char s i)))
        (cond ((char= c #\\)
               (incf i)
               (vector-push-extend
                (case (char s i) (#\n 10) (#\t 9) (#\r 13) (#\0 0)
                      (#\\ 92) (#\" 34) (t (char-code (char s i)))) out)
               (incf i))
              (t (vector-push-extend (char-code c) out) (incf i)))))
    out))

(defun enc-data (d)
  "Encode a `dat` -> (values octets symbols fixups writable) for a solder obj.
   `:ref` pointer items become ABS64 relocations to the referenced symbol."
  (let ((buf (make-octets)) (fixups '()))
    (dolist (it (dat-items d))
      (ecase (first it)
        (:int  (destructuring-bind (size value) (rest it) (push-int buf value size)))
        (:zero (dotimes (k (second it)) (vector-push-extend 0 buf)))
        (:str  (loop for b across (unescape-str (second it)) do (vector-push-extend b buf)))
        (:ref  (destructuring-bind (size name off) (rest it)
                 (unless (= size 8) (error "enc-data: TODO ~d-byte ref" size))
                 (push (list :offset (fill-pointer buf) :symbol name :kind :abs64 :addend off)
                       fixups)
                 (push-int buf 0 8)))))
    (when (dat-thread d) (error "enc-data: TODO thread-local ~a" (dat-name d)))
    (values (coerce buf '(simple-array (unsigned-byte 8) (*)))
            (list (cons (dat-name d) 0)) (nreverse fixups) t)))

(defun enc-stash ()
  "Encode the fp-constant pool (*stash*) -> (values octets symbols) for a rodata
   obj.  Each entry lands size-aligned under the same quoted `.LfpN` name that
   isel's rip-relative operands reference."
  (let ((buf (make-octets)) (syms '()))
    (dotimes (i (fill-pointer *stash*))
      (destructuring-bind (bits . size) (aref *stash* i)
        (loop until (zerop (mod (fill-pointer buf) size)) do (vector-push-extend 0 buf))
        (push (cons (format nil "\".Lfp~d\"" i) (fill-pointer buf)) syms)
        (push-int buf bits size)))
    (values (coerce buf '(simple-array (unsigned-byte 8) (*))) (nreverse syms))))
