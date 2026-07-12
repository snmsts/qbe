**** Function chk ****
> After instruction selection:
function $chk() {
@l0
	%t1 =w copy R2
	%t0 =w copy R1
	%t17 =l extsw %t0
	%isel.32 =l copy 8
	%t18 =l mul %t17, %isel.32
	%t34 =l extsw %t1
	%isel.31 =l copy 4
	%t35 =l mul %t34, %isel.31
@l1
	%r.3 =w phi @l0 0, @l14 %r.10
	%i.4 =w phi @l0 0, @l14 %t152
	%isel.33 =l copy $glo1
	%t7 =w loadsw %isel.33
	acmpw %i.4, %t7
	jfislt @l2, @l3
@l2
	%isel.38 =l copy $glo3
	%t15 =l load %isel.38
	%t14 =l add %t15, %t18
	%t13 =l load %t14
	%t20 =l extsw %i.4
	%isel.37 =l copy 4
	%t21 =l mul %t20, %isel.37
	%t12 =l add %t13, %t21
	%t11 =w loadsw %t12
	%t9 =w add %t11, %r.3
	%isel.36 =l copy 8
	%t32 =l mul %t20, %isel.36
	%t28 =l add %t15, %t32
	%t27 =l load %t28
	%t26 =l add %t27, %t35
	%t25 =w loadsw %t26
	%t23 =w add %t9, %t25
	%t38 =w add %t0, %i.4
	acmpw %t38, %t7
	%t37 =w flagislt
	%t43 =w add %t1, %i.4
	acmpw %t43, %t7
	%t42 =w flagislt
	%t36 =w and %t37, %t42
	%t58 =l extsw %t38
	%isel.35 =l copy 8
	%t59 =l mul %t58, %isel.35
	%t53 =l add %t15, %t59
	%t63 =l extsw %t43
	%isel.34 =l copy 4
	%t64 =l mul %t63, %isel.34
	acmpw %t36, 0
	jfine @l4, @l5
@l4
	%snk.23 =l add %t15, %t59
	%t52 =l load %snk.23
	%t51 =l add %t52, %t64
	%t50 =w loadsw %t51
	%t48 =w add %t23, %t50
	%isel.39 =l copy 8
	%snk.24 =l mul %t58, %isel.39
@l5
	%r.7 =w phi @l2 %t23, @l4 %t48
	%t73 =w sub %t1, %i.4
	acmpw %t73, 0
	%t71 =w flagisge
	%t65 =w and %t37, %t71
	%t92 =l extsw %t73
	%isel.40 =l copy 4
	%t93 =l mul %t92, %isel.40
	acmpw %t65, 0
	jfine @l7, @l8
@l7
	%snk.25 =l add %t15, %t59
	%t81 =l load %snk.25
	%t80 =l add %t81, %t93
	%t79 =w loadsw %t80
	%t77 =w add %t79, %r.7
	%isel.41 =l copy 8
	%snk.26 =l mul %t58, %isel.41
@l8
	%r.8 =w phi @l5 %r.7, @l7 %t77
	%t97 =w sub %t0, %i.4
	acmpw %t97, 0
	%t95 =w flagisge
	%t94 =w and %t42, %t95
	%t116 =l extsw %t97
	%isel.42 =l copy 8
	%t117 =l mul %t116, %isel.42
	%t111 =l add %t15, %t117
	acmpw %t94, 0
	jfine @l10, @l11
@l10
	%snk.27 =l add %t15, %t117
	%t110 =l load %snk.27
	%t109 =l add %t64, %t110
	%t108 =w loadsw %t109
	%t106 =w add %t108, %r.8
	%isel.43 =l copy 8
	%snk.28 =l mul %t116, %isel.43
@l11
	%r.9 =w phi @l8 %r.8, @l10 %t106
	%t123 =w and %t71, %t95
	acmpw %t123, 0
	jfine @l13, @l14
@l13
	%snk.29 =l add %t15, %t117
	%t139 =l load %snk.29
	%t138 =l add %t93, %t139
	%t137 =w loadsw %t138
	%t135 =w add %t137, %r.9
	%isel.44 =l copy 8
	%snk.30 =l mul %t116, %isel.44
@l14
	%r.10 =w phi @l11 %r.9, @l13 %t135
	%isel.45 =w copy 1
	%t152 =w add %i.4, %isel.45
	jmp @l1
@l3
	R1 =w copy %r.3
	ret0 0001
}

**** Function go ****
> After instruction selection:
function $go() {
@l16
	%t0 =w copy R1
	%isel.51 =l copy $glo1
	%t3 =w loadsw %isel.51
	acmpw %t0, %t3
	jfieq @l17, @l18
@l17
	%isel.55 =l copy $glo2
	%t5 =w loadsw %isel.55
	%isel.54 =w copy 1
	%t4 =w add %t5, %isel.54
	%isel.53 =l copy $glo2
	storew %t4, %isel.53
	%isel.52 =w copy 0
	R1 =w copy %isel.52
	ret0 0001
@l18
	%t26 =l extsw %t0
	%isel.57 =l copy 4
	%t27 =l mul %t26, %isel.57
	%isel.56 =w copy 1
	%t30 =w add %t0, %isel.56
@l20
	%x.47 =w phi @l18 0, @l24 %t45
	%isel.58 =l copy $glo1
	%t11 =w loadsw %isel.58
	acmpw %x.47, %t11
	jfislt @l21, @l22
@l21
	R2 =w copy %t0
	R1 =w copy %x.47
	call $chk, 0041
	%t13 =w copy R1
	acmpw %t13, 0
	jfieq @l23, @l24
@l23
	%isel.63 =l copy $glo3
	%t21 =l load %isel.63
	%t23 =l extsw %x.47
	%isel.62 =l copy 8
	%t24 =l mul %t23, %isel.62
	%t20 =l add %t21, %t24
	%t19 =l load %t20
	%t18 =l add %t19, %t27
	%t28 =w loadsw %t18
	%isel.61 =w copy 1
	%t17 =w add %t28, %isel.61
	storew %t17, %t18
	R1 =w copy %t30
	call $go, 0021
	%t29 =w copy R1
	%isel.60 =l copy $glo3
	%t37 =l load %isel.60
	%t36 =l add %t24, %t37
	%t35 =l load %t36
	%t34 =l add %t27, %t35
	%t44 =w loadsw %t34
	%isel.59 =w copy 1
	%t33 =w sub %t44, %isel.59
	storew %t33, %t34
@l24
	%isel.64 =w copy 1
	%t45 =w add %x.47, %isel.64
	jmp @l20
@l22
	%isel.65 =w copy 0
	R1 =w copy %isel.65
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@l26
	%isel.74 =l copy $glo1
	%isel.73 =w copy 8
	storew %isel.73, %isel.74
	%isel.72 =w copy 8
	R2 =w copy %isel.72
	%isel.71 =w copy 8
	R1 =w copy %isel.71
	call $calloc, 0041
	%t3 =l copy R1
	%isel.70 =l copy $glo3
	storel %t3, %isel.70
@l27
	%i.67 =w phi @l26 0, @l28 %t20
	%isel.75 =l copy $glo1
	%t10 =w loadsw %isel.75
	acmpw %i.67, %t10
	jfislt @l28, @l29
@l28
	%isel.79 =w copy 4
	R2 =w copy %isel.79
	R1 =w copy %t10
	call $calloc, 0041
	%t12 =l copy R1
	%isel.78 =l copy $glo3
	%t16 =l load %isel.78
	%t18 =l extsw %i.67
	%isel.77 =l copy 8
	%t19 =l mul %t18, %isel.77
	%t15 =l add %t16, %t19
	storel %t12, %t15
	%isel.76 =w copy 1
	%t20 =w add %i.67, %isel.76
	jmp @l27
@l29
	%isel.81 =w copy 0
	R1 =w copy %isel.81
	call $go, 0021
	%t22 =w copy R1
	%isel.80 =l copy $glo2
	%t25 =w loadsw %isel.80
	acmpw %t25, 92
	%t24 =w flagine
	R1 =w copy %t24
	ret0 0001
}

