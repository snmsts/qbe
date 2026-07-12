;;;; arm64-emit.lisp --- arm64 (Apple / mach-o) assembly emission (G4).
;;;; Mirrors arm64/emit.c: omap table, emitf format interpreter, loadcon/
;;;; loadaddr, framelayout, and arm64_emitfn.  Replaces the naive arm64.lisp
;;;; path once spill/rega have produced a register-allocated function.
;;;;
;;;; Apple conventions (T_arm64_apple): `_`/`L` prefixes, `.balign`, `hint #34`,
;;;; stp/ldp x29,x30 frame, mach-o literal sections for the fp pool.

(in-package #:qbe)

;;; ------------------------------------------------------------ register names
;;; arm64/emit.c rname: register id + class -> assembler name.  V31 is a scratch
;;; fp register used by the store-of-immediate fixup (isel never allocates it).
(defconstant +a64-v31+ #x1fffffff)

(defun a64-rname (r k)
  "arm64/emit.c rname."
  (cond
    ((= r +a64-sp+) "sp")
    ((<= +a64-r0+ r +a64-lr+)
     (ecase k (:w (format nil "w~d" (- r +a64-r0+)))
              ((:x :l :m) (format nil "x~d" (- r +a64-r0+)))))
    ((<= +a64-v0+ r (+ +a64-v0+ 30))
     (ecase k (:s (format nil "s~d" (- r +a64-v0+)))
              ((:x :d) (format nil "d~d" (- r +a64-v0+)))))
    ((= r +a64-v31+)
     (ecase k (:s "s31") (:d "d31")))
    (t (error "arm64 emit: invalid register ~d" r))))

;;; ------------------------------------------------------------------ E state
(defstruct (ae (:conc-name ae-)) stream fn (frame 0) (padding 0))

(defun ae-out (e fmt &rest args) (apply #'format (ae-stream e) fmt args))

;;; ------------------------------------------------------------------ omap
;;; arm64/emit.c omap: (op cls fmt).  cls is :ki (Kw/Kl), :ka (all), or a
;;; specific class; a Ki entry matches an integer instruction class.
(defparameter *a64-omap*
  '((:add :ki "add %=, %0, %1") (:add :ka "fadd %=, %0, %1")
    (:sub :ki "sub %=, %0, %1") (:sub :ka "fsub %=, %0, %1")
    (:neg :ki "neg %=, %0")     (:neg :ka "fneg %=, %0")
    (:and :ki "and %=, %0, %1") (:or :ki "orr %=, %0, %1")
    (:xor :ki "eor %=, %0, %1")
    (:sar :ki "asr %=, %0, %1") (:shr :ki "lsr %=, %0, %1")
    (:shl :ki "lsl %=, %0, %1")
    (:mul :ki "mul %=, %0, %1") (:mul :ka "fmul %=, %0, %1")
    (:div :ki "sdiv %=, %0, %1") (:div :ka "fdiv %=, %0, %1")
    (:udiv :ki "udiv %=, %0, %1")
    (:rem :ki #.(format nil "sdiv %?, %0, %1~%~Cmsub~C%=, %?, %1, %0" #\Tab #\Tab))
    (:urem :ki #.(format nil "udiv %?, %0, %1~%~Cmsub~C%=, %?, %1, %0" #\Tab #\Tab))
    (:copy :ki "mov %=, %0") (:copy :ka "fmov %=, %0")
    (:swap :ki #.(format nil "mov %?, %0~%~Cmov~C%0, %1~%~Cmov~C%1, %?" #\Tab #\Tab #\Tab #\Tab))
    (:swap :ka #.(format nil "fmov %?, %0~%~Cfmov~C%0, %1~%~Cfmov~C%1, %?" #\Tab #\Tab #\Tab #\Tab))
    (:storeb :w "strb %W0, %M1") (:storeh :w "strh %W0, %M1")
    (:storew :w "str %W0, %M1")  (:storel :w "str %L0, %M1")
    (:stores :w "str %S0, %M1")  (:stored :w "str %D0, %M1")
    (:loadsb :ki "ldrsb %=, %M0") (:loadub :ki "ldrb %W=, %M0")
    (:loadsh :ki "ldrsh %=, %M0") (:loaduh :ki "ldrh %W=, %M0")
    (:loadsw :w "ldr %=, %M0")    (:loadsw :l "ldrsw %=, %M0")
    (:loaduw :ki "ldr %W=, %M0")  (:load :ka "ldr %=, %M0")
    (:extsb :ki "sxtb %=, %W0") (:extub :ki "uxtb %W=, %W0")
    (:extsh :ki "sxth %=, %W0") (:extuh :ki "uxth %W=, %W0")
    (:extsw :ki "sxtw %L=, %W0") (:extuw :ki "mov %W=, %W0")
    (:exts :d "fcvt %=, %S0") (:truncd :s "fcvt %=, %D0")
    (:cast :w "fmov %=, %S0") (:cast :l "fmov %=, %D0")
    (:cast :s "fmov %=, %W0") (:cast :d "fmov %=, %L0")
    (:stosi :ka "fcvtzs %=, %S0") (:stoui :ka "fcvtzu %=, %S0")
    (:dtosi :ka "fcvtzs %=, %D0") (:dtoui :ka "fcvtzu %=, %D0")
    (:swtof :ka "scvtf %=, %W0") (:uwtof :ka "ucvtf %=, %W0")
    (:sltof :ka "scvtf %=, %L0") (:ultof :ka "ucvtf %=, %L0")
    (:call :w "blr %L0")
    (:acmp :ki "cmp %0, %1") (:acmn :ki "cmn %0, %1")
    (:afcmp :ka "fcmpe %0, %1"))
  "arm64/emit.c omap (flag<cc> entries are generated separately).")

(defparameter *a64-omap-flags*
  ;; arm64/emit.c CMP(X): flag<cc> -> "cset %=, <cond>".  Index by the combined
  ;; compare code (matches *flag-ops* / *cmp-codes* ordering 0..17).
  #("eq" "ne" "ge" "gt" "le" "lt" "cs" "hi" "ls" "cc"
    "eq" "ge" "gt" "ls" "mi" "ne" "vc" "vs")
  "cset condition per compare code.")

(defun a64-omap-match (op cls)
  "Return the format string for OP at result class CLS (arm64/emit.c omap loop)."
  (let ((fi (position op *flag-ops*)))
    (when fi (return-from a64-omap-match
               (format nil "cset %=, ~a" (aref *a64-omap-flags* fi)))))
  (dolist (row *a64-omap* (error "arm64 emit: no omap match for ~s(~s)" op cls))
    (destructuring-bind (o c fmt) row
      (when (and (eq o op)
                 (or (eq c cls) (eq c :ka)
                     (and (eq c :ki) (= (cls-base cls) 0))))
        (return fmt)))))

;;; ------------------------------------------------------------------ slots
(defun a64-slot (r e)
  "arm64/emit.c slot: RSlot R -> byte offset off x29."
  (let ((s (slot-ref-n r)) (fn (ae-fn e)))
    (cond
      ((= s -1) (+ 16 (ae-frame e)))
      ((< s 0) (if (and (fn-vararg fn) (not (tg-apple)))
                   (+ 16 (ae-frame e) 192 (- (+ s 2)))
                   (+ 16 (ae-frame e) (- (+ s 2)))))
      (t (+ 16 (ae-padding e) (* 4 s))))))

;;; ------------------------------------------------------------------ emitf
(defun a64-getarg (ch i)
  (ecase ch (#\0 (ins-arg0 i)) (#\1 (ins-arg1 i)) (#\= (ins-to i))))

(defun a64-emit1-imm (r e k)
  "Print the second operand of an add/sub/cmp (arm64/emit.c emitf '%1' RCon)."
  (let* ((c r) (n (con-rawbits c)))
    (cond
      ((/= 0 (ash n -24)) (ae-out e "#~d" n))            ; logimm (asserted by qbe)
      ((/= 0 (logand n #xfff000)) (ae-out e "#~d, lsl #12" (ash n -12)))
      (t (ae-out e "#~d" n)))))

(defun a64-emitf (fmt i e)
  "arm64/emit.c emitf: interpret an omap format string for instruction I."
  (let ((s (ae-stream e)) (p 0) (n (length fmt)) (sp nil))
    (write-char #\Tab s)
    (loop while (< p n) do
      (let ((c (char fmt p)) (k (ins-cls i)))    ; k resets to i->cls per '%' group
        (incf p)
        (cond
          ((char= c #\Tab) (write-char #\Tab s))         ; explicit tab from ~C
          ((char= c #\%)
           ;; a '%' introduces a spec that may be prefixed by class modifiers
           ;; W/L/S/D (arm64/emit.c goto Switch), so loop until the real spec.
           (loop
             (let ((d (char fmt p)))
               (incf p)
               (case d
                 (#\W (setf k :w)) (#\L (setf k :l)) (#\S (setf k :s)) (#\D (setf k :d))
                 (#\? (write-string (if (= (cls-base (ins-cls i)) 0)
                                        (a64-rname +a64-ip1+ (ins-cls i))
                                        (a64-rname +a64-v31+ (ins-cls i))) s)
                      (return))
                 ((#\= #\0) (write-string (a64-rname (reg-id (a64-getarg d i)) k) s) (return))
                 (#\1 (let ((r (ins-arg1 i)))
                        (if (reg-p r)
                            (write-string (a64-rname (reg-id r) k) s)
                            (a64-emit1-imm r e k)))
                      (return))
                 (#\M (let* ((mc (char fmt p)) (r (a64-getarg mc i)))
                        (incf p)
                        (cond ((reg-p r) (ae-out e "[~a]" (a64-rname (reg-id r) :l)))
                              ((slot-ref-p r) (ae-out e "[x29, ~d]" (a64-slot r e)))
                              (t (error "arm64 emit: unhandled %M ref ~s" r))))
                      (return))
                 (t (error "arm64 emit: bad spec %~a" d))))))
          ;; a space before the first operand column becomes a tab
          ((and (char= c #\Space) (not sp)) (write-char #\Tab s) (setf sp t))
          (t (write-char c s)))))
    (write-char #\Newline s)))

;;; ------------------------------------------------------------------ loadaddr
(defun a64-loadaddr (c rn e)
  "arm64/emit.c loadaddr: materialize a symbol address into register name RN."
  (let* ((st (con-symtype c))
         (tmpl (cond
                 ((member :thr st)
                  (if (tg-apple)
                      "~Cadrp~CR, S@tlvppage~%~Cldr~CR, [R, S@tlvppageoff]~%"
                      (error "arm64 emit: elf TLS unsupported")))
                 ((member :ext st)
                  (if (tg-apple)
                      "~Cadrp~CR, S@gotpage~%~Cldr~CR, [R, S@gotpageoff]~%"
                      (error "arm64 emit: elf GOT unsupported")))
                 (t                              ; SGlo: plain global
                  (if (tg-apple)
                      "~Cadrp~CR, S@pageO~%~Cadd~CR, R, S@pageoffO~%"
                      "~Cadrp~CR, SO~%~Cadd~CR, R, #:lo12:SO~%"))))
         (l (con-symname c))
         (pfx (if (and (> (length l) 0) (char= (char l 0) #\")) "" (target-assym *target*)))
         (out (ae-stream e)) (i 0) (m (length tmpl)))
    (loop while (< i m) do
      (let ((ch (char tmpl i)))
        (incf i)
        (cond
          ((char= ch #\~) (let ((d (char tmpl i))) (incf i)
                            (ecase d (#\C (write-char #\Tab out)) (#\% (write-char #\Newline out)))))
          ((char= ch #\R) (write-string rn out))
          ((char= ch #\S) (write-string pfx out) (write-string l out))
          ((char= ch #\O) (unless (zerop (con-off c)) (ae-out e "+~d" (con-off c))))
          (t (write-char ch out)))))))

;;; ------------------------------------------------------------------ loadcon
(defun a64-emit-loadcon (c r k e)
  "arm64/emit.c loadcon: materialize constant C into register id R at class K."
  (let ((rn (a64-rname r k)))
    (when (eq (con-kind c) :addr)
      (a64-loadaddr c (a64-rname r :l) e)
      (return-from a64-emit-loadcon))
    (let* ((w (kwide k)) (n (con-rawbits c)))
      (unless w (setf n (s32* n)))
      (if (or (= (logior n #xffff) -1) (arm64-logimm n k))
          (ae-out e "~Cmov~C~a, #~d~%" #\Tab #\Tab rn n)
          (progn
            (ae-out e "~Cmov~C~a, #~d~%" #\Tab #\Tab rn (logand n #xffff))
            (let ((sh 16) (nn (ash n -16)))
              (loop while (/= nn 0) do
                (when (or (and (not w) (= sh 32)) (= sh 64)) (return))
                (ae-out e "~Cmovk~C~a, #0x~x, lsl #~d~%" #\Tab #\Tab rn (logand nn #xffff) sh)
                (setf nn (ash nn -16)) (incf sh 16))))))))

;;; ------------------------------------------------------------------ fixarg
(defun a64-emit-fixarg (i argn sz tid e)
  "arm64/emit.c fixarg: if arg ARGN is a far slot, materialize its address into
register TID (or return t when TID<0 = 'no scratch available')."
  (let ((r (if (= argn 0) (ins-arg0 i) (ins-arg1 i))))
    (when (slot-ref-p r)
      (let ((s (a64-slot r e)))
        (when (> s (* sz 4095))
          (when (< tid 0) (return-from a64-emit-fixarg t))
          (a64-emitins (make-instance 'ins :op :addr :cls :l :to (a64rg tid) :arg0 r :arg1 nil) e)
          (if (= argn 0) (setf (ins-arg0 i) (a64rg tid)) (setf (ins-arg1 i) (a64rg tid))))))
    nil))

;;; ------------------------------------------------------------------ emitins
(defun a64-emitins (i e)
  "arm64/emit.c emitins: emit one instruction, handling the special cases."
  (let ((op (ins-op i)) (s (ae-stream e)))
    (case op
      (:nop)
      (:dbgloc)                                          ; debug info: skipped
      (:copy (a64-emit-copyins i e))
      (:addr
       (let ((rn (a64-rname (reg-id (ins-to i)) :l)) (sl (a64-slot (ins-arg0 i) e)))
         (cond
           ((<= sl 4095) (ae-out e "~Cadd~C~a, x29, #~d~%" #\Tab #\Tab rn sl))
           ((<= sl 65535)
            (ae-out e "~Cmov~C~a, #~d~%~Cadd~C~a, x29, ~a~%" #\Tab #\Tab rn sl #\Tab #\Tab rn rn))
           (t (ae-out e "~Cmov~C~a, #~d~%~Cmovk~C~a, #~d, lsl #16~%~Cadd~C~a, x29, ~a~%"
                      #\Tab #\Tab rn (logand sl #xffff) #\Tab #\Tab rn (ash sl -16)
                      #\Tab #\Tab rn rn)))))
      (:call
       (if (not (con-p (ins-arg0 i)))
           (a64-emitins-table i e)
           (let ((c (ins-arg0 i)))
             (when (or (not (eq (con-kind c) :addr)) (member :thr (con-symtype c))
                       (/= (con-off c) 0))
               (error "arm64 emit: invalid call argument"))
             (let* ((l (con-symname c))
                    (pfx (if (char= (char l 0) #\") "" (target-assym *target*))))
               (ae-out e "~Cbl~C~a~a~%" #\Tab #\Tab pfx l)))))
      (:salloc
       (a64-emitf "sub sp, sp, %0" i e)
       (when (ins-to i) (a64-emitf "mov %=, sp" i e)))
      (t (a64-emitins-table i e)))))

(defun a64-emitins-table (i e)
  "The default emitins path (arm64/emit.c `default:`): fix far load/store slots,
then look the op up in omap."
  (let ((op (ins-op i)))
    (when (isload-op op)
      (a64-emit-fixarg i 0 (loadsz i) +a64-ip1+ e))
    (when (isstore-op op)
      (let ((tid (if (tg-apple) -1 +a64-r18+)))
        (when (a64-emit-fixarg i 1 (storesz i) tid e)
          ;; the address needs a scratch but only IP1 is free and it may hold the
          ;; value; bounce the value through V31, then re-fix with IP1.
          (when (and (reg-p (ins-arg0 i)) (= (reg-id (ins-arg0 i)) +a64-ip1+))
            (ae-out e "~Cfmov~C~a31, ~a17~%" #\Tab #\Tab
                    (if (eq (ins-cls i) :w) "s" "d") (if (eq (ins-cls i) :w) "w" "x"))
            (setf (ins-arg0 i) (a64rg +a64-v31+)
                  (ins-op i) (aref #(:storew :storel :stores :stored) (cls-code (ins-cls i)))))
          (a64-emit-fixarg i 1 (storesz i) +a64-ip1+ e))))
    (a64-emitf (a64-omap-match (ins-op i) (ins-cls i)) i e)))

(defun a64-emit-copyins (i e)
  "arm64/emit.c emitins Ocopy case."
  (let ((to (ins-to i)) (a0 (ins-arg0 i)))
    (cond
      ((and to a0 (ref= to a0)))                         ; nop copy
      ((slot-ref-p to)                                   ; copy into a slot -> store
       (let ((r to))
         (unless (reg-p a0)
           (setf (ins-to i) (a64rg +a64-ip1+))
           (a64-emitins i e)
           (setf (ins-arg0 i) (ins-to i)))
         (setf (ins-op i) (aref #(:storew :storel :stores :stored) (cls-code (ins-cls i)))
               (ins-cls i) :w (ins-arg1 i) r)
         (a64-emitins i e)))
      (t
       (cond
         ((con-p a0) (a64-emit-loadcon a0 (reg-id to) (ins-cls i) e))
         ((slot-ref-p a0) (setf (ins-op i) :load) (a64-emitins i e))
         (t (a64-emitins-table i e)))))))

;;; ------------------------------------------------------------------ framelayout
(defun a64-framelayout (e)
  "arm64/emit.c framelayout: compute e->frame and e->padding from callee-saves,
spill slots, and locals."
  (let ((fn (ae-fn e)) (o 0))
    (loop for rc across *arm64-rclob*
          do (incf o (logand 1 (ash (fn-reg fn) (- rc)))))
    (let ((f (logand (+ (fn-slot fn) 3) -4)))
      (incf o (logand o 1))
      (setf (ae-padding e) (* 4 (- f (fn-slot fn)))
            (ae-frame e) (+ (* 4 f) (* 8 o))))))

;;; ------------------------------------------------------------------ fn emit
(defparameter *a64-jf-cc*
  ;; arm64/emit.c ctoa: #(taken untaken) condition suffixes per compare code.
  #(#("eq" "ne") #("ne" "eq") #("ge" "lt") #("gt" "le") #("le" "gt") #("lt" "ge")
    #("cs" "cc") #("hi" "ls") #("ls" "hi") #("cc" "cs")
    #("eq" "ne") #("ge" "lt") #("gt" "le") #("ls" "hi") #("mi" "pl") #("ne" "eq")
    #("vc" "vs") #("vs" "vc")))

(defvar *a64-id0* 0 "Running block-label counter across a module's functions.")

(defun a64-emit-prologue (e)
  (let ((fn (ae-fn e)) (frame (ae-frame e)))
    (ae-out e "~Chint~C#34~%" #\Tab #\Tab)
    (cond
      ((<= (+ frame 16) 512)
       (ae-out e "~Cstp~Cx29, x30, [sp, -~d]!~%" #\Tab #\Tab (+ frame 16)))
      ((<= frame 4095)
       (ae-out e "~Csub~Csp, sp, #~d~%~Cstp~Cx29, x30, [sp, -16]!~%" #\Tab #\Tab frame #\Tab #\Tab))
      ((<= frame 65535)
       (ae-out e "~Cmov~Cx16, #~d~%~Csub~Csp, sp, x16~%~Cstp~Cx29, x30, [sp, -16]!~%"
               #\Tab #\Tab frame #\Tab #\Tab #\Tab #\Tab))
      (t (ae-out e "~Cmov~Cx16, #~d~%~Cmovk~Cx16, #~d, lsl #16~%~Csub~Csp, sp, x16~%~Cstp~Cx29, x30, [sp, -16]!~%"
                 #\Tab #\Tab (logand frame #xffff) #\Tab #\Tab (ash frame -16)
                 #\Tab #\Tab #\Tab #\Tab)))
    (ae-out e "~Cmov~Cx29, sp~%" #\Tab #\Tab)
    ;; save callee-clobbered registers into the top of the frame
    (let ((sc (floor (- (ae-frame e) (ae-padding e)) 4)))
      (loop for rc across *arm64-rclob*
            when (logbitp rc (fn-reg fn))
            do (decf sc 2)
               (a64-emitins (make-instance 'ins
                              :op (if (>= rc +a64-v0+) :stored :storel) :cls :w
                              :to nil :arg0 (a64rg rc) :arg1 (make-slot-ref sc)) e)))))

(defun a64-emit-epilogue (e)
  (let ((fn (ae-fn e)))
    (let ((sc (floor (- (ae-frame e) (ae-padding e)) 4)))
      (loop for rc across *arm64-rclob*
            when (logbitp rc (fn-reg fn))
            do (decf sc 2)
               (a64-emitins (make-instance 'ins
                              :op :load :cls (if (>= rc +a64-v0+) :d :l)
                              :to (a64rg rc) :arg0 (make-slot-ref sc) :arg1 nil) e)))
    (when (fn-dynalloc fn) (ae-out e "~Cmov sp, x29~%" #\Tab))
    (let ((o (+ (ae-frame e) 16)))
      (when (and (fn-vararg fn) (not (tg-apple))) (incf o 192))
      (cond
        ((<= o 504) (ae-out e "~Cldp~Cx29, x30, [sp], ~d~%" #\Tab #\Tab o))
        ((<= (- o 16) 4095)
         (ae-out e "~Cldp~Cx29, x30, [sp], 16~%~Cadd~Csp, sp, #~d~%" #\Tab #\Tab #\Tab #\Tab (- o 16)))
        ((<= (- o 16) 65535)
         (ae-out e "~Cldp~Cx29, x30, [sp], 16~%~Cmov~Cx16, #~d~%~Cadd~Csp, sp, x16~%"
                 #\Tab #\Tab #\Tab #\Tab (- o 16) #\Tab #\Tab))
        (t (ae-out e "~Cldp~Cx29, x30, [sp], 16~%~Cmov~Cx16, #~d~%~Cmovk~Cx16, #~d, lsl #16~%~Cadd~Csp, sp, x16~%"
                   #\Tab #\Tab #\Tab #\Tab (logand (- o 16) #xffff) #\Tab #\Tab (ash (- o 16) -16)
                   #\Tab #\Tab))))
    (ae-out e "~Cret~%" #\Tab)))

(defun a64-block-label (e id) (format nil "~a~d" (tg-asloc) id))

(defun a64-emit-jmp (b e lbl)
  "Emit B's terminator; return the next-block lbl flag (arm64/emit.c switch)."
  (case (blk-jmp-type b)
    (:hlt (ae-out e "~Cbrk~C#1000~%" #\Tab #\Tab) t)
    (:ret0 (a64-emit-epilogue e) t)
    (:jmp (cond ((not (eq (blk-s1 b) (blk-link b)))
                 (ae-out e "~Cb~C~a~%" #\Tab #\Tab
                         (a64-block-label e (+ *a64-id0* (blk-id (blk-s1 b))))) t)
                (t nil)))
    (t (let ((cc (a64-jmp-code (blk-jmp-type b))) (n 1))
         (when (or (< cc 0) (> cc 17)) (error "arm64 emit: unhandled jump ~s" (blk-jmp-type b)))
         (if (eq (blk-link b) (blk-s2 b))
             (progn (rotatef (blk-s1 b) (blk-s2 b)) (setf n 0))
             (setf n 1))
         (ae-out e "~Cb~a~C~a~%" #\Tab (aref (aref *a64-jf-cc* cc) n) #\Tab
                 (a64-block-label e (+ *a64-id0* (blk-id (blk-s2 b)))))
         (cond ((not (eq (blk-s1 b) (blk-link b)))
                (ae-out e "~Cb~C~a~%" #\Tab #\Tab
                        (a64-block-label e (+ *a64-id0* (blk-id (blk-s1 b))))) t)
               (t nil))))))

(defun a64-jmp-code (jt)
  "Compare code (0..17) of a Jjf<cc> jump type, else -1."
  (or (position jt *jf-jumps-vec*) -1))

(defun a64-be-emit-fn (fn stream)
  "arm64/emit.c arm64_emitfn: emit one function."
  (let ((e (make-ae :stream stream :fn fn)))
    ;; function link (emitfnlnk / emitlnk): text section, Apple 4-byte align,
    ;; globl, label — all at column 0.
    (ae-out e ".text~%")
    (when (tg-apple) (ae-out e ".balign 4~%"))
    (let* ((name (fn-name fn))
           (pfx (target-assym *target*)))
      (when (fn-export fn) (ae-out e ".globl ~a~a~%" pfx name))
      (ae-out e "~a~a:~%" pfx name))
    (a64-framelayout e)
    (a64-emit-prologue e)
    (let ((lbl nil))
      (loop for b = (fn-start fn) then (blk-link b) while b do
        (when (or lbl (> (length (blk-preds b)) 1))
          (ae-out e "~a~d:~%" (tg-asloc) (+ *a64-id0* (blk-id b))))
        (dolist (i (blk-ins b)) (a64-emitins i e))
        (setf lbl (a64-emit-jmp b e lbl))))
    (incf *a64-id0* (fn-nblk fn))))

;;; ------------------------------------------------------------ backend driver
(defun a64-backend-pipeline (fn)
  "Full arm64_apple backend (main.c func, T.cansel=0 -> NO ifconvert): abi0,
SSA, mid-end, abi1, isel, then spill/rega and simpljmp."
  (a64-apple-extsb fn)
  (fill-cfg fn) (fill-use fn) (promote fn) (fill-use fn)
  (ssa fn) (fill-use fn)
  (fill-alias fn) (loadopt fn) (fill-use fn) (fill-alias fn) (coalesce fn)
  (fill-use fn) (fill-dom fn)
  (gvn fn) (fill-cfg fn) (simplcfg fn)
  (fill-use fn) (fill-dom fn) (gcm fn) (fill-use fn)
  (arm64-abi fn) (simpl fn) (fill-cfg fn) (fill-use fn)
  (arm64-isel fn)
  (materialize-regs fn)
  (fill-cfg fn) (be-fill-live fn) (fill-loop fn) (fill-cost fn)
  (spill fn) (rega fn)
  (fill-cfg fn) (simpljmp fn) (fill-cfg fn))

(defun a64-emit-data (d s)
  "Emit one data definition for mach-o (arm64/emit.c emitdat / emitlnk apple)."
  (let ((pfx (target-assym *target*)) (name (dat-name d)))
    (if (dat-thread d)
        ;; Apple thread-local: a $tlv$init that the __thread_vars descriptor
        ;; points at (arm64/emit.c emitlnk apple TLS).
        (progn
          (format s ".section __DATA,__thread_vars,thread_local_variables~%")
          (format s "~a~a:~%~C.quad __tlv_bootstrap~%~C.quad 0~%~C.quad ~a~a$tlv$init~%~%"
                  pfx name #\Tab #\Tab #\Tab pfx name)
          (format s ".section __DATA,__thread_data,thread_local_regular~%")
          (format s ".balign ~d~%~a~a$tlv$init:~%" (dat-align d) pfx name))
        (progn                          ; emitlnk sec[0][SecData] = ".data"
          (format s ".data~%.balign ~d~%" (dat-align d))
          (when (dat-export d) (format s ".globl ~a~a~%" pfx name))
          (format s "~a~a:~%" pfx name)))
    (dolist (it (dat-items d))
      (ecase (first it)
        (:int (destructuring-bind (size value) (rest it)
                (let ((decl (ecase size (1 ".byte") (2 ".short") (4 ".int") (8 ".quad")))
                      (v (if (= size 8) (norm-i64 value)
                             (logand value (1- (ash 1 (* 8 size)))))))
                  (format s "~C~a ~d~%" #\Tab decl v))))
        (:str (format s "~C.ascii ~a~%" #\Tab (second it)))
        (:ref (destructuring-bind (size name off) (rest it)
                (format s "~C~a ~a~a~@[~a~]~%" #\Tab (if (= size 8) ".quad" ".int")
                        pfx name (unless (zerop off) (format nil "~@d" off)))))
        (:zero (format s "~C.zero ~d~%" #\Tab (second it)))))
    (format s "~%")))

(defun a64-be-emit-module (module &optional (*target* *arm64-apple-target*))
  "Run the arm64 backend per function and return the module's mach-o assembly."
  (let ((s (make-string-output-stream)) (*a64-id0* 0))
    (setf *tmp-counter* 0)
    (reset-stash)
    (dolist (fn (module-funcs module))
      (a64-backend-pipeline fn)
      (a64-be-emit-fn fn s))
    (dolist (d (module-data module)) (a64-emit-data d s))
    (a64-emit-fin s)
    (get-output-stream-string s)))

;;; ------------------------------------------------------------ fp-const pool
(defparameter *a64-macho-litsec*
  #("__TEXT,__literal4,4byte_literals"
    "__TEXT,__literal8,8byte_literals"
    "__TEXT,__literal16,16byte_literals")
  "arm64/emit.c macho_emitfin sec[]: mach-o literal sections by log2 size-4.")

(defun a64-emit-fin (stream)
  "arm64/emit.c macho_emitfin -> emitfin: the fp-constant pool, grouped by size
(16/8/4) but labelled by insertion index, in mach-o literal sections."
  (when (> (fill-pointer *stash*) 0)
    (format stream "/* floating point constants */~%")
    (loop for lg from 4 downto 2 do
      (dotimes (i (fill-pointer *stash*))
        (let ((b (aref *stash* i)))
          (when (= (cdr b) (ash 1 lg))
            (format stream ".section ~a~%.p2align ~d~%~afp~d:"
                    (aref *a64-macho-litsec* (- lg 2)) lg (tg-asloc) i)
            (ecase lg
              (4 (format stream "~%~C.quad ~d~%~C.quad 0~%~%" #\Tab (car b) #\Tab))
              (3 (format stream "~%~C.quad ~d~%~%" #\Tab (car b)))
              (2 (format stream "~%~C.int ~d~%~%" #\Tab (s32* (car b)))))))))))
