;;;; amd64.lisp --- naive code generator for amd64 (System V).
;;;;
;;;; Still the "everything in a stack slot, one instruction at a time via
;;;; rax/rcx scratch" scheme -- no register allocation, no SSA construction.
;;;; What M1 grew into (milestone "B"): multiple blocks + control flow, so real
;;;; branching/looping programs run end to end.
;;;;
;;;; Covers: integer classes w/l; ops
;;;;   par copy add sub mul and or xor neg
;;;;   c{eq,ne,slt,sle,sgt,sge,ult,ule,ugt,uge}{w,l}   (comparisons -> 0/1)
;;;;   load{sb,ub,sh,uh,sw,uw} load  store{b,h,w,l}  alloc{4,8,16}
;;;; terminators jmp / jnz / ret / ret0, and phi (lowered to edge copies).
;;;; Floats, calls, blit, and variadics are out of scope and error out.

(in-package #:qbe)

(defparameter *sysv-arg-gpr*
  #(("%rdi" . "%edi") ("%rsi" . "%esi") ("%rdx" . "%edx")
    ("%rcx" . "%ecx") ("%r8"  . "%r8d") ("%r9"  . "%r9d")))

(defparameter *binop-mnemonic*
  '((:add . "add") (:sub . "sub") (:mul . "imul")
    (:and . "and") (:or . "or") (:xor . "xor")))

;;; comparison op keyword -> (setcc-suffix . operand-class)
(defparameter *cmp-info*
  (let ((h (make-hash-table :test 'eq)))
    (loop for (base . cc) in '(("ceq" . "e")  ("cne" . "ne")
                               ("csge" . "ge") ("csgt" . "g")
                               ("csle" . "le") ("cslt" . "l")
                               ("cuge" . "ae") ("cugt" . "a")
                               ("cule" . "be") ("cult" . "b"))
          do (dolist (cls '(:w :l))
               (setf (gethash (intern (string-upcase
                                       (concatenate 'string base
                                                    (if (eq cls :w) "w" "l")))
                                      :keyword) h)
                     (cons cc cls))))
    h))

;;; load op keyword -> (mnemonic-for-w . mnemonic-for-l), and the dest reg is
;;; %eax for w, %rax for l.
(defparameter *load-info*
  '((:loadsb "movsbl" . "movsbq") (:loadub "movzbl" . "movzbq")
    (:loadsh "movswl" . "movswq") (:loaduh "movzwl" . "movzwq")
    (:loadsw "movl"   . "movslq") (:loaduw "movl"   . "movl")
    (:load   "movl"   . "movq")))

;;; store op keyword -> (mnemonic . value-reg)
(defparameter *store-info*
  '((:storeb "movb" . "%cl") (:storeh "movw" . "%cx")
    (:storew "movl" . "%ecx") (:storel "movq" . "%rcx")))

(defun m1-class (cls)
  (unless (member cls '(:w :l))
    (error "amd64: unsupported class ~s (integer w/l only)" cls))
  cls)

(defun reg-a (cls) (if (eq cls :l) "%rax" "%eax"))
(defun reg-c (cls) (if (eq cls :l) "%rcx" "%ecx"))
(defun suffix (cls) (if (eq cls :l) "q" "l"))
(defun alloc-align (op) (ecase op (:alloc4 4) (:alloc8 8) (:alloc16 16)))

;;; ------------------------------------------------------------ frame layout

(defstruct frame slots allocs staging size)
;; slots:   tmp -> byte offset from %rbp (negative)
;; allocs:  alloc-ins -> byte offset of its region base
;; staging: vector of staging-slot offsets, for phi edge copies

(defun layout-frame (fn)
  (let ((slots (make-hash-table :test 'eq))
        (allocs (make-hash-table :test 'eq))
        (used 0) (maxphi 0))
    (flet ((slot! (r) (when (and (tmp-p r) (not (gethash r slots)))
                        (setf (gethash r slots) (- (incf used 8))))))
      ;; temp slots (phi + ins destinations), in a deterministic order
      (dolist (b (fn-blocks fn))
        (setf maxphi (max maxphi (length (blk-phis b))))
        (dolist (p (blk-phis b)) (slot! (phi-to p)))
        (dolist (i (blk-ins b)) (slot! (ins-to i))))
      ;; phi staging slots
      (let ((staging (make-array maxphi)))
        (dotimes (i maxphi) (setf (aref staging i) (- (incf used 8))))
        ;; alloca regions
        (dolist (b (fn-blocks fn))
          (dolist (i (blk-ins b))
            (when (member (ins-op i) '(:alloc4 :alloc8 :alloc16))
              (let* ((sz (const-size (ins-arg0 i)))
                     (al (alloc-align (ins-op i))))
                (setf used (* al (ceiling (+ used sz) al)))
                (setf (gethash i allocs) (- used))))))
        (make-frame :slots slots :allocs allocs :staging staging
                    :size (* 16 (ceiling used 16)))))))

(defun const-size (r)
  (if (and (con-p r) (eq (con-kind r) :bits)) (con-value r)
      (error "amd64: alloc size must be a constant")))

;;; ------------------------------------------------------------ operands

(defun slot-ref (fr r)
  (format nil "~d(%rbp)" (or (gethash r (frame-slots fr))
                             (error "amd64: undefined temp ~s" (tmp-name r)))))

(defun const-imm (r cls)
  (unless (and (con-p r) (eq (con-kind r) :bits))
    (error "amd64: non-integer-constant operand ~s" r))
  (format nil "$~d" (if (eq cls :l) (con-value r) (logand (con-value r) #xffffffff))))

(defun load-operand (r cls which fr stream)
  (let ((reg (if (eq which :a) (reg-a cls) (reg-c cls))))
    (cond
      ((tmp-p r) (format stream "~amov~a ~a, ~a~%" #\Tab (suffix cls) (slot-ref fr r) reg))
      ((con-p r) (format stream "~amov~a ~a, ~a~%" #\Tab (suffix cls) (const-imm r cls) reg))
      (t (error "amd64: bad operand ~s" r)))))

(defun store-a (to cls fr stream)
  (format stream "~amov~a ~a, ~a~%" #\Tab (suffix cls) (reg-a cls) (slot-ref fr to)))

;;; ------------------------------------------------------------ instructions

(defun emit-ins (i fr param-counter stream)
  (let* ((op (ins-op i)) (cmp (gethash op *cmp-info*))
         (cls (and (ins-to i) (m1-class (ins-cls i)))))
    (cond
      ((eq op :par)
       (let ((k (car param-counter)))
         (when (>= k (length *sysv-arg-gpr*)) (error "amd64: too many register params"))
         (setf (car param-counter) (1+ k))
         (format stream "~amov~a ~a, ~a~%" #\Tab (suffix cls)
                 (let ((regs (aref *sysv-arg-gpr* k))) (if (eq cls :l) (car regs) (cdr regs)))
                 (slot-ref fr (ins-to i)))))
      ((eq op :copy)
       (load-operand (ins-arg0 i) cls :a fr stream)
       (store-a (ins-to i) cls fr stream))
      ((eq op :neg)
       (load-operand (ins-arg0 i) cls :a fr stream)
       (format stream "~aneg~a ~a~%" #\Tab (suffix cls) (reg-a cls))
       (store-a (ins-to i) cls fr stream))
      ((assoc op *binop-mnemonic*)
       (load-operand (ins-arg0 i) cls :a fr stream)
       (load-operand (ins-arg1 i) cls :c fr stream)
       (format stream "~a~a~a ~a, ~a~%" #\Tab (cdr (assoc op *binop-mnemonic*))
               (suffix cls) (reg-c cls) (reg-a cls))
       (store-a (ins-to i) cls fr stream))
      (cmp
       (destructuring-bind (cc . ocls) cmp
         (load-operand (ins-arg0 i) ocls :a fr stream)
         (load-operand (ins-arg1 i) ocls :c fr stream)
         (format stream "~acmp~a ~a, ~a~%" #\Tab (suffix ocls) (reg-c ocls) (reg-a ocls))
         (format stream "~aset~a %al~%~amovzbl %al, %eax~%" #\Tab cc #\Tab)
         (store-a (ins-to i) cls fr stream)))
      ((assoc op *load-info*)
       (destructuring-bind (wm . lm) (cdr (assoc op *load-info*))
         (load-operand (ins-arg0 i) :l :a fr stream)   ; pointer
         ;; The destination register width follows the *mnemonic* (…q => 64-bit),
         ;; not the result class: e.g. loaduw into an l temp is `movl (%rax),%eax`
         ;; (movl zero-extends into rax), never `movl …,%rax` (which won't assemble).
         (let* ((mn (if (eq cls :l) lm wm))
                (dst (if (char= (char mn (1- (length mn))) #\q) "%rax" "%eax")))
           (format stream "~a~a (%rax), ~a~%" #\Tab mn dst))
         (store-a (ins-to i) cls fr stream)))
      ((assoc op *store-info*)
       (destructuring-bind (mn . vreg) (cdr (assoc op *store-info*))
         (load-operand (ins-arg1 i) :l :a fr stream)   ; pointer -> rax
         (load-operand (ins-arg0 i) (if (eq op :storel) :l :w) :c fr stream) ; value -> rcx/ecx
         (format stream "~a~a ~a, (%rax)~%" #\Tab mn vreg)))
      ((member op '(:alloc4 :alloc8 :alloc16))
       (format stream "~aleaq ~d(%rbp), %rax~%" #\Tab (gethash i (frame-allocs fr)))
       (store-a (ins-to i) :l fr stream))
      (t (error "amd64: unsupported op ~s" op)))))

;;; ------------------------------------------------------------ phi lowering

(defun emit-edge (pred succ fr stream)
  "Move each phi in SUCC's PRED-argument into the phi's slot (2-phase to be
safe against parallel-copy hazards)."
  (let ((phis (blk-phis succ)) (staging (frame-staging fr)))
    (loop for p in phis for i from 0 do
      (let ((src (cdr (assoc pred (phi-args p)))) (cls (m1-class (phi-cls p))))
        (load-operand src cls :a fr stream)
        (format stream "~amov~a ~a, ~d(%rbp)~%" #\Tab (suffix cls)
                (reg-a cls) (aref staging i))))
    (loop for p in phis for i from 0 do
      (let ((cls (m1-class (phi-cls p))))
        (format stream "~amov~a ~d(%rbp), ~a~%" #\Tab (suffix cls)
                (aref staging i) (reg-a cls))
        (store-a (phi-to p) cls fr stream)))))

;;; ------------------------------------------------------------ function

(defun emit-fn (fn stream &optional (fnid 0))
  (let* ((fr (layout-frame fn))
         (name (fn-name fn))
         (blocks (fn-blocks fn))
         (blk-labels (let ((h (make-hash-table :test 'eq)))
                       (loop for b in blocks for k from 0
                             do (setf (gethash b h) (format nil ".LBB~d_~d" fnid k)))
                       h))
         (pc (list 0)))
    (flet ((lbl (b) (gethash b blk-labels)))
      (format stream "~a.globl ~a~%~a.type ~a, @function~%~a:~%"
              #\Tab name #\Tab name name)
      (format stream "~apushq %rbp~%~amovq %rsp, %rbp~%" #\Tab #\Tab)
      (unless (zerop (frame-size fr))
        (format stream "~asubq $~d, %rsp~%" #\Tab (frame-size fr)))
      (loop for (b . rest) on blocks
            for next = (car rest) do
        (format stream "~a:~%" (lbl b))
        (dolist (i (blk-ins b)) (emit-ins i fr pc stream))
        (let ((jt (blk-jmp-type b)))
          (case jt
            (:ret0 (format stream "~aleave~%~aret~%" #\Tab #\Tab))
            ((:retw :retl)
             (load-operand (blk-jmp-arg b) (if (eq jt :retw) :w :l) :a fr stream)
             (format stream "~aleave~%~aret~%" #\Tab #\Tab))
            (:jmp
             (emit-edge b (blk-s1 b) fr stream)
             (unless (eq (blk-s1 b) next)
               (format stream "~ajmp ~a~%" #\Tab (lbl (blk-s1 b)))))
            (:jnz
             (let ((else (format nil ".LBB~d_~de" fnid (position b blocks))))
               (load-operand (blk-jmp-arg b) :w :a fr stream)
               (format stream "~atestl %eax, %eax~%~aje ~a~%" #\Tab #\Tab else)
               (emit-edge b (blk-s1 b) fr stream)
               (format stream "~ajmp ~a~%~a:~%" #\Tab (lbl (blk-s1 b)) else)
               (emit-edge b (blk-s2 b) fr stream)
               (format stream "~ajmp ~a~%" #\Tab (lbl (blk-s2 b)))))
            (t (error "amd64: unsupported terminator ~s" jt)))))
      (format stream "~a.size ~a, .-~a~%" #\Tab name name))))
