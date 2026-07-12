;;;; arm64-encode.lisp --- G6: AArch64 machine-code encoder (bytes + fixups).
;;;;
;;;; The "as-less" JIT path for arm64_apple: emits AArch64 machine code + a
;;;; relocation list instead of text asm, feeding solder's bytes+fixups loader.
;;;; Verified byte-exact against Apple `as` over the same functions the text
;;;; emitter (arm64-emit.lisp) produces (test/arm64-encode.lisp).
;;;;
;;;; AArch64 is fixed-width (every instruction is one little-endian 32-bit word),
;;;; so there is no ModRM/REX/length variability; each encoder just packs the
;;;; instruction's bitfields.  Branch targets are still span-dependent but every
;;;; branch is one word, so "relaxation" only resolves label offsets (no growth).
;;;;
;;;; This mirrors arm64-emit.lisp instruction-for-instruction; that text path is
;;;; the byte-exact oracle for this one.

(in-package #:qbe)

;;; ------------------------------------------------------------------ buffer
(defstruct (aenc (:conc-name aenc-))
  (buf (make-array 64 :element-type '(unsigned-byte 8) :adjustable t :fill-pointer 0))
  (fixups '())          ; reversed list of fixup plists (:offset :symbol :kind :addend)
  es)                   ; emit-state for slot resolution (shares ae/framelayout)

(defun aw (e word)
  "Append one 32-bit AArch64 instruction WORD (little-endian)."
  (let ((w (logand word #xffffffff)))
    (dotimes (k 4) (vector-push-extend (ldb (byte 8 (* 8 k)) w) (aenc-buf e)))))

(defun ahere (e) (fill-pointer (aenc-buf e)))

;;; ------------------------------------------------------------------ registers
;;; AArch64 register field encoding: x0..x30 = 0..30, and 31 means either SP or
;;; XZR/WZR depending on the instruction slot.  Our register ids: R0=1..LR=31
;;; map to hw 0..30; SP(id 32) and V0(id 33)..V30 map to fp hw 0..30.
(defun a64-hw (r)
  "Hardware register number (0..31) for a register id or reg object R."
  (let ((id (if (reg-p r) (reg-id r) r)))
    (cond
      ((= id +a64-sp+) 31)                       ; SP / XZR slot
      ((<= +a64-r0+ id +a64-lr+) (- id +a64-r0+))
      ((<= +a64-v0+ id (+ +a64-v0+ 30)) (- id +a64-v0+))
      ((= id +a64-v31+) 31)
      (t (error "arm64 enc: bad register id ~d" id)))))

(defun a64-rhw (ref) (a64-hw (reg-id ref)))

;;; ------------------------------------------------------------------ common forms
(defun a64-sf (cls) (if (kwide cls) 1 0))       ; 64-bit operand size bit

;;; Add/sub (shifted register): sf|op|S|01011|shift(2)|0|Rm|imm6|Rn|Rd.  When SP
;;; is Rn or Rd, AArch64 requires the extended-register form instead (as does
;;; `as`): sf|op|S|01011|00|1|Rm|option(3)|imm3|Rn|Rd, option = UXTX(011)/UXTW.
(defun a64-addsub-reg (e op cls rd rn rm &optional (setflags 0))
  (if (or (= (reg-id rn) +a64-sp+) (and (= setflags 0) (= (reg-id rd) +a64-sp+)))
      (let ((option (if (kwide cls) #b011 #b010)))    ; UXTX (64) / UXTW (32)
        (aw e (logior (ash (a64-sf cls) 31) (ash op 30) (ash setflags 29)
                      (ash #b01011001 21) (ash (a64-hw rm) 16) (ash option 13)
                      (ash (a64-hw rn) 5) (a64-hw rd))))
      (aw e (logior (ash (a64-sf cls) 31) (ash op 30) (ash setflags 29)
                    (ash #b01011 24) (ash (a64-hw rm) 16) (ash (a64-hw rn) 5) (a64-hw rd)))))

;;; Add/sub (immediate): sf|op|S|100010|sh|imm12|Rn|Rd
(defun a64-addsub-imm (e op cls rd rn imm12 &optional (setflags 0) (sh 0))
  (aw e (logior (ash (a64-sf cls) 31) (ash op 30) (ash setflags 29)
                (ash #b100010 23) (ash sh 22) (ash (logand imm12 #xfff) 10)
                (ash (a64-hw rn) 5) (a64-hw rd))))

;;; Logical (shifted register): sf|opc(2)|01010|shift(2)|N|Rm|imm6|Rn|Rd
(defun a64-logic-reg (e opc cls rd rn rm)
  (aw e (logior (ash (a64-sf cls) 31) (ash opc 29) (ash #b01010 24)
                (ash (a64-hw rm) 16) (ash (a64-hw rn) 5) (a64-hw rd))))

;;; Data-processing (2 source): sf|0|0|11010110|Rm|opcode(6)|Rn|Rd  (div, lsl/lsr/asr var)
(defun a64-dp2 (e cls rd rn rm opcode6)
  (aw e (logior (ash (a64-sf cls) 31) (ash #b0011010110 21)
                (ash (a64-hw rm) 16) (ash opcode6 10) (ash (a64-hw rn) 5) (a64-hw rd))))

;;; Data-processing (3 source): sf|00|11011|op31(3)|Rm|o0|Ra|Rn|Rd  (madd/msub/mul)
(defun a64-dp3 (e cls rd rn rm ra op31 o0)
  (aw e (logior (ash (a64-sf cls) 31) (ash #b11011 24) (ash op31 21)
                (ash (a64-hw rm) 16) (ash o0 15) (ash (a64-hw ra) 10)
                (ash (a64-hw rn) 5) (a64-hw rd))))

;;; ------------------------------------------------------------------ mov immediate
;;; movz/movn/movk: sf|opc(2)|100101|hw(2)|imm16|Rd
(defun a64-movzknq (e opc cls rd imm16 shift-hw)
  (aw e (logior (ash (a64-sf cls) 31) (ash opc 29) (ash #b100101 23)
                (ash shift-hw 21) (ash (logand imm16 #xffff) 5) (a64-hw rd))))

;;; Single-lane MOVZ/MOVN check: is VAL (WIDTH bits) covered by one 16-bit lane
;;; (movz), or its complement (movn)?  Returns (values kind lane shift) or NIL.
;;; This is `as`'s `mov #imm` alias precedence: a single-lane movz/movn wins over
;;; the logical-immediate ORR form.
(defun a64-movwide-lane (val width)
  (let ((uval (logand val (1- (ash 1 width)))))
    (dolist (shift (if (= width 64) '(0 16 32 48) '(0 16)) nil)
      (when (= uval (logand (ash (logand (ash uval (- shift)) #xffff) shift)
                            (1- (ash 1 width))))
        (return-from a64-movwide-lane (values :z (logand (ash uval (- shift)) #xffff) shift))))
    (let ((cval (logand (lognot uval) (1- (ash 1 width)))))
      (dolist (shift (if (= width 64) '(0 16 32 48) '(0 16)) nil)
        (when (= cval (logand (ash (logand (ash cval (- shift)) #xffff) shift)
                              (1- (ash 1 width))))
          (return-from a64-movwide-lane
            (values :n (logand (ash cval (- shift)) #xffff) shift)))))))

(defun a64-enc-loadcon-bits (e c rd cls)
  "arm64/emit.c loadcon (CBits path): materialize integer const C into RD.
The `mov #imm` alias picks (in `as`'s order) MOVZ/MOVN single-lane, then the
logical-immediate ORR, then MOVZ+MOVK lanes."
  (let* ((w (kwide cls)) (n (con-rawbits c)) (width (if w 64 32)))
    (unless w (setf n (s32* n)))
    (cond
      ;; MOVN whole-value shortcut (emit.c: (n | 0xffff) == -1)
      ((= (logior n #xffff) -1)
       (a64-movzknq e #b00 cls rd (logand (lognot n) #xffff) 0))  ; movn rd,#~n16
      ((multiple-value-bind (kind lane shift) (a64-movwide-lane n width)
         (when kind
           (a64-movzknq e (if (eq kind :z) #b10 #b00) cls rd lane (floor shift 16))
           t)))
      ((arm64-logimm n cls)
       (a64-log-imm-mov e rd n cls))                              ; orr rd,xzr,#imm (mov alias)
      (t
       ;; movz low, then movk the nonzero 16-bit lanes (matches emit.c's loop)
       (a64-movzknq e #b10 cls rd (logand n #xffff) 0)            ; movz rd,#n16
       (let ((sh 16) (nn (ash n -16)))
         (loop while (/= nn 0) do
           (when (or (and (not w) (= sh 32)) (= sh 64)) (return))
           (a64-movzknq e #b11 cls rd (logand nn #xffff) (floor sh 16))  ; movk
           (setf nn (ash nn -16)) (incf sh 16)))))))

;;; Logical immediate mov (orr Rd, XZR, #imm) — for constants arm64-logimm accepts.
(defun a64-log-imm-mov (e rd n cls)
  (multiple-value-bind (nbit immr imms) (a64-logimm-fields n cls)
    (aw e (logior (ash (a64-sf cls) 31) (ash #b01100100 23) (ash nbit 22)
                  (ash immr 16) (ash imms 10) (ash 31 5) (a64-hw rd)))))

;;; The N:immr:imms bitmask-immediate encoding (shared by logical-immediate ops
;;; and the ORR-based mov).  Inverse of the ARM ARM DecodeBitMasks: find the
;;; element size (a power of two whose lane repeats across 64 bits), the number
;;; of set bits (a contiguous run after rotation), and the rotation.
(defun a64-logimm-fields (n cls)
  (let* ((width (if (kwide cls) 64 32))
         (val (logand n (1- (ash 1 width)))))
    (when (or (= val 0) (= val (1- (ash 1 width))))
      (error "arm64 enc: 0 / all-ones not a logical immediate"))
    ;; find the smallest element size whose lane repeats
    (let ((size width))
      (loop for sz = (ash size -1) then (ash sz -1)
            while (>= sz 2)
            do (let ((mask (1- (ash 1 sz))))
                 (if (= (logand val mask) (logand (ash val (- sz)) mask))
                     (setf size sz val (logand val mask))
                     (return))))
      ;; val now holds one element of `size` bits; it must be a rotated run of 1s
      (let* ((esize size) (emask (1- (ash 1 esize))))
        ;; rotate so the run is right-aligned (trailing 1s, no gap in the middle)
        (let ((rot 0) (x val))
          ;; bring a 0-1 boundary to bit 0: rotate until bit0=1 and bit(top)=0
          (loop while (or (zerop (logand x 1)) (/= 0 (logand x (ash 1 (1- esize)))))
                do (setf x (logior (ash x -1) (ash (logand x 1) (1- esize))))
                   (incf rot)
                   (when (> rot esize) (error "arm64 enc: not a logical immediate")))
          (let ((ones (logcount x)))
            (unless (= x (1- (ash 1 ones))) (error "arm64 enc: not a logical immediate"))
            ;; immr = (esize - rot) mod esize; imms = (~(esize-1) | (ones-1)) low 6
            (let* ((immr (mod (- esize rot) esize))
                   (imms (logior (logand (lognot (1- esize)) #x3f) (1- ones)))
                   (nbit (if (= esize 64) 1 0)))
              (declare (ignore emask))
              (values nbit immr (logand imms #x3f)))))))))

;;; ------------------------------------------------------------------ ldp/stp
;;; Load/store pair, pre-index (stp x29,x30,[sp,#imm]!) and post-index
;;; (ldp x29,x30,[sp],#imm).  opc=10 for 64-bit; imm7 is scaled by 8.
;;;   pre-index:  opc|101|0|011|0|imm7|Rt2|Rn|Rt
;;;   post-index: opc|101|0|001|0|imm7|Rt2|Rn|Rt
(defun a64-ldstp (e load pre imm rt rt2 rn)
  (let ((imm7 (logand (ash imm -3) #x7f)))
    (aw e (logior (ash #b10 30) (ash #b101 27)
                  (ash (if pre #b011 #b001) 23) (ash load 22)
                  (ash imm7 15) (ash (a64-hw rt2) 10) (ash (a64-hw rn) 5) (a64-hw rt)))))

;;; hint #imm (NOP-space): 11010101 00000011 0010 imm7 11111  -> hint#34 = bti-ish
(defun a64-hint (e imm)
  (aw e (logior #xd503201f (ash (logand imm #x7f) 5))))

;;; ret {Xn}: 1101011 0 0 10 11111 000000 Rn 00000  (Rn defaults x30)
(defun a64-ret (e &optional (rn +a64-lr+))
  (aw e (logior #xd65f0000 (ash (a64-hw rn) 5))))

;;; unconditional branch (imm26, PC-relative *4): 000101 imm26 -> patched by reloc
(defun a64-b (e) (aw e #x14000000))
;;; b.cond (imm19): 0101010 0 imm19 0 cond
(defun a64-bcond (e cond) (aw e (logior #x54000000 (logand cond #xf))))
;;; bl (imm26): 100101 imm26
(defun a64-bl (e) (aw e #x94000000))
;;; blr Xn: 1101011 0 0 01 11111 000000 Rn 00000
(defun a64-blr (e rn) (aw e (logior #xd63f0000 (ash (a64-hw rn) 5))))

;;; ------------------------------------------------------------------ load/store
;;; Load/store, unsigned 12-bit scaled offset: size(2)|111|V|01|opc(2)|imm12|Rn|Rt
;;; size: b=00 h=01 w=10 x=11.  opc: str=00 ldr(zext)=01 ldrs->64=10 ldrs->32=11.
(defun a64-ldst-uimm (e size opc rt rn off)
  (let ((imm12 (ash off (- size))))    ; scaled by access size
    (unless (and (= (ash imm12 size) off) (<= 0 imm12 4095))
      (error "arm64 enc: ldst offset ~d not encodable (needs fixarg)" off))
    (aw e (logior (ash size 30) (ash #b111 27) (ash #b01 24) (ash opc 22)
                  (ash imm12 10) (ash (a64-hw rn) 5) (a64-hw rt)))))

;;; resolve a %M operand ref (reg base [Xn] or RSlot [x29,#off]) -> (values rn off).
(defun a64-mem-base-off (e r)
  (cond
    ((reg-p r) (values r 0))
    ((slot-ref-p r) (values (a64rg +a64-fp+) (a64-slot r (aenc-es e))))
    (t (error "arm64 enc: unhandled %M ref ~s" r))))

(defparameter *a64-ld-size/opc*
  ;; op -> (size opc dst-cls).  dst-cls picks the Rt operand width for the encoding.
  '((:loadsb 0 #b10) (:loadub 0 #b01) (:loadsh 1 #b10) (:loaduh 1 #b01)
    (:loaduw 2 #b01)))

(defun aenc-load (e i)
  (let* ((op (ins-op i)) (to (ins-to i)) (cls (ins-cls i)))
    (multiple-value-bind (rn off) (a64-mem-base-off e (ins-arg0 i))
      (case op
        (:load (if (member cls '(:s :d))
                   (a64-ldst-uimm-v e (if (eq cls :d) 3 2) #b01 to rn off)   ; ldr d/s
                   (a64-ldst-uimm e (if (kwide cls) 3 2) #b01 to rn off)))    ; ldr x/w
        (:loadsw (if (kwide cls)
                     (a64-ldst-uimm e 2 #b10 to rn off)                ; ldrsw ->x
                     (a64-ldst-uimm e 2 #b01 to rn off)))              ; ldr w
        (t (destructuring-bind (size opc) (cdr (assoc op *a64-ld-size/opc*))
             ;; ldrsb/ldrsh sign-extend to the result class: opc 10 -> x, 11 -> w
             (when (and (member op '(:loadsb :loadsh)) (not (kwide cls)))
               (setf opc #b11))
             (a64-ldst-uimm e size opc to rn off)))))))

(defparameter *a64-st-size*
  '((:storeb . 0) (:storeh . 1) (:storew . 2) (:storel . 3) (:stores . 2) (:stored . 3)))

(defun aenc-store (e i)
  (let* ((op (ins-op i)) (size (cdr (assoc op *a64-st-size*))))
    (multiple-value-bind (rn off) (a64-mem-base-off e (ins-arg1 i))
      ;; fp stores (stores/stored) set V=1
      (if (member op '(:stores :stored))
          (a64-ldst-uimm-v e size #b00 (ins-arg0 i) rn off)
          (a64-ldst-uimm e size #b00 (ins-arg0 i) rn off)))))

;;; fp variant (V=1) of the unsigned-offset load/store.
(defun a64-ldst-uimm-v (e size opc rt rn off)
  (let ((imm12 (ash off (- size))))
    (unless (and (= (ash imm12 size) off) (<= 0 imm12 4095))
      (error "arm64 enc: fp ldst offset ~d not encodable" off))
    (aw e (logior (ash size 30) (ash #b111 27) (ash 1 26) (ash #b01 24) (ash opc 22)
                  (ash imm12 10) (ash (a64-hw rn) 5) (a64-hw rt)))))

;;; ------------------------------------------------------------------ ext (bitfield)
;;; sxtb/sxth/sxtw = SBFM, uxtb/uxth = UBFM aliases.  sf|opc|100110|N|immr|imms|Rn|Rd
(defun a64-bfm (e opc cls rd rn immr imms nbit)
  (aw e (logior (ash (a64-sf cls) 31) (ash opc 29) (ash #b100110 23) (ash nbit 22)
                (ash immr 16) (ash imms 10) (ash (a64-hw rn) 5) (a64-hw rd))))

(defun aenc-ext (e i)
  (let ((op (ins-op i)) (to (ins-to i)) (a0 (ins-arg0 i)) (cls (ins-cls i)))
    (ecase op
      ;; sxtb %=,%W0 : SBFM with sf/N following the *result* width; source is Kw
      (:extsb (a64-bfm e #b00 cls to a0 0 7  (a64-sf cls)))
      (:extsh (a64-bfm e #b00 cls to a0 0 15 (a64-sf cls)))
      (:extsw (a64-bfm e #b00 :l to a0 0 31 1))                 ; sxtw ->x
      (:extub (a64-bfm e #b10 :w to a0 0 7  0))                 ; uxtb %W=,%W0
      (:extuh (a64-bfm e #b10 :w to a0 0 15 0))                 ; uxth %W=,%W0
      (:extuw (a64-logic-reg e #b01 :w to (a64rg +a64-sp+) a0)))))  ; mov %W=,%W0

;;; ------------------------------------------------------------------ cmp / cset
;;; cmp = SUBS Rd=XZR; cmn = ADDS Rd=XZR.  Register and immediate forms.
(defun aenc-acmp (e i op)   ; op 0 = cmp(subs), used with acmn -> op differs
  (let ((cls (ins-cls i)) (a0 (ins-arg0 i)) (a1 (ins-arg1 i)))
    (if (con-p a1)
        (a64-addsub-imm e op cls (a64rg +a64-sp+) a0 (con-rawbits a1) 1)   ; subs xzr,a0,#imm
        (a64-addsub-reg e op cls (a64rg +a64-sp+) a0 a1 1))))

;;; cset Rd, cond  == CSINC Rd, XZR, XZR, invert(cond)
;;; sf|0|0|11010100|Rm|cond|0|1|Rn|Rd
(defun aenc-cset (e i cc)
  (let ((cls (ins-cls i)) (rd (ins-to i)) (inv (logxor cc 1)))
    (aw e (logior (ash (a64-sf cls) 31) (ash #b0011010100 21)
                  (ash 31 16) (ash inv 12) (ash #b01 10) (ash 31 5) (a64-hw rd)))))

;;; ------------------------------------------------------------------ relocs
;;; A symbol reference records a fixup at the current word; the instruction's
;;; reloc field is left 0 (as `as` does — the linker/solder patches it).  Kinds
;;; map to mach-o ARM64_RELOC_{BRANCH26, PAGE21, PAGEOFF12}.
(defun a64-symname (c)
  "Assembler-visible name of a CAddr con: quoted names verbatim, else assym-prefixed."
  (let ((l (con-symname c)))
    (if (and (> (length l) 0) (char= (char l 0) #\")) l
        (concatenate 'string (target-assym *target*) l))))

(defun a64-reloc (e sym kind &optional (addend 0))
  (push (list :offset (ahere e) :symbol sym :kind kind :addend addend) (aenc-fixups e)))

(defun aenc-loadaddr (e c rd)
  "arm64/emit.c loadaddr (SGlo apple): adrp Xd,sym@page ; add Xd,Xd,sym@pageoff."
  (when (or (member :ext (con-symtype c)) (member :thr (con-symtype c)))
    (error "arm64 enc: GOT/TLS address (later tranche)"))
  (let ((sym (a64-symname c)))
    ;; adrp Xd, #0 : 1|immlo(2)|10000|immhi(19)|Rd  (immlo/immhi left 0 for the reloc)
    (a64-reloc e sym :page21)
    (aw e (logior #x90000000 (a64-hw rd)))
    ;; add Xd, Xd, #0  (imm12 left 0 for the pageoff reloc)
    (a64-reloc e sym :pageoff12)
    (a64-addsub-imm e 0 :l rd rd 0)
    (unless (zerop (con-off c)) (error "arm64 enc: addr addend (later tranche)"))))

(defun aenc-call (e i)
  "arm64/emit.c Ocall: bl sym (CAddr, off 0) -> BRANCH26 fixup; else blr Xn."
  (let ((a0 (ins-arg0 i)))
    (cond
      ((and (con-p a0) (eq (con-kind a0) :addr) (zerop (con-off a0))
            (not (member :thr (con-symtype a0))))
       (a64-reloc e (a64-symname a0) :branch26)
       (a64-bl e))                              ; bl #0 (imm26 patched by reloc)
      ((reg-p a0) (a64-blr e a0))               ; blr Xn (register indirect)
      (t (error "arm64 enc: invalid call argument ~s" a0)))))

;;; swap: mov ?, a0 ; mov a0, a1 ; mov a1, ?  (? = IP1 for int, V31 for fp).
(defun aenc-mov-reg (e rd rm cls fp)
  (if fp
      (a64-fmov-reg e rd rm cls)
      (if (or (= (reg-id rd) +a64-sp+) (= (reg-id rm) +a64-sp+))
          (a64-addsub-imm e 0 cls rd rm 0)
          (a64-logic-reg e #b01 cls rd (a64rg +a64-sp+) rm))))

(defun aenc-swap (e i)
  (let* ((cls (ins-cls i)) (fp (member cls '(:s :d)))
         (tmp (a64rg (if fp +a64-v31+ +a64-ip1+)))
         (a0 (ins-arg0 i)) (a1 (ins-arg1 i)))
    (aenc-mov-reg e tmp a0 cls fp)
    (aenc-mov-reg e a0 a1 cls fp)
    (aenc-mov-reg e a1 tmp cls fp)))

;;; fmov Vd, Vn (scalar) : 0001111 0 ptype 1 00000 010000 Rn Rd
(defun a64-fmov-reg (e rd rn cls)
  (aw e (logior #x1e204000 (ash (if (eq cls :d) 1 0) 22)
                (ash (a64-hw rn) 5) (a64-hw rd))))

;;; fp data-processing 2-source: 00011110 ptype 1 Rm opcode(4) 10 Rn Rd
(defparameter *a64-fbin-opc*
  '((:mul . #b0000) (:div . #b0001) (:add . #b0010) (:sub . #b0011)))
(defun aenc-fbin (e i op)
  (let ((cls (ins-cls i)))
    (aw e (logior #x1e200800 (ash (if (eq cls :d) 1 0) 22)
                  (ash (a64-hw (ins-arg1 i)) 16) (ash (cdr (assoc op *a64-fbin-opc*)) 12)
                  (ash (a64-hw (ins-arg0 i)) 5) (a64-hw (ins-to i))))))

;;; fneg Vd, Vn : 00011110 ptype 1 00001 010000 Rn Rd
(defun aenc-fneg (e i)
  (let ((cls (ins-cls i)))
    (aw e (logior #x1e214000 (ash (if (eq cls :d) 1 0) 22)
                  (ash (a64-hw (ins-arg0 i)) 5) (a64-hw (ins-to i))))))

;;; ------------------------------------------------------------------ dispatch
;;; Tranches A+: integer ALU/mov, loads/stores + slots, ext, cmp/cset.  The rest
;;; (calls+relocs, floats, div/rem, logimm) error, mirroring arm64-emit.lisp.
(defun aenc-ins (e i)
  (let ((op (ins-op i)) (cls (ins-cls i)))
    (cond
      ((eq op :nop))
      ((eq op :copy) (aenc-copy e i))
      ((and (member cls '(:s :d)) (member op '(:add :sub :mul :div)))
       (aenc-fbin e i op))
      ((eq op :neg) (if (member cls '(:s :d)) (aenc-fneg e i)
                        (a64-addsub-reg e 1 cls (ins-to i) (a64rg +a64-sp+) (ins-arg0 i))))
      ((member op '(:add :sub)) (aenc-addsub e i (if (eq op :sub) 1 0)))
      ((eq op :and) (aenc-logic e i #b00))
      ((eq op :or)  (aenc-logic e i #b01))
      ((eq op :xor) (aenc-logic e i #b10))
      ((eq op :mul) (a64-dp3 e cls (ins-to i) (ins-arg0 i) (ins-arg1 i) (a64rg +a64-sp+) #b000 0))
      ((member op '(:load :loadsw :loadsb :loadub :loadsh :loaduh :loaduw)) (aenc-load e i))
      ((member op '(:storeb :storeh :storew :storel :stores :stored)) (aenc-store e i))
      ((eq op :addr)                                          ; add Xd, x29, #slot
       (a64-addsub-imm e 0 :l (ins-to i) (a64rg +a64-fp+) (a64-slot (ins-arg0 i) (aenc-es e))))
      ((member op '(:extsb :extub :extsh :extuh :extsw :extuw)) (aenc-ext e i))
      ((eq op :swap) (aenc-swap e i))
      ((eq op :call) (aenc-call e i))
      ((eq op :acmp) (aenc-acmp e i 1))                       ; cmp -> subs
      ((eq op :acmn) (aenc-acmp e i 0))                       ; cmn -> adds
      ((position op *flag-ops*)
       (aenc-cset e i (a64-cc-code (aref *a64-omap-flags* (position op *flag-ops*)))))
      (t (error "arm64 enc: TODO op ~s (cls ~s)" op cls)))))

(defun aenc-copy (e i)
  "arm64/emit.c Ocopy: mov reg (add imm 0 / orr xzr) or load-const."
  (let ((to (ins-to i)) (a0 (ins-arg0 i)) (cls (ins-cls i)))
    (cond
      ((and to a0 (ref= to a0)))
      ((member cls '(:s :d))                                  ; fp copy: fmov Vd,Vn
       (if (reg-p a0) (a64-fmov-reg e to a0 cls)
           (error "arm64 enc: fp copy of non-reg (fp const pool later tranche)")))
      ((and (con-p a0) (eq (con-kind a0) :addr)) (aenc-loadaddr e a0 to))
      ((con-p a0) (a64-enc-loadcon-bits e a0 to cls))
      ((reg-p a0)
       ;; mov Xd, Xm  == orr Xd, XZR, Xm  (integer);  for SP source use add #0
       (if (or (= (reg-id to) +a64-sp+) (= (reg-id a0) +a64-sp+))
           (a64-addsub-imm e 0 cls to a0 0)
           (a64-logic-reg e #b01 cls to (a64rg +a64-sp+) a0)))   ; orr to,xzr,a0
      (t (error "arm64 enc: copy src ~s" a0)))))

(defun aenc-addsub (e i op)
  (let ((to (ins-to i)) (a0 (ins-arg0 i)) (a1 (ins-arg1 i)) (cls (ins-cls i)))
    (if (con-p a1)
        (a64-addsub-imm e op cls to a0 (con-rawbits a1))
        (a64-addsub-reg e op cls to a0 a1))))

(defun aenc-logic (e i opc)
  (let ((to (ins-to i)) (a0 (ins-arg0 i)) (a1 (ins-arg1 i)) (cls (ins-cls i)))
    (if (con-p a1)
        (a64-enc-logic-imm e opc cls to a0 (con-rawbits a1))
        (a64-logic-reg e opc cls to a0 a1))))

(defun a64-enc-logic-imm (e opc cls rd rn imm)
  "Logical (immediate): sf|opc|100100|N|immr|imms|Rn|Rd."
  (multiple-value-bind (nbit immr imms) (a64-logimm-fields imm cls)
    (aw e (logior (ash (a64-sf cls) 31) (ash opc 29) (ash #b100100 23)
                  (ash nbit 22) (ash immr 16) (ash imms 10)
                  (ash (a64-hw rn) 5) (a64-hw rd)))))

;;; ------------------------------------------------------------------ prologue
(defvar *abrs* nil "Pending intra-function branches for the current aenc-fn.")

(defparameter *a64-cc-codes*
  '(("eq" . 0) ("ne" . 1) ("cs" . 2) ("cc" . 3) ("mi" . 4) ("pl" . 5)
    ("vs" . 6) ("vc" . 7) ("hi" . 8) ("ls" . 9) ("ge" . 10) ("lt" . 11)
    ("gt" . 12) ("le" . 13) ("al" . 14))
  "AArch64 condition-code field values.")
(defun a64-cc-code (s) (cdr (assoc s *a64-cc-codes* :test #'string=)))

(defun aenc-prologue (e frame fn)
  (a64-hint e 34)
  (cond
    ((<= (+ frame 16) 512)
     (a64-ldstp e 0 t (- (+ frame 16)) (a64rg +a64-fp+) (a64rg +a64-lr+) (a64rg +a64-sp+)))
    (t (error "arm64 enc: large frame prologue (tranche B)")))
  (a64-addsub-imm e 0 :l (a64rg +a64-fp+) (a64rg +a64-sp+) 0)     ; mov x29, sp
  ;; callee-clobbered register saves (str into top-of-frame slots)
  (let ((sc (floor (- frame (ae-padding (aenc-es e))) 4)))
    (loop for rc across *arm64-rclob*
          when (logbitp rc (fn-reg fn))
          do (decf sc 2)
             (aenc-ins e (make-instance 'ins
                           :op (if (>= rc +a64-v0+) :stored :storel) :cls :w
                           :to nil :arg0 (a64rg rc) :arg1 (make-slot-ref sc))))))

(defun aenc-epilogue (e frame fn)
  (let ((sc (floor (- frame (ae-padding (aenc-es e))) 4)))
    (loop for rc across *arm64-rclob*
          when (logbitp rc (fn-reg fn))
          do (decf sc 2)
             (aenc-ins e (make-instance 'ins
                           :op :load :cls (if (>= rc +a64-v0+) :d :l)
                           :to (a64rg rc) :arg0 (make-slot-ref sc) :arg1 nil))))
  (when (fn-dynalloc fn) (error "arm64 enc: dynalloc epilogue (tranche B)"))
  (let ((o (+ frame 16)))
    (when (and (fn-vararg fn) (not (tg-apple))) (incf o 192))
    (cond
      ((<= o 504) (a64-ldstp e 1 nil o (a64rg +a64-fp+) (a64rg +a64-lr+) (a64rg +a64-sp+)))
      (t (error "arm64 enc: large frame epilogue (tranche B)"))))
  (a64-ret e))

;;; ------------------------------------------------------------------ fn driver
;;; AArch64 branches are one word, so there is no size relaxation: we lay out
;;; all instructions recording each block's byte offset, emit branches with a
;;; placeholder, then patch their PC-relative immediates once offsets are known.
;;; Terminator planning mirrors a64-emit-jmp (successor rotate, fallthrough).

(defstruct (abr (:conc-name abr-)) pos kind target)   ; pending intra-fn branch

(defun aenc-b-imm26 (word disp)   ; b / bl: imm26 = disp/4
  (logior (logand word #xfc000000) (logand (ash disp -2) #x3ffffff)))
(defun aenc-bcond-imm19 (word disp) ; b.cond: imm19 in [23:5]
  (logior (logand word #xff00001f) (ash (logand (ash disp -2) #x7ffff) 5)))

(defun aenc-plan-term (e b fn frame)
  "Emit B's terminator, recording pending intra-fn branches in *abrs*."
  (case (blk-jmp-type b)
    (:hlt (aw e (logior #xd4200000 (ash 1000 5))) t)       ; brk #1000
    (:ret0 (aenc-epilogue e frame fn) t)
    (:jmp (cond ((not (eq (blk-s1 b) (blk-link b)))
                 (push (make-abr :pos (ahere e) :kind :b :target (blk-id (blk-s1 b))) *abrs*)
                 (a64-b e) t)
                (t nil)))
    (t (let ((cc (a64-jmp-code (blk-jmp-type b))) (n 1) s1 s2)
         (when (< cc 0) (error "arm64 enc: unhandled jump ~s" (blk-jmp-type b)))
         (if (eq (blk-link b) (blk-s2 b))
             (setf s1 (blk-s2 b) s2 (blk-s1 b) n 0)
             (setf s1 (blk-s1 b) s2 (blk-s2 b) n 1))
         (push (make-abr :pos (ahere e) :kind :bcond :target (blk-id s2)) *abrs*)
         (a64-bcond e (a64-cc-code (aref (aref *a64-jf-cc* cc) n)))
         (cond ((not (eq s1 (blk-link b)))
                (push (make-abr :pos (ahere e) :kind :b :target (blk-id s1)) *abrs*)
                (a64-b e) t)
               (t nil))))))

(defun aenc-fn (fn)
  "Encode a backend-pipelined FN to (values code-bytes symbols fixups)."
  (let* ((e (make-aenc)) (ae (make-ae :fn fn)) (*abrs* nil)
         (labels (make-hash-table)))
    (setf (aenc-es e) ae)
    (a64-framelayout ae)
    (aenc-prologue e (ae-frame ae) fn)
    (loop for b = (fn-start fn) then (blk-link b) while b do
      (setf (gethash (blk-id b) labels) (ahere e))
      (dolist (i (blk-ins b)) (aenc-ins e i))
      (aenc-plan-term e b fn (ae-frame ae)))
    ;; patch intra-function branches now that every block offset is known
    (dolist (br *abrs*)
      (let* ((pos (abr-pos br)) (tgt (gethash (abr-target br) labels))
             (disp (- tgt pos))
             (word (logior (aref (aenc-buf e) pos)
                           (ash (aref (aenc-buf e) (+ pos 1)) 8)
                           (ash (aref (aenc-buf e) (+ pos 2)) 16)
                           (ash (aref (aenc-buf e) (+ pos 3)) 24)))
             (patched (ecase (abr-kind br)
                        (:b (aenc-b-imm26 word disp))
                        (:bcond (aenc-bcond-imm19 word disp)))))
        (dotimes (k 4) (setf (aref (aenc-buf e) (+ pos k)) (ldb (byte 8 (* 8 k)) patched)))))
    (values (coerce (aenc-buf e) '(simple-array (unsigned-byte 8) (*)))
            (list (cons (fn-name fn) 0))
            (nreverse (aenc-fixups e)))))
