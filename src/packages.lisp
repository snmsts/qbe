;;;; packages.lisp
(defpackage #:qbe
  (:use #:cl)
  (:documentation "QBE IL: data model, parser, printer.")
  (:export
   ;; ir
   #:module #:module-funcs #:module-types
   #:fn #:fn-name #:fn-export #:fn-retclass #:fn-rettyp #:fn-vararg #:fn-blocks #:fn-start
   #:blk #:blk-name #:blk-phis #:blk-ins #:blk-jmp-type #:blk-jmp-arg #:blk-s1 #:blk-s2 #:blk-link
   #:blk-id #:blk-preds #:blk-idom #:blk-doms #:blk-fron #:fn-rpo #:fn-nblk
   #:blk-depth #:blk-loop
   #:phi #:phi-to #:phi-cls #:phi-args
   #:ins #:ins-op #:ins-cls #:ins-to #:ins-arg0 #:ins-arg1
   #:typ #:typ-name
   #:tmp #:make-tmp #:tmp-name #:tmp-p
   #:con #:make-con #:con-kind #:con-value #:con-flt #:con-symname #:con-symtype #:con-off #:con-p
   ;; ops
   #:*op-names* #:op-keyword #:classchar-op-p
   ;; parse / print
   #:parse-string #:parse-file
   #:print-fn #:print-fn-to-string
   ;; cfg / dominators (M2/A1)
   #:fill-cfg #:fill-rpo #:fill-preds #:fill-dom #:fill-fron #:sdom #:dom
   #:fill-depth #:fill-loop #:lca #:simplcfg #:gcm #:ifconvert
   ;; ssa construction (M2/A2+A3)
   #:fn-tmp #:fn-ntmp #:blk-in #:blk-out #:blk-gen
   #:fill-use #:fill-live #:phiins #:renblk #:ssa #:*tmp-counter*
   ;; memory opt (M2/A4)
   #:promote
   ;; gvn (M2/C3)
   #:gvn #:normins #:getcon #:isconbits
   ;; amd64 abi lowering (M3/B1)
   #:amd64-abi #:amd64-isel #:simpl #:reg #:reg-p #:reg-id #:call-ref #:call-ref-p #:slot-ref-p
   ;; backend (M4): register materialization, liveness, spill costs
   #:materialize-regs #:be-fill-live #:fill-cost #:ref-tid #:tid-ref #:+tmp0+
   ;; amd64 codegen (M1) + driver
   #:emit-fn #:emit-module #:module-asm-string
   #:build-exe #:compile-and-run))
