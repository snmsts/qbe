;;;; parse.lisp --- QBE IL text -> module  (mirrors parse.c)
;;;;
;;;; Reproduces the parser's *internal-form* transformations so that
;;;; print-fn output matches `qbe -dP` byte-for-byte:
;;;;   - params      become  par/parsb/.../parc/pare  ins at head of block 1
;;;;   - call args   become  arg/argsb/.../argc/arge/argv  ins before the call
;;;;   - `ret`       becomes a ret<class> / ret0 / retc terminator
;;;;   - `blit`      becomes blit0 + blit1
;;;;   - loadw->loadsw, load{l,s,d}->load

(in-package #:qbe)

;;; ---------------------------------------------------------------- lexer

(defstruct (lx (:constructor %make-lx))
  (str "") (pos 0) (len 0) (ahead nil))

(defun make-lexer (str) (%make-lx :str str :len (length str)))

(declaim (inline word-char-p))
(defun word-char-p (c)
  (or (alpha-char-p c) (digit-char-p c)
      (char= c #\.) (char= c #\_) (char= c #\$)))

(defun parse-c-float (s)
  "Parse a C float/double literal into a double-float."
  (let ((*read-default-float-format* 'double-float))
    (coerce (read-from-string s) 'double-float)))

(defun lx-scan (l)
  "Produce the next raw token as (TYPE . VALUE)."
  (let ((s (lx-str l)) (n (lx-len l)))
    (macrolet ((c () `(char s (lx-pos l)))
               (adv () `(incf (lx-pos l))))
      ;; skip blanks (not newlines)
      (loop while (and (< (lx-pos l) n)
                       (member (c) '(#\Space #\Tab)))
            do (adv))
      (when (>= (lx-pos l) n) (return-from lx-scan '(:eof)))
      (let ((ch (c)))
        (cond
          ((char= ch #\Newline) (adv) '(:nl))
          ((char= ch #\#)                 ; comment to end of line
           (loop while (and (< (lx-pos l) n) (char/= (c) #\Newline)) do (adv))
           (when (< (lx-pos l) n) (adv))  ; consume the newline
           '(:nl))
          ((char= ch #\,) (adv) '(:comma))
          ((char= ch #\() (adv) '(:lparen))
          ((char= ch #\)) (adv) '(:rparen))
          ((char= ch #\{) (adv) '(:lbrace))
          ((char= ch #\}) (adv) '(:rbrace))
          ((char= ch #\=) (adv) '(:eq))
          ((char= ch #\+) (adv) '(:plus))
          ((char= ch #\") (lx-scan-string l))
          ((member ch '(#\% #\@ #\$ #\:)) (lx-scan-sigil l ch))
          ;; float literal:  s_...  or  d_...
          ((and (member ch '(#\s #\d))
                (< (1+ (lx-pos l)) n)
                (char= (char s (1+ (lx-pos l))) #\_))
           (let ((sd ch))
             (adv) (adv)                  ; skip letter and underscore
             (let ((start (lx-pos l)))
               (loop while (and (< (lx-pos l) n)
                                (find (c) "+-0123456789.eE"))
                     do (adv))
               (let ((v (parse-c-float (subseq s start (lx-pos l)))))
                 (if (char= sd #\s)
                     (cons :flts (coerce v 'single-float))
                     (cons :fltd v))))))
          ;; integer
          ((or (digit-char-p ch)
               (and (char= ch #\-) (< (1+ (lx-pos l)) n)
                    (digit-char-p (char s (1+ (lx-pos l))))))
           (let ((start (lx-pos l)))
             (adv)
             (loop while (and (< (lx-pos l) n) (digit-char-p (c))) do (adv))
             (cons :int (parse-integer s :start start :end (lx-pos l)))))
          ;; word / keyword
          ((word-char-p ch)
           (let ((start (lx-pos l)))
             (loop while (and (< (lx-pos l) n) (word-char-p (c))) do (adv))
             (cons :word (subseq s start (lx-pos l)))))
          (t (error "qbe: invalid character ~s at ~d" ch (lx-pos l))))))))

(defun lx-scan-sigil (l ch)
  (let ((s (lx-str l)) (n (lx-len l))
        (type (ecase ch (#\% :tmp) (#\@ :lbl) (#\$ :glo) (#\: :typ))))
    (incf (lx-pos l))                     ; consume sigil
    ;; $"quoted name"
    (when (and (char= ch #\$) (< (lx-pos l) n) (char= (char s (lx-pos l)) #\"))
      (let ((start (lx-pos l)))
        (incf (lx-pos l))
        (loop while (and (< (lx-pos l) n) (char/= (char s (lx-pos l)) #\"))
              do (incf (lx-pos l)))
        (when (< (lx-pos l) n) (incf (lx-pos l)))
        (return-from lx-scan-sigil (cons :glo (subseq s start (lx-pos l))))))
    (let ((start (lx-pos l)))
      (loop while (and (< (lx-pos l) n) (word-char-p (char s (lx-pos l))))
            do (incf (lx-pos l)))
      (cons type (subseq s start (lx-pos l))))))

(defun lx-scan-string (l)
  (let ((s (lx-str l)) (n (lx-len l)) (start (lx-pos l)) (esc nil))
    (incf (lx-pos l))                     ; opening quote
    (loop for c = (and (< (lx-pos l) n) (char s (lx-pos l)))
          while c do
            (incf (lx-pos l))
            (cond (esc (setf esc nil))
                  ((char= c #\\) (setf esc t))
                  ((char= c #\") (loop-finish))))
    (cons :str (subseq s start (lx-pos l)))))

(defun lx-peek (l) (or (lx-ahead l) (setf (lx-ahead l) (lx-scan l))))
(defun lx-pop (l) (prog1 (lx-peek l) (setf (lx-ahead l) nil)))
(defun lx-pop-nn (l)                      ; pop, skipping newlines
  (loop while (eq (car (lx-peek l)) :nl) do (lx-pop l))
  (lx-pop l))
(defun lx-peek-nn (l)
  (loop while (eq (car (lx-peek l)) :nl) do (lx-pop l))
  (lx-peek l))

(defun expect (l type)
  (let ((tok (lx-pop l)))
    (unless (eq (car tok) type)
      (error "qbe: expected ~s, got ~s" type tok))
    tok))

;;; ------------------------------------------------- constant interning
;;;
;;; QBE's newcon() dedups constants by (type, sym, bits.i) and IGNORES the
;;; `flt` display flag; con[1] is pre-seeded as the integer 0.  Consequently
;;; d_0 / s_0 collapse onto that integer 0 and print as "0".  We replicate
;;; the dedup so print output is byte-identical.

(defun norm-i64 (x)
  (let ((m (logand x #xFFFFFFFFFFFFFFFF)))
    (if (>= m #x8000000000000000) (- m #x10000000000000000) m)))

(defun double-bits (d)
  (logior (ash (ldb (byte 32 0) (sb-kernel:double-float-high-bits d)) 32)
          (sb-kernel:double-float-low-bits d)))

(defun con-rawbits (c)
  "The 64-bit union payload QBE compares on (bits.i)."
  (case (con-flt c)
    (1 (ldb (byte 32 0) (sb-kernel:single-float-bits (con-value c))))
    (2 (norm-i64 (double-bits (con-value c))))
    (t (norm-i64 (con-value c)))))

(defun con-key (c)
  (ecase (con-kind c)
    (:bits (list :bits (con-rawbits c)))
    (:addr (list :addr (con-symname c) (con-symtype c)))))

;;; ---------------------------------------------------------------- module

(defun intern-type (mod name)
  (or (gethash name (module-types mod))
      (setf (gethash name (module-types mod)) (make-instance 'typ :name name))))

(defun parse-string (text)
  (let ((l (make-lexer text))
        (mod (make-instance 'module)))
    (loop
      (let ((export nil) tok)
        ;; leading linkage
        (loop
          (setf tok (lx-pop-nn l))
          (cond
            ((eq (car tok) :eof) (return-from parse-string
                                   (progn (setf (module-funcs mod)
                                                (nreverse (module-funcs mod)))
                                          mod)))
            ((word= tok "export") (setf export t))
            ((word= tok "thread"))        ; linkage flags we don't model at M0
            ((word= tok "common"))
            ((word= tok "section")        ; section "name" ["flags"]
             (expect l :str)
             (when (eq (car (lx-peek l)) :str) (lx-pop l)))
            (t (return))))
        ;; top-level definition
        (cond
          ((word= tok "function")
           (push (parse-fn l mod export) (module-funcs mod)))
          ((word= tok "type")  (parse-type l mod))
          ((word= tok "data")  (skip-braced l))
          ((word= tok "dbgfile") (expect l :str))
          (t (error "qbe: top-level definition expected, got ~s" tok)))))))

(defun word= (tok str) (and (eq (car tok) :word) (string= (cdr tok) str)))

(defun parse-type (l mod)
  ;; type :NAME = [align N] { ... }
  (let ((nm (expect l :typ)))
    (intern-type mod (cdr nm))
    (expect l :eq)
    (skip-braced l)))

(defun skip-braced (l)
  "Consume tokens up to and including the matching closing brace of the
next `{ ... }` group (handles nested braces, e.g. unions)."
  (loop for tok = (lx-pop l)
        until (eq (car tok) :lbrace)
        when (eq (car tok) :eof) do (error "qbe: unexpected eof, { expected"))
  (let ((depth 1))
    (loop until (zerop depth)
          for tok = (lx-pop l) do
            (case (car tok)
              (:lbrace (incf depth))
              (:rbrace (decf depth))
              (:eof (error "qbe: unexpected eof in braced group"))))))

;;; ---------------------------------------------------------------- classes

(defun parse-class (l mod)
  "Consume a class specifier token; return (values class-keyword typ)."
  (let ((tok (lx-pop l)))
    (case (car tok)
      (:typ (values :c (intern-type mod (cdr tok))))
      (:word
       (values
        (cond ((string= (cdr tok) "w") :w) ((string= (cdr tok) "l") :l)
              ((string= (cdr tok) "s") :s) ((string= (cdr tok) "d") :d)
              ((string= (cdr tok) "sb") :sb) ((string= (cdr tok) "ub") :ub)
              ((string= (cdr tok) "sh") :sh) ((string= (cdr tok) "uh") :uh)
              (t (error "qbe: invalid class specifier ~s" tok)))
        nil))
      (t (error "qbe: invalid class specifier ~s" tok)))))

(defparameter *subword-par* '((:sb . :parsb) (:ub . :parub) (:sh . :parsh) (:uh . :paruh)))
(defparameter *subword-arg* '((:sb . :argsb) (:ub . :argub) (:sh . :argsh) (:uh . :arguh)))

(defun retclass->rettype (rc)
  (ecase rc
    (:w :retw) (:l :retl) (:s :rets) (:d :retd)
    (:sb :retsb) (:ub :retub) (:sh :retsh) (:uh :retuh)
    (:c :retc) (:0 :ret0)))

;;; ---------------------------------------------------------------- function

(defun parse-fn (l mod export)
  (let ((fn (make-instance 'fn :name nil :export export))
        (tmps (make-hash-table :test 'equal))
        (blks (make-hash-table :test 'equal))
        (cons (make-hash-table :test 'equal))
        (ordered '())
        (cur nil) (cur-ins '()) (cur-phis '())
        (param-ins '()))
    ;; con[1]: the pre-seeded integer 0 that d_0/s_0 collapse onto.
    (setf (gethash '(:bits 0) cons) (make-con :kind :bits :value 0))
    (labels
        ((tmp-for (name)
           (or (gethash name tmps)
               (setf (gethash name tmps) (make-tmp name (hash-table-count tmps)))))
         (intern-con (c)
           (let ((k (con-key c)))
             (or (gethash k cons) (setf (gethash k cons) c))))
         (blk-for (name)
           (or (gethash name blks)
               (setf (gethash name blks)
                     (make-instance 'blk :name name))))
         (parse-ref ()
           (let ((tok (lx-pop l)))
             (case (car tok)
               (:tmp  (tmp-for (cdr tok)))
               ;; getint() reads uint64 then reinterprets as int64; wrap to match.
               (:int  (intern-con (make-con :kind :bits :value (norm-i64 (cdr tok)))))
               (:flts (intern-con (make-con :kind :bits :value (cdr tok) :flt 1)))
               (:fltd (intern-con (make-con :kind :bits :value (cdr tok) :flt 2)))
               (:glo  (intern-con (make-con :kind :addr :symname (cdr tok))))
               (:word (cond ((string= (cdr tok) "extern") (parse-glo '(:ext)))
                            ((string= (cdr tok) "thread") (parse-glo '(:thr)))
                            (t nil)))
               (t nil))))
         (parse-glo (types)
           (let ((tok (lx-pop l)))
             (cond ((word= tok "extern") (parse-glo (cons :ext types)))
                   ((word= tok "thread") (parse-glo (cons :thr types)))
                   ((eq (car tok) :glo)
                    (intern-con (make-con :kind :addr :symname (cdr tok) :symtype types)))
                   (t (error "qbe: global symbol expected, got ~s" tok)))))
         (emit (i) (push i cur-ins))
         (begin-block (name)
           (let ((b (blk-for name)))
             (when cur (finish-block b))
             (setf cur b)
             (setf cur-ins (if (null (fn-start fn)) (reverse param-ins) '()))
             (setf cur-phis '())
             (unless (fn-start fn) (setf (fn-start fn) b))
             (push b ordered)))
         (finish-block (next)
           (setf (blk-phis cur) (nreverse cur-phis))
           (setf (blk-ins cur) (nreverse cur-ins))
           (when (null (blk-jmp-type cur))     ; implicit fall-through
             (setf (blk-jmp-type cur) :jmp (blk-s1 cur) next))
           (setf (blk-link cur) next))
         (parse-arglist ()
           (expect l :lparen)
           (loop
             (when (eq (car (lx-peek l)) :rparen) (return))
             (let ((p (lx-peek l)))
               (cond
                 ((word= p "...") (lx-pop l)
                  (emit (make-instance 'ins :op :argv :cls :w)))
                 ((word= p "env") (lx-pop l)
                  (emit (make-instance 'ins :op :arge :cls :l :arg0 (parse-ref))))
                 (t (multiple-value-bind (k ty) (parse-class l mod)
                      (let ((r (parse-ref)))
                        (cond
                          ((eq k :c)
                           (emit (make-instance 'ins :op :argc :cls :l :arg0 ty :arg1 r)))
                          ((assoc k *subword-arg*)
                           (emit (make-instance 'ins :op (cdr (assoc k *subword-arg*))
                                                     :cls :w :arg0 r)))
                          (t (emit (make-instance 'ins :op :arg :cls k :arg0 r)))))))))
             (if (eq (car (lx-peek l)) :rparen) (return) (expect l :comma)))
           (expect l :rparen))
         (parse-args ()                    ; generic comma-separated refs -> 2
           (let ((acc '()))
             (loop
               (let ((tp (car (lx-peek l))))
                 (when (member tp '(:nl :eof :rbrace)) (return)))
               (push (parse-ref) acc)
               (if (eq (car (lx-peek l)) :comma) (lx-pop l) (return)))
             (setf acc (nreverse acc))
             (values (first acc) (second acc))))
         (con-int (r)                      ; RInt payload from a constant ref
           (if (and (con-p r) (eq (con-kind r) :bits)) (con-value r)
               (error "qbe: constant expected, got ~s" r)))
         (do-call (to k ty)
           (let ((callee (parse-ref)))
             (parse-arglist)               ; emits arg* ins
             (let ((cls (cond ((eq k :c) :l) ((assoc k *subword-par*) :w) (t k)))
                   (arg1 (when (eq k :c) ty)))
               (emit (make-instance 'ins :op :call :cls cls :to to
                                         :arg0 callee :arg1 arg1)))))
         (result-line (to)
           (expect l :eq)
           (multiple-value-bind (k ty) (parse-class l mod)
             (let ((op (lx-pop l)))
               (cond
                 ((word= op "phi")
                  (let ((args '()))
                    (loop
                      (let ((lbl (expect l :lbl)))
                        (push (cons (blk-for (cdr lbl)) (parse-ref)) args))
                      (if (eq (car (lx-peek l)) :comma) (lx-pop l) (return)))
                    (push (make-instance 'phi :to to :cls k :args (nreverse args))
                          cur-phis)))
                 ((word= op "call") (do-call to k ty))
                 ((eq (car op) :word)
                  (let ((opk (writable-op (cdr op))))
                    (unless opk (error "qbe: unknown instruction ~s" op))
                    (multiple-value-bind (a0 a1) (parse-args)
                      (emit (make-instance 'ins :op opk :cls k :to to
                                                :arg0 a0 :arg1 a1)))))
                 (t (error "qbe: instruction expected, got ~s" op))))))
         (resultless-line (op)
           (let ((name (cdr op)))
             (cond
               ((string= name "call")
                (let ((callee (parse-ref)))
                  (parse-arglist)
                  (emit (make-instance 'ins :op :call :cls :w :arg0 callee))))
               ((string= name "blit")
                (let ((src (parse-ref)))
                  (expect l :comma)
                  (let ((dst (parse-ref)))
                    (expect l :comma)
                    (let ((sz (con-int (parse-ref))))
                      (emit (make-instance 'ins :op :blit0 :arg0 src :arg1 dst))
                      (emit (make-instance 'ins :op :blit1 :arg0 sz))))))
               ((string= name "vastart")
                (emit (make-instance 'ins :op :vastart :arg0 (parse-ref))))
               ((string= name "dbgloc")
                (let ((line (cdr (expect l :int))) (col 0))
                  (when (eq (car (lx-peek l)) :comma)
                    (lx-pop l) (setf col (cdr (expect l :int))))
                  (emit (make-instance 'ins :op :dbgloc :arg0 line :arg1 col))))
               (t
                (let ((opk (writable-op name)))
                  (unless opk (error "qbe: unknown instruction ~s" op))
                  (multiple-value-bind (a0 a1) (parse-args)
                    (emit (make-instance 'ins :op opk :cls :w :arg0 a0 :arg1 a1))))))))
         (terminator (op)
           (let ((name (cdr op)))
             (cond
               ((string= name "ret")
                (setf (blk-jmp-type cur) (retclass->rettype (fn-retclass fn)))
                (cond
                  ((eq (car (lx-peek l)) :nl) (setf (blk-jmp-type cur) :ret0))
                  ((not (eq (fn-retclass fn) :0))
                   (setf (blk-jmp-arg cur) (parse-ref)))))
               ((string= name "jmp")
                (setf (blk-jmp-type cur) :jmp
                      (blk-s1 cur) (blk-for (cdr (expect l :lbl)))))
               ((string= name "jnz")
                (setf (blk-jmp-type cur) :jnz (blk-jmp-arg cur) (parse-ref))
                (expect l :comma)
                (setf (blk-s1 cur) (blk-for (cdr (expect l :lbl))))
                (expect l :comma)
                (setf (blk-s2 cur) (blk-for (cdr (expect l :lbl)))))
               ((string= name "hlt") (setf (blk-jmp-type cur) :hlt))
               (t (error "qbe: unknown terminator ~s" op))))))
      ;; ---- header ----
      (unless (eq (car (lx-peek l)) :glo)
        (multiple-value-bind (rc ty) (parse-class l mod)
          (setf (fn-retclass fn) rc (fn-rettyp fn) ty)))
      (setf (fn-name fn) (cdr (expect l :glo)))
      ;; params -> par ins (collected into param-ins, prepended to block 1)
      (expect l :lparen)
      (loop
        (when (eq (car (lx-peek l)) :rparen) (return))
        (let ((p (lx-peek l)))
          (cond
            ((word= p "...") (lx-pop l) (setf (fn-vararg fn) t))
            ((word= p "env") (lx-pop l)
             (push (make-instance 'ins :op :pare :cls :l :to (parse-ref)) param-ins))
            (t (multiple-value-bind (k ty) (parse-class l mod)
                 (let ((r (parse-ref)))
                   (cond
                     ((eq k :c)
                      (push (make-instance 'ins :op :parc :cls :l :to r :arg0 ty) param-ins))
                     ((assoc k *subword-par*)
                      (push (make-instance 'ins :op (cdr (assoc k *subword-par*))
                                                :cls :w :to r) param-ins))
                     (t (push (make-instance 'ins :op :par :cls k :to r) param-ins))))))))
        (if (eq (car (lx-peek l)) :rparen) (return) (expect l :comma)))
      (expect l :rparen)
      (setf param-ins (nreverse param-ins))
      (unless (eq (car (lx-pop-nn l)) :lbrace)
        (error "qbe: function body must start with {"))
      ;; ---- body ----
      (loop
        (let ((tok (lx-pop-nn l)))
          (case (car tok)
            (:rbrace (when cur (finish-block nil)) (return))
            (:lbl (begin-block (cdr tok)))
            (:tmp (result-line (tmp-for (cdr tok))))
            (:word
             (let ((name (cdr tok)))
               (cond
                 ((member name '("ret" "jmp" "jnz" "hlt") :test #'string=)
                  (terminator tok))
                 (t (resultless-line tok)))))
            (t (error "qbe: label, instruction or jump expected, got ~s" tok)))))
      (setf (fn-blocks fn) (nreverse ordered))
      fn)))

(defun parse-file (path)
  (with-open-file (in path :direction :input)
    (let* ((buf (make-string (file-length in)))
           (n (read-sequence buf in)))
      (parse-string (subseq buf 0 n)))))
