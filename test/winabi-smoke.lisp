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

(format t "~&~%  ~a  (~d 件中 ~d 失敗)~%" (if (zerop *bad*) "全部 ok" "FAILED") *n* *bad*)
(uiop:quit (if (zerop *bad*) 0 1))
