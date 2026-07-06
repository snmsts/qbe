**** Function chk ****
> After instruction selection:
function $chk() {
@l0
	%t1 =w copy R4
	%t0 =w copy R5
	%t17 =l extsw %t0
	%t18 =l mul %t17, 8
	%t34 =l extsw %t1
	%t35 =l mul %t34, 4
@l1
	%r.3 =w phi @l0 0, @l14 %r.10
	%i.4 =w phi @l0 0, @l14 %t152
	%t7 =w loadsw $glo1
	xcmpw %t7, %i.4
	jfislt @l2, @l3
@l2
	%t15 =l load $glo3
	%t13 =l load [%t15 + 1 * %t18]
	%t20 =l extsw %i.4
	%t11 =w loadsw [%t13 + 4 * %t20]
	%t9 =w add %t11, %r.3
	%t27 =l load [%t15 + 8 * %t20]
	%t25 =w loadsw [%t27 + 1 * %t35]
	%t23 =w add %t9, %t25
	%t38 =w add %t0, %i.4
	xcmpw %t7, %t38
	%t37 =w flagislt
	%t43 =w add %t1, %i.4
	xcmpw %t7, %t43
	%t42 =w flagislt
	%t36 =w and %t37, %t42
	%t58 =l extsw %t38
	%t59 =l mul %t58, 8
	%t63 =l extsw %t43
	%t64 =l mul %t63, 4
	xcmpw 0, %t36
	jfine @l4, @l5
@l4
	%t52 =l load [%t15 + 1 * %t59]
	%t50 =w loadsw [%t52 + 1 * %t64]
	%t48 =w add %t23, %t50
@l5
	%r.7 =w phi @l2 %t23, @l4 %t48
	%t73 =w sub %t1, %i.4
	xcmpw 0, %t73
	%t71 =w flagisge
	%t65 =w and %t37, %t71
	%t92 =l extsw %t73
	%t93 =l mul %t92, 4
	xcmpw 0, %t65
	jfine @l7, @l8
@l7
	%t81 =l load [%t15 + 1 * %t59]
	%t79 =w loadsw [%t81 + 1 * %t93]
	%t77 =w add %t79, %r.7
@l8
	%r.8 =w phi @l5 %r.7, @l7 %t77
	%t97 =w sub %t0, %i.4
	xcmpw 0, %t97
	%t95 =w flagisge
	%t94 =w and %t42, %t95
	%t116 =l extsw %t97
	%t117 =l mul %t116, 8
	xcmpw 0, %t94
	jfine @l10, @l11
@l10
	%t110 =l load [%t15 + 1 * %t117]
	%t108 =w loadsw [%t64 + 1 * %t110]
	%t106 =w add %t108, %r.8
@l11
	%r.9 =w phi @l8 %r.8, @l10 %t106
	xtestw %t71, %t95
	jfine @l13, @l14
@l13
	%t139 =l load [%t15 + 1 * %t117]
	%t137 =w loadsw [%t93 + 1 * %t139]
	%t135 =w add %t137, %r.9
@l14
	%r.10 =w phi @l11 %r.9, @l13 %t135
	%t152 =w add %i.4, 1
	jmp @l1
@l3
	R1 =w copy %r.3
	ret0 0001
}

**** Function go ****
> After instruction selection:
function $go() {
@l16
	%t0 =w copy R5
	%t3 =w loadsw $glo1
	xcmpw %t3, %t0
	jfieq @l17, @l18
@l17
	%t5 =w loadsw $glo2
	%t4 =w add %t5, 1
	storew %t4, $glo2
	R1 =w copy 0
	ret0 0001
@l18
	%t26 =l extsw %t0
	%t27 =l mul %t26, 4
	%t30 =w add %t0, 1
@l20
	%x.32 =w phi @l18 0, @l24 %t45
	%t11 =w loadsw $glo1
	xcmpw %t11, %x.32
	jfislt @l21, @l22
@l21
	R4 =w copy %t0
	R5 =w copy %x.32
	call $chk, 0021
	%t13 =w copy R1
	xcmpw 0, %t13
	jfieq @l23, @l24
@l23
	%t21 =l load $glo3
	%t23 =l extsw %x.32
	%t19 =l load [%t21 + 8 * %t23]
	%t28 =w loadsw [%t19 + 1 * %t27]
	%t17 =w add %t28, 1
	storew %t17, [%t19 + 1 * %t27]
	R5 =w copy %t30
	call $go, 0011
	%t29 =w copy R1
	%t37 =l load $glo3
	%t35 =l load [%t37 + 8 * %t23]
	%t44 =w loadsw [%t27 + 1 * %t35]
	%t33 =w sub %t44, 1
	storew %t33, [%t27 + 1 * %t35]
@l24
	%t45 =w add %x.32, 1
	jmp @l20
@l22
	R1 =w copy 0
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@l26
	storew 8, $glo1
	R4 =w copy 8
	R5 =w copy 8
	call $calloc, 0021
	%t3 =l copy R1
	storel %t3, $glo3
@l27
	%i.37 =w phi @l26 0, @l28 %t20
	%t10 =w loadsw $glo1
	xcmpw %t10, %i.37
	jfislt @l28, @l29
@l28
	R4 =w copy 4
	R5 =w copy %t10
	call $calloc, 0021
	%t12 =l copy R1
	%t16 =l load $glo3
	%t18 =l extsw %i.37
	storel %t12, [%t16 + 8 * %t18]
	%t20 =w add %i.37, 1
	jmp @l27
@l29
	R5 =w copy 0
	call $go, 0011
	%t22 =w copy R1
	%t25 =w loadsw $glo2
	xcmpw 92, %t25
	%t24 =w flagine
	R1 =w copy %t24
	ret0 0001
}

