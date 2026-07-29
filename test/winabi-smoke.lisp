;;;; winabi-smoke.lisp --- the Win64 register model, against winabi.c by hand.
;;;;   ros -Q run -- --script test/winabi-smoke.lisp
(require :asdf)
(push (truename (merge-pathnames "../" (directory-namestring *load-pathname*))) asdf:*central-registry*)
(handler-bind ((warning #'muffle-warning)) (asdf:load-system "qbe-cl" :verbose nil))
(in-package #:qbe)

(defvar *n* 0) (defvar *bad* 0)
(defun ck (what got want)
  (incf *n*)
  (if (equal got want)
      (format t "  ok   ~a~%" what)
      (progn (incf *bad*) (format t "  FAIL ~a~%    got  ~s~%    want ~s~%" what got want))))

;; rsave: RCX RDX R8 R9 R10 R11 RAX then XMM0..XMM14  (amd64_winabi_rsave)
(ck "rsave gp part" (coerce (subseq *winabi-rsave* 0 7) 'list)
    (list +rcx+ +rdx+ +r8+ +r9+ +r10+ +r11+ +rax+))
(ck "rsave length" (length *winabi-rsave*) (+ +ngps-win+ +amd64-nfpr+))
(ck "nrsave" (coerce *winabi-nrsave* 'list) (list 7 15))
;; rclob: RBX R12 R13 R14 R15 RSI RDI  -- RSI/RDI are callee-save on Windows
(ck "rclob" (coerce *winabi-rclob* 'list)
    (list +rbx+ +r12+ +r13+ +r14+ +r15+ +rsi+ +rdi+))
(ck "NCLR_WIN" (length *winabi-rclob*) +nclr-win+)

;; retregs: bit0 = rax returned, else xmm0
(ck "retregs int"   (multiple-value-list (amd64-winabi-retregs 1)) (list (list +rax+) 1 0))
(ck "retregs float" (multiple-value-list (amd64-winabi-retregs 2)) (list (list +xmm0+) 0 2))

;; argregs: bits 4-7 = rcx rdx r8 r9, bits 8-11 = xmm0..3, bit 12 = env(rax)
(ck "argregs (int,int)" (sort (nth 0 (multiple-value-list (amd64-winabi-argregs (ash 3 4)))) #'<)
    (sort (list +rcx+ +rdx+) #'<))
;; f(int, double): position 0 -> RCX, position 1 -> XMM1 (the shared counter!)
(ck "argregs (int,double) uses RCX and XMM1"
    (sort (nth 0 (multiple-value-list (amd64-winabi-argregs (logior (ash 1 4) (ash 2 8))))) #'<)
    (sort (list +rcx+ (+ +xmm0+ 1)) #'<))
(ck "argregs env adds rax"
    (nth 0 (multiple-value-list (amd64-winabi-argregs (ash 1 12)))) (list +rax+))

;;; --------------------------------------------- argument classification
(defun mkins (op cls &optional a0 to) (make-instance (quote ins) :op op :cls cls :to to :arg0 a0 :arg1 nil))
(defun mkty (size &optional dark) (let ((ty (make-instance (quote typ)))) (setf (typ-size ty) size (typ-isdark ty) dark (typ-align ty) 3) ty))
(defun styles (args) (let ((u (make-wusage))) (multiple-value-bind (acs env) (winabi-classify u args) (declare (ignore env)) (values (map (quote list) (function warg-style) acs) u))))

;; ONE counter: f(int, double) -> RCX and XMM1 (XMM0 skipped)
(multiple-value-bind (st u) (styles (list (mkins :arg :l) (mkins :arg :d)))
  (ck "classify (int,double) styles" st (list :register :register))
  (ck "classify (int,double) mask" (format nil "~4,'0x" (winabi-call-arg-value u)) "0210"))

;; five register-class arguments: the 5th spills to the stack
(ck "5th argument goes on the stack"
    (styles (list (mkins :arg :l) (mkins :arg :l) (mkins :arg :l) (mkins :arg :l) (mkins :arg :l)))
    (list :register :register :register :register :inline-on-stack))

;; 1/2/4/8 byte aggregates go in a register; anything else is copied by pointer
(dolist (c (list (cons 8 :register) (cons 4 :register) (cons 5 :copy-and-pointer-in-register)
                 (cons 16 :copy-and-pointer-in-register)))
  (ck (format nil "struct of ~d bytes" (car c))
      (styles (list (mkins :argc :l (mkty (car c))))) (list (cdr c))))

;; a varargs call duplicates float args into the matching integer register
(multiple-value-bind (st u) (styles (list (mkins :argv :w) (mkins :arg :d)))
  (declare (ignore st))
  (ck "varargs duplicates XMM0 into RCX" (format nil "~4,'0x" (winabi-call-arg-value u)) "0110"))

(format t "~&~%  ~a  (~d 件中 ~d 失敗)~%" (if (zerop *bad*) "全部 ok" "FAILED") *n* *bad*)
(uiop:quit (if (zerop *bad*) 0 1))
