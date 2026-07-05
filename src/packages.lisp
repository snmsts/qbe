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
   ;; ssa construction (M2/A2+A3)
   #:fn-tmp #:fn-ntmp #:blk-in #:blk-out #:blk-gen
   #:fill-use #:fill-live #:phiins #:renblk #:ssa #:*tmp-counter*
   ;; amd64 codegen (M1) + driver
   #:emit-fn #:emit-module #:module-asm-string
   #:build-exe #:compile-and-run))
