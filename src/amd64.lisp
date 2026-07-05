;;;; amd64.lisp --- M1 walking-skeleton code generator for amd64 (System V).
;;;;
;;;; Deliberately the *most naive* correct scheme: every temporary lives in a
;;;; stack slot; each instruction loads its operands into scratch registers
;;;; (rax/rcx), computes, and stores the result back.  No register allocation,
;;;; no SSA analysis -- the input is already single-assignment.  This exists to
;;;; prove the vertical slice (parse -> lower -> emit -> as/ld -> run) end to
;;;; end; smarter isel/regalloc replace it later (M3/M4), and arm64 slots in as
;;;; another target.
;;;;
;;;; Scope: one basic block, integer classes w/l, ops
;;;;   par copy add sub mul and or xor neg  + ret/ret0.
;;;; Anything outside this signals an error rather than emitting wrong code.

(in-package #:qbe)

(defparameter *sysv-arg-gpr*
  #(("%rdi" . "%edi") ("%rsi" . "%esi") ("%rdx" . "%edx")
    ("%rcx" . "%ecx") ("%r8"  . "%r8d") ("%r9"  . "%r9d"))
  "System V integer argument registers, (64-bit . 32-bit).")

(defparameter *binop-mnemonic*
  '((:add . "add") (:sub . "sub") (:mul . "imul")
    (:and . "and") (:or . "or") (:xor . "xor")))

(defun m1-class (cls)
  "Only w/l are handled at M1."
  (unless (member cls '(:w :l))
    (error "amd64/M1: unsupported class ~s (only w/l)" cls))
  cls)

(defun reg-a (cls) (if (eq cls :l) "%rax" "%eax"))
(defun reg-c (cls) (if (eq cls :l) "%rcx" "%ecx"))
(defun suffix (cls) (if (eq cls :l) "q" "l"))

(defun collect-slots (fn)
  "Assign each defined temp a frame slot.  Returns (values slot-table nslots).
slot-table maps a tmp to its byte offset from %rbp (negative)."
  (let ((slots (make-hash-table :test 'eq)) (n 0))
    (flet ((assign (r)
             (when (and (tmp-p r) (not (gethash r slots)))
               (setf (gethash r slots) (- (* 8 (incf n)))))))
      (dolist (b (fn-blocks fn))
        (when (blk-phis b) (error "amd64/M1: phi unsupported"))
        (dolist (i (blk-ins b)) (assign (ins-to i)))))
    (values slots n)))

(defun slot-ref (slots r)
  (format nil "~d(%rbp)" (or (gethash r slots)
                             (error "amd64/M1: undefined temp ~s" (tmp-name r)))))

(defun const-imm (r cls)
  "Immediate string for a constant operand."
  (unless (and (con-p r) (eq (con-kind r) :bits))
    (error "amd64/M1: non-integer-constant operand ~s" r))
  (if (eq cls :l)
      (format nil "$~d" (con-value r))
      (format nil "$~d" (logand (con-value r) #xffffffff))))

(defun load-operand (r cls which slots stream)
  "Emit a load of operand R (temp or int const) into scratch reg WHICH (:a/:c)."
  (let ((reg (if (eq which :a) (reg-a cls) (reg-c cls))))
    (cond
      ((tmp-p r)
       (format stream "~amov~a ~a, ~a~%" #\Tab (suffix cls) (slot-ref slots r) reg))
      ((con-p r)
       (format stream "~amov~a ~a, ~a~%" #\Tab (suffix cls) (const-imm r cls) reg))
      (t (error "amd64/M1: bad operand ~s" r)))))

(defun store-result (to cls slots stream)
  (format stream "~amov~a ~a, ~a~%" #\Tab (suffix cls) (reg-a cls) (slot-ref slots to)))

(defun emit-ins (i slots param-counter stream)
  "Lower one instruction.  PARAM-COUNTER is a mutable cons cell (count)."
  (let ((op (ins-op i)) (cls (and (ins-to i) (m1-class (ins-cls i)))))
    (case op
      (:par
       (let* ((k (car param-counter))
              (regs (aref *sysv-arg-gpr* k)))
         (when (>= k (length *sysv-arg-gpr*))
           (error "amd64/M1: too many register params"))
         (setf (car param-counter) (1+ k))
         (format stream "~amov~a ~a, ~a~%" #\Tab (suffix cls)
                 (if (eq cls :l) (car regs) (cdr regs))
                 (slot-ref slots (ins-to i)))))
      (:copy
       (load-operand (ins-arg0 i) cls :a slots stream)
       (store-result (ins-to i) cls slots stream))
      (:neg
       (load-operand (ins-arg0 i) cls :a slots stream)
       (format stream "~aneg~a ~a~%" #\Tab (suffix cls) (reg-a cls))
       (store-result (ins-to i) cls slots stream))
      ((:add :sub :mul :and :or :xor)
       (load-operand (ins-arg0 i) cls :a slots stream)
       (load-operand (ins-arg1 i) cls :c slots stream)
       (format stream "~a~a~a ~a, ~a~%" #\Tab (cdr (assoc op *binop-mnemonic*))
               (suffix cls) (reg-c cls) (reg-a cls))
       (store-result (ins-to i) cls slots stream))
      (t (error "amd64/M1: unsupported op ~s" op)))))

(defun emit-fn (fn stream)
  (when (cdr (fn-blocks fn))
    (error "amd64/M1: multi-block functions unsupported (~a)" (fn-name fn)))
  (multiple-value-bind (slots n) (collect-slots fn)
    (let ((frame (* 16 (ceiling (* 8 n) 16)))
          (name (fn-name fn))
          (b (fn-start fn))
          (pc (list 0)))
      (format stream "~a.globl ~a~%~a.type ~a, @function~%~a:~%"
              #\Tab name #\Tab name name)
      ;; prologue
      (format stream "~apushq %rbp~%~amovq %rsp, %rbp~%" #\Tab #\Tab)
      (unless (zerop frame)
        (format stream "~asubq $~d, %rsp~%" #\Tab frame))
      ;; body
      (dolist (i (blk-ins b)) (emit-ins i slots pc stream))
      ;; return
      (let ((jt (blk-jmp-type b)) (arg (blk-jmp-arg b)))
        (case jt
          (:ret0)
          (:retw (load-operand arg :w :a slots stream))
          (:retl (load-operand arg :l :a slots stream))
          (t (error "amd64/M1: unsupported terminator ~s" jt))))
      (format stream "~aleave~%~aret~%~a.size ~a, .-~a~%"
              #\Tab #\Tab #\Tab name name))))
