;;;; arm64-abi.lisp --- arm64 ABI lowering (G2), mirrors arm64/abi.c.
;;;;
;;;; Two passes, matching QBE's two `-dA` dumps for arm64_apple:
;;;;   abi0 = apple_extsb : "> After Apple pre-ABI:"  (sub-word ext insertion)
;;;;   abi1 = arm64_abi   : "> After ABI lowering:"   (params/returns/calls,
;;;;                         HFA + struct + stack + env + vararg)
;;;;
;;;; Like amd64-abi.lisp we reproduce QBE's backward `emit` by pushing onto
;;;; *emitted* in QBE's loop order, then reversing into the block.

(in-package #:qbe)

;;; ------------------------------------------------------------ abi0: extsb
;;; apple_extsb (arm64/abi.c): Apple passes/returns sub-word (b/h) scalars
;;; already sign/zero extended, so insert an ext{s,u}{b,h} around each argsb/
;;; argub/argsh/arguh call argument and each retsb/retub/retsh/retuh return.

(defparameter *argbh->ext*
  '((:argsb . :extsb) (:argub . :extub) (:argsh . :extsh) (:arguh . :extuh))
  "sub-word arg op -> the extension op that materializes its value.")

(defparameter *retbh->ext*
  '((:retsb . :extsb) (:retub . :extub) (:retsh . :extsh) (:retuh . :extuh))
  "sub-word ret terminator -> its extension op.")

(defun argbh-op-p (op) (and (assoc op *argbh->ext*) t))

(defun a64-apple-extsb (fn)
  "arm64/abi.c apple_extsb (abi0): extend sub-word call args and returns."
  (dolist (b (fn-blocks fn))
    (let ((*emitted* nil)
          (vec (coerce (blk-ins b) 'vector)))
      ;; return terminator: retbh -> ext into a fresh temp, then retw
      (let ((re (assoc (blk-jmp-type b) *retbh->ext*)))
        (when re
          (let ((r (newtmp "abi" :w fn)))
            (emit (cdr re) :w r (blk-jmp-arg b) nil)
            (setf (blk-jmp-arg b) r (blk-jmp-type b) :retw))))
      ;; walk instructions backward, re-emitting; around each call, extend its
      ;; sub-word args (QBE: replace argbh's result temp, feed the call the temp,
      ;; then emit the ext that fills it).
      (loop with k = (length vec) while (> k 0) do
        (decf k)
        (let ((i (aref vec k)))
          (cond
            ((eq (ins-op i) :call)
             ;; find the run of arg instructions [i0,k) preceding the call
             (let ((i0 k) (exts '()))
               (loop while (and (> i0 0) (arg-op-p (ins-op (aref vec (1- i0)))))
                     do (decf i0))
               ;; emit the call itself
               (push i *emitted*)
               ;; pass 1: emit args (k-1..i0).  For an argbh, thread its carried
               ;; value through a fresh Kl temp: the emitted arg now carries the
               ;; temp, and we remember (temp <- ext(original value)) for pass 2.
               (loop for j from (1- k) downto i0
                     for a = (aref vec j) do
                 (if (argbh-op-p (ins-op a))
                     (let ((r (newtmp "abi" :l fn)) (orig (ins-arg0 a)))
                       (setf (ins-arg0 a) r)
                       (push (list (cdr (assoc (ins-op a) *argbh->ext*)) r orig) exts))
                     nil)
                 (push a *emitted*))
               ;; pass 2: emit each ext (in the same backward order QBE uses)
               (dolist (e (nreverse exts))
                 (destructuring-bind (op r orig) e (emit op :w r orig nil)))
               (setf k i0)))
            (t (push i *emitted*)))))
      (setf (blk-ins b) *emitted*))))
