**** Function chk ****
> After instruction selection:
function $chk() {
@l0
	%t1 =w copy R8
	%t0 =w copy R7
	%t17 =l extsw %t0
	%isel.34 =l copy 8
	%t18 =l mul %t17, %isel.34
	%t34 =l extsw %t1
	%isel.33 =l copy 4
	%t35 =l mul %t34, %isel.33
	%isel.32 =w copy 0
	%isel.31 =w copy 0
@l1
	%r.3 =w phi @l0 %isel.31, @l14 %r.10
	%i.4 =w phi @l0 %isel.32, @l14 %t152
	%t7 =w loadsw $glo1
	%t5 =w csltl %i.4, %t7
	jnz %t5, @l2, @l3
@l2
	%t15 =l load $glo3
	%t14 =l add %t15, %t18
	%t13 =l load %t14
	%t20 =l extsw %i.4
	%isel.38 =l copy 4
	%t21 =l mul %t20, %isel.38
	%t12 =l add %t13, %t21
	%t11 =w loadsw %t12
	%t9 =w add %t11, %r.3
	%isel.37 =l copy 8
	%t32 =l mul %t20, %isel.37
	%t28 =l add %t15, %t32
	%t27 =l load %t28
	%t26 =l add %t27, %t35
	%t25 =w loadsw %t26
	%t23 =w add %t9, %t25
	%t38 =w add %t0, %i.4
	%t37 =w csltl %t38, %t7
	%t43 =w add %t1, %i.4
	%t42 =w csltl %t43, %t7
	%t36 =w and %t37, %t42
	%t58 =l extsw %t38
	%isel.36 =l copy 8
	%t59 =l mul %t58, %isel.36
	%t53 =l add %t15, %t59
	%t63 =l extsw %t43
	%isel.35 =l copy 4
	%t64 =l mul %t63, %isel.35
	jnz %t36, @l4, @l5
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
	%isel.41 =w csltl %t73, 0
	%t71 =w xor %isel.41, 1
	%t65 =w and %t37, %t71
	%t92 =l extsw %t73
	%isel.40 =l copy 4
	%t93 =l mul %t92, %isel.40
	jnz %t65, @l7, @l8
@l7
	%snk.25 =l add %t15, %t59
	%t81 =l load %snk.25
	%t80 =l add %t81, %t93
	%t79 =w loadsw %t80
	%t77 =w add %t79, %r.7
	%isel.42 =l copy 8
	%snk.26 =l mul %t58, %isel.42
@l8
	%r.8 =w phi @l5 %r.7, @l7 %t77
	%t97 =w sub %t0, %i.4
	%isel.44 =w csltl %t97, 0
	%t95 =w xor %isel.44, 1
	%t94 =w and %t42, %t95
	%t116 =l extsw %t97
	%isel.43 =l copy 8
	%t117 =l mul %t116, %isel.43
	%t111 =l add %t15, %t117
	jnz %t94, @l10, @l11
@l10
	%snk.27 =l add %t15, %t117
	%t110 =l load %snk.27
	%t109 =l add %t64, %t110
	%t108 =w loadsw %t109
	%t106 =w add %t108, %r.8
	%isel.45 =l copy 8
	%snk.28 =l mul %t116, %isel.45
@l11
	%r.9 =w phi @l8 %r.8, @l10 %t106
	%t123 =w and %t71, %t95
	jnz %t123, @l13, @l14
@l13
	%snk.29 =l add %t15, %t117
	%t139 =l load %snk.29
	%t138 =l add %t93, %t139
	%t137 =w loadsw %t138
	%t135 =w add %t137, %r.9
	%isel.46 =l copy 8
	%snk.30 =l mul %t116, %isel.46
@l14
	%r.10 =w phi @l11 %r.9, @l13 %t135
	%t152 =w add %i.4, 1
	jmp @l1
@l3
	R7 =w copy %r.3
	ret0 0001
}

**** Function go ****
> After instruction selection:
function $go() {
@l16
	%t0 =w copy R7
	%t3 =w loadsw $glo1
	%isel.52 =w xor %t0, %t3
	%t1 =w reqz %isel.52
	jnz %t1, @l17, @l18
@l17
	%t5 =w loadsw $glo2
	%t4 =w add %t5, 1
	storew %t4, $glo2
	%isel.53 =w copy 0
	R7 =w copy %isel.53
	ret0 0001
@l18
	%t26 =l extsw %t0
	%isel.55 =l copy 4
	%t27 =l mul %t26, %isel.55
	%t30 =w add %t0, 1
	%isel.54 =w copy 0
@l20
	%x.48 =w phi @l18 %isel.54, @l24 %t45
	%t11 =w loadsw $glo1
	%t9 =w csltl %x.48, %t11
	jnz %t9, @l21, @l22
@l21
	R8 =w copy %t0
	R7 =w copy %x.48
	call $chk, 0021
	%t13 =w copy R7
	%isel.56 =w xor %t13, 0
	%t12 =w reqz %isel.56
	jnz %t12, @l23, @l24
@l23
	%t21 =l load $glo3
	%t23 =l extsw %x.48
	%isel.58 =l copy 8
	%t24 =l mul %t23, %isel.58
	%t20 =l add %t21, %t24
	%t19 =l load %t20
	%t18 =l add %t19, %t27
	%t28 =w loadsw %t18
	%t17 =w add %t28, 1
	storew %t17, %t18
	R7 =w copy %t30
	call $go, 0011
	%t29 =w copy R7
	%t37 =l load $glo3
	%t36 =l add %t24, %t37
	%t35 =l load %t36
	%t34 =l add %t27, %t35
	%t44 =w loadsw %t34
	%isel.57 =w copy 1
	%t33 =w sub %t44, %isel.57
	storew %t33, %t34
@l24
	%t45 =w add %x.48, 1
	jmp @l20
@l22
	%isel.59 =w copy 0
	R7 =w copy %isel.59
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@l26
	%isel.67 =w copy 8
	storew %isel.67, $glo1
	%isel.66 =w copy 8
	R8 =w copy %isel.66
	%isel.65 =w copy 8
	R7 =w copy %isel.65
	call $calloc, 0021
	%t3 =l copy R7
	storel %t3, $glo3
	%isel.64 =w copy 0
@l27
	%i.61 =w phi @l26 %isel.64, @l28 %t20
	%t10 =w loadsw $glo1
	%t8 =w csltl %i.61, %t10
	jnz %t8, @l28, @l29
@l28
	%isel.69 =w copy 4
	R8 =w copy %isel.69
	R7 =w copy %t10
	call $calloc, 0021
	%t12 =l copy R7
	%t16 =l load $glo3
	%t18 =l extsw %i.61
	%isel.68 =l copy 8
	%t19 =l mul %t18, %isel.68
	%t15 =l add %t16, %t19
	storel %t12, %t15
	%t20 =w add %i.61, 1
	jmp @l27
@l29
	%isel.71 =w copy 0
	R7 =w copy %isel.71
	call $go, 0011
	%t22 =w copy R7
	%t25 =w loadsw $glo2
	%isel.70 =w xor %t25, 92
	%t24 =w rnez %isel.70
	R7 =w copy %t24
	ret0 0001
}

