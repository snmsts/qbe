**** Function chk ****
> After slot promotion:
function $chk() {
@l0
	%t0 =w par
	%t1 =w par
	nop
	%x =w copy %t0
	nop
	%y =w copy %t1
	nop
	nop
	%i =w copy 0
	%r =w copy 0
@l1
	%t6 =w copy %i
	%t7 =w loadsw $glo1
	%t5 =w csltw %t6, %t7
	jnz %t5, @l2, @l3
@l2
	%t10 =w copy %r
	%t15 =l load $glo3
	%t16 =w copy %x
	%t17 =l extsw %t16
	%t18 =l mul 8, %t17
	%t14 =l add %t15, %t18
	%t13 =l load %t14
	%t19 =w copy %i
	%t20 =l extsw %t19
	%t21 =l mul 4, %t20
	%t12 =l add %t13, %t21
	%t11 =w loadsw %t12
	%t9 =w add %t10, %t11
	%r =w copy %t9
	%t24 =w copy %r
	%t29 =l load $glo3
	%t30 =w copy %i
	%t31 =l extsw %t30
	%t32 =l mul 8, %t31
	%t28 =l add %t29, %t32
	%t27 =l load %t28
	%t33 =w copy %y
	%t34 =l extsw %t33
	%t35 =l mul 4, %t34
	%t26 =l add %t27, %t35
	%t25 =w loadsw %t26
	%t23 =w add %t24, %t25
	%r =w copy %t23
	%t39 =w copy %x
	%t40 =w copy %i
	%t38 =w add %t39, %t40
	%t41 =w loadsw $glo1
	%t37 =w csltw %t38, %t41
	%t44 =w copy %y
	%t45 =w copy %i
	%t43 =w add %t44, %t45
	%t46 =w loadsw $glo1
	%t42 =w csltw %t43, %t46
	%t36 =w and %t37, %t42
	jnz %t36, @l4, @l5
@l4
	%t49 =w copy %r
	%t54 =l load $glo3
	%t56 =w copy %x
	%t57 =w copy %i
	%t55 =w add %t56, %t57
	%t58 =l extsw %t55
	%t59 =l mul 8, %t58
	%t53 =l add %t54, %t59
	%t52 =l load %t53
	%t61 =w copy %y
	%t62 =w copy %i
	%t60 =w add %t61, %t62
	%t63 =l extsw %t60
	%t64 =l mul 4, %t63
	%t51 =l add %t52, %t64
	%t50 =w loadsw %t51
	%t48 =w add %t49, %t50
	%r =w copy %t48
@l5
	%t68 =w copy %x
	%t69 =w copy %i
	%t67 =w add %t68, %t69
	%t70 =w loadsw $glo1
	%t66 =w csltw %t67, %t70
	%t74 =w copy %y
	%t75 =w copy %i
	%t73 =w sub %t74, %t75
	%t71 =w cslew 0, %t73
	%t65 =w and %t66, %t71
	jnz %t65, @l7, @l8
@l7
	%t78 =w copy %r
	%t83 =l load $glo3
	%t85 =w copy %x
	%t86 =w copy %i
	%t84 =w add %t85, %t86
	%t87 =l extsw %t84
	%t88 =l mul 8, %t87
	%t82 =l add %t83, %t88
	%t81 =l load %t82
	%t90 =w copy %y
	%t91 =w copy %i
	%t89 =w sub %t90, %t91
	%t92 =l extsw %t89
	%t93 =l mul 4, %t92
	%t80 =l add %t81, %t93
	%t79 =w loadsw %t80
	%t77 =w add %t78, %t79
	%r =w copy %t77
@l8
	%t98 =w copy %x
	%t99 =w copy %i
	%t97 =w sub %t98, %t99
	%t95 =w cslew 0, %t97
	%t102 =w copy %y
	%t103 =w copy %i
	%t101 =w add %t102, %t103
	%t104 =w loadsw $glo1
	%t100 =w csltw %t101, %t104
	%t94 =w and %t95, %t100
	jnz %t94, @l10, @l11
@l10
	%t107 =w copy %r
	%t112 =l load $glo3
	%t114 =w copy %x
	%t115 =w copy %i
	%t113 =w sub %t114, %t115
	%t116 =l extsw %t113
	%t117 =l mul 8, %t116
	%t111 =l add %t112, %t117
	%t110 =l load %t111
	%t119 =w copy %y
	%t120 =w copy %i
	%t118 =w add %t119, %t120
	%t121 =l extsw %t118
	%t122 =l mul 4, %t121
	%t109 =l add %t110, %t122
	%t108 =w loadsw %t109
	%t106 =w add %t107, %t108
	%r =w copy %t106
@l11
	%t127 =w copy %x
	%t128 =w copy %i
	%t126 =w sub %t127, %t128
	%t124 =w cslew 0, %t126
	%t132 =w copy %y
	%t133 =w copy %i
	%t131 =w sub %t132, %t133
	%t129 =w cslew 0, %t131
	%t123 =w and %t124, %t129
	jnz %t123, @l13, @l14
@l13
	%t136 =w copy %r
	%t141 =l load $glo3
	%t143 =w copy %x
	%t144 =w copy %i
	%t142 =w sub %t143, %t144
	%t145 =l extsw %t142
	%t146 =l mul 8, %t145
	%t140 =l add %t141, %t146
	%t139 =l load %t140
	%t148 =w copy %y
	%t149 =w copy %i
	%t147 =w sub %t148, %t149
	%t150 =l extsw %t147
	%t151 =l mul 4, %t150
	%t138 =l add %t139, %t151
	%t137 =w loadsw %t138
	%t135 =w add %t136, %t137
	%r =w copy %t135
@l14
	%t153 =w copy %i
	%t152 =w add %t153, 1
	%i =w copy %t152
	jmp @l1
@l3
	%t154 =w copy %r
	retw %t154
}

> After load elimination:
function $chk() {
@l0
	%t0 =w par
	%t1 =w par
	nop
	%x =w copy %t0
	nop
	%y =w copy %t1
	nop
	nop
	%i.1 =w copy 0
	%r.2 =w copy 0
@l1
	%r.3 =w phi @l0 %r.2, @l14 %r.10
	%i.4 =w phi @l0 %i.1, @l14 %i.11
	%t6 =w copy %i.4
	%t7 =w loadsw $glo1
	%t5 =w csltw %t6, %t7
	jnz %t5, @l2, @l3
@l2
	%t10 =w copy %r.3
	%t15 =l load $glo3
	%t16 =w copy %x
	%t17 =l extsw %t16
	%t18 =l mul 8, %t17
	%t14 =l add %t15, %t18
	%t13 =l load %t14
	%t19 =w copy %i.4
	%t20 =l extsw %t19
	%t21 =l mul 4, %t20
	%t12 =l add %t13, %t21
	%t11 =w loadsw %t12
	%t9 =w add %t10, %t11
	%r.5 =w copy %t9
	%t24 =w copy %r.5
	%t29 =l copy %t15
	%t30 =w copy %i.4
	%t31 =l extsw %t30
	%t32 =l mul 8, %t31
	%t28 =l add %t29, %t32
	%t27 =l load %t28
	%t33 =w copy %y
	%t34 =l extsw %t33
	%t35 =l mul 4, %t34
	%t26 =l add %t27, %t35
	%t25 =w loadsw %t26
	%t23 =w add %t24, %t25
	%r.6 =w copy %t23
	%t39 =w copy %x
	%t40 =w copy %i.4
	%t38 =w add %t39, %t40
	%t41 =w copy %t7
	%t37 =w csltw %t38, %t41
	%t44 =w copy %y
	%t45 =w copy %i.4
	%t43 =w add %t44, %t45
	%t46 =w copy %t41
	%t42 =w csltw %t43, %t46
	%t36 =w and %t37, %t42
	jnz %t36, @l4, @l5
@l4
	%t49 =w copy %r.6
	%t54 =l copy %t29
	%t56 =w copy %x
	%t57 =w copy %i.4
	%t55 =w add %t56, %t57
	%t58 =l extsw %t55
	%t59 =l mul 8, %t58
	%t53 =l add %t54, %t59
	%t52 =l load %t53
	%t61 =w copy %y
	%t62 =w copy %i.4
	%t60 =w add %t61, %t62
	%t63 =l extsw %t60
	%t64 =l mul 4, %t63
	%t51 =l add %t52, %t64
	%t50 =w loadsw %t51
	%t48 =w add %t49, %t50
	%r.15 =w copy %t48
@l5
	%ld.19 =l phi @l2 %t29, @l4 %t54
	%ld.18 =w phi @l2 %t46, @l4 %t46
	%r.7 =w phi @l2 %r.6, @l4 %r.15
	%t68 =w copy %x
	%t69 =w copy %i.4
	%t67 =w add %t68, %t69
	%t70 =w copy %ld.18
	%t66 =w csltw %t67, %t70
	%t74 =w copy %y
	%t75 =w copy %i.4
	%t73 =w sub %t74, %t75
	%t71 =w cslew 0, %t73
	%t65 =w and %t66, %t71
	jnz %t65, @l7, @l8
@l7
	%t78 =w copy %r.7
	%t83 =l copy %ld.19
	%t85 =w copy %x
	%t86 =w copy %i.4
	%t84 =w add %t85, %t86
	%t87 =l extsw %t84
	%t88 =l mul 8, %t87
	%t82 =l add %t83, %t88
	%t81 =l load %t82
	%t90 =w copy %y
	%t91 =w copy %i.4
	%t89 =w sub %t90, %t91
	%t92 =l extsw %t89
	%t93 =l mul 4, %t92
	%t80 =l add %t81, %t93
	%t79 =w loadsw %t80
	%t77 =w add %t78, %t79
	%r.14 =w copy %t77
@l8
	%ld.21 =l phi @l5 %ld.19, @l7 %t83
	%ld.20 =w phi @l5 %t70, @l7 %t70
	%r.8 =w phi @l5 %r.7, @l7 %r.14
	%t98 =w copy %x
	%t99 =w copy %i.4
	%t97 =w sub %t98, %t99
	%t95 =w cslew 0, %t97
	%t102 =w copy %y
	%t103 =w copy %i.4
	%t101 =w add %t102, %t103
	%t104 =w copy %ld.20
	%t100 =w csltw %t101, %t104
	%t94 =w and %t95, %t100
	jnz %t94, @l10, @l11
@l10
	%t107 =w copy %r.8
	%t112 =l copy %ld.21
	%t114 =w copy %x
	%t115 =w copy %i.4
	%t113 =w sub %t114, %t115
	%t116 =l extsw %t113
	%t117 =l mul 8, %t116
	%t111 =l add %t112, %t117
	%t110 =l load %t111
	%t119 =w copy %y
	%t120 =w copy %i.4
	%t118 =w add %t119, %t120
	%t121 =l extsw %t118
	%t122 =l mul 4, %t121
	%t109 =l add %t110, %t122
	%t108 =w loadsw %t109
	%t106 =w add %t107, %t108
	%r.13 =w copy %t106
@l11
	%ld.22 =l phi @l8 %ld.21, @l10 %t112
	%r.9 =w phi @l8 %r.8, @l10 %r.13
	%t127 =w copy %x
	%t128 =w copy %i.4
	%t126 =w sub %t127, %t128
	%t124 =w cslew 0, %t126
	%t132 =w copy %y
	%t133 =w copy %i.4
	%t131 =w sub %t132, %t133
	%t129 =w cslew 0, %t131
	%t123 =w and %t124, %t129
	jnz %t123, @l13, @l14
@l13
	%t136 =w copy %r.9
	%t141 =l copy %ld.22
	%t143 =w copy %x
	%t144 =w copy %i.4
	%t142 =w sub %t143, %t144
	%t145 =l extsw %t142
	%t146 =l mul 8, %t145
	%t140 =l add %t141, %t146
	%t139 =l load %t140
	%t148 =w copy %y
	%t149 =w copy %i.4
	%t147 =w sub %t148, %t149
	%t150 =l extsw %t147
	%t151 =l mul 4, %t150
	%t138 =l add %t139, %t151
	%t137 =w loadsw %t138
	%t135 =w add %t136, %t137
	%r.12 =w copy %t135
@l14
	%r.10 =w phi @l11 %r.9, @l13 %r.12
	%t153 =w copy %i.4
	%t152 =w add %t153, 1
	%i.11 =w copy %t152
	jmp @l1
@l3
	%t154 =w copy %r.3
	retw %t154
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $chk() {
@l0
	%t0 =w par
	%t1 =w par
	nop
	%x =w copy %t0
	nop
	%y =w copy %t1
	nop
	nop
	%i.1 =w copy 0
	%r.2 =w copy 0
@l1
	%r.3 =w phi @l0 %r.2, @l14 %r.10
	%i.4 =w phi @l0 %i.1, @l14 %i.11
	%t6 =w copy %i.4
	%t7 =w loadsw $glo1
	%t5 =w csltw %t6, %t7
	jnz %t5, @l2, @l3
@l2
	%t10 =w copy %r.3
	%t15 =l load $glo3
	%t16 =w copy %x
	%t17 =l extsw %t16
	%t18 =l mul 8, %t17
	%t14 =l add %t15, %t18
	%t13 =l load %t14
	%t19 =w copy %i.4
	%t20 =l extsw %t19
	%t21 =l mul 4, %t20
	%t12 =l add %t13, %t21
	%t11 =w loadsw %t12
	%t9 =w add %t10, %t11
	%r.5 =w copy %t9
	%t24 =w copy %r.5
	%t29 =l copy %t15
	%t30 =w copy %i.4
	%t31 =l extsw %t30
	%t32 =l mul 8, %t31
	%t28 =l add %t29, %t32
	%t27 =l load %t28
	%t33 =w copy %y
	%t34 =l extsw %t33
	%t35 =l mul 4, %t34
	%t26 =l add %t27, %t35
	%t25 =w loadsw %t26
	%t23 =w add %t24, %t25
	%r.6 =w copy %t23
	%t39 =w copy %x
	%t40 =w copy %i.4
	%t38 =w add %t39, %t40
	%t41 =w copy %t7
	%t37 =w csltw %t38, %t41
	%t44 =w copy %y
	%t45 =w copy %i.4
	%t43 =w add %t44, %t45
	%t46 =w copy %t41
	%t42 =w csltw %t43, %t46
	%t36 =w and %t37, %t42
	jnz %t36, @l4, @l5
@l4
	%t49 =w copy %r.6
	%t54 =l copy %t29
	%t56 =w copy %x
	%t57 =w copy %i.4
	%t55 =w add %t56, %t57
	%t58 =l extsw %t55
	%t59 =l mul 8, %t58
	%t53 =l add %t54, %t59
	%t52 =l load %t53
	%t61 =w copy %y
	%t62 =w copy %i.4
	%t60 =w add %t61, %t62
	%t63 =l extsw %t60
	%t64 =l mul 4, %t63
	%t51 =l add %t52, %t64
	%t50 =w loadsw %t51
	%t48 =w add %t49, %t50
	%r.15 =w copy %t48
@l5
	%ld.19 =l phi @l2 %t29, @l4 %t54
	%ld.18 =w phi @l2 %t46, @l4 %t46
	%r.7 =w phi @l2 %r.6, @l4 %r.15
	%t68 =w copy %x
	%t69 =w copy %i.4
	%t67 =w add %t68, %t69
	%t70 =w copy %ld.18
	%t66 =w csltw %t67, %t70
	%t74 =w copy %y
	%t75 =w copy %i.4
	%t73 =w sub %t74, %t75
	%t71 =w cslew 0, %t73
	%t65 =w and %t66, %t71
	jnz %t65, @l7, @l8
@l7
	%t78 =w copy %r.7
	%t83 =l copy %ld.19
	%t85 =w copy %x
	%t86 =w copy %i.4
	%t84 =w add %t85, %t86
	%t87 =l extsw %t84
	%t88 =l mul 8, %t87
	%t82 =l add %t83, %t88
	%t81 =l load %t82
	%t90 =w copy %y
	%t91 =w copy %i.4
	%t89 =w sub %t90, %t91
	%t92 =l extsw %t89
	%t93 =l mul 4, %t92
	%t80 =l add %t81, %t93
	%t79 =w loadsw %t80
	%t77 =w add %t78, %t79
	%r.14 =w copy %t77
@l8
	%ld.21 =l phi @l5 %ld.19, @l7 %t83
	%ld.20 =w phi @l5 %t70, @l7 %t70
	%r.8 =w phi @l5 %r.7, @l7 %r.14
	%t98 =w copy %x
	%t99 =w copy %i.4
	%t97 =w sub %t98, %t99
	%t95 =w cslew 0, %t97
	%t102 =w copy %y
	%t103 =w copy %i.4
	%t101 =w add %t102, %t103
	%t104 =w copy %ld.20
	%t100 =w csltw %t101, %t104
	%t94 =w and %t95, %t100
	jnz %t94, @l10, @l11
@l10
	%t107 =w copy %r.8
	%t112 =l copy %ld.21
	%t114 =w copy %x
	%t115 =w copy %i.4
	%t113 =w sub %t114, %t115
	%t116 =l extsw %t113
	%t117 =l mul 8, %t116
	%t111 =l add %t112, %t117
	%t110 =l load %t111
	%t119 =w copy %y
	%t120 =w copy %i.4
	%t118 =w add %t119, %t120
	%t121 =l extsw %t118
	%t122 =l mul 4, %t121
	%t109 =l add %t110, %t122
	%t108 =w loadsw %t109
	%t106 =w add %t107, %t108
	%r.13 =w copy %t106
@l11
	%ld.22 =l phi @l8 %ld.21, @l10 %t112
	%r.9 =w phi @l8 %r.8, @l10 %r.13
	%t127 =w copy %x
	%t128 =w copy %i.4
	%t126 =w sub %t127, %t128
	%t124 =w cslew 0, %t126
	%t132 =w copy %y
	%t133 =w copy %i.4
	%t131 =w sub %t132, %t133
	%t129 =w cslew 0, %t131
	%t123 =w and %t124, %t129
	jnz %t123, @l13, @l14
@l13
	%t136 =w copy %r.9
	%t141 =l copy %ld.22
	%t143 =w copy %x
	%t144 =w copy %i.4
	%t142 =w sub %t143, %t144
	%t145 =l extsw %t142
	%t146 =l mul 8, %t145
	%t140 =l add %t141, %t146
	%t139 =l load %t140
	%t148 =w copy %y
	%t149 =w copy %i.4
	%t147 =w sub %t148, %t149
	%t150 =l extsw %t147
	%t151 =l mul 4, %t150
	%t138 =l add %t139, %t151
	%t137 =w loadsw %t138
	%t135 =w add %t136, %t137
	%r.12 =w copy %t135
@l14
	%r.10 =w phi @l11 %r.9, @l13 %r.12
	%t153 =w copy %i.4
	%t152 =w add %t153, 1
	%i.11 =w copy %t152
	jmp @l1
@l3
	%t154 =w copy %r.3
	retw %t154
}

**** Function go ****
> After slot promotion:
function $go() {
@l16
	%t0 =w par
	nop
	%y =w copy %t0
	nop
	%t2 =w copy %y
	%t3 =w loadsw $glo1
	%t1 =w ceqw %t2, %t3
	jnz %t1, @l17, @l18
@l17
	%t5 =w loadsw $glo2
	%t4 =w add %t5, 1
	storew %t4, $glo2
	retw 0
@l18
	%x =w copy 0
@l20
	%t10 =w copy %x
	%t11 =w loadsw $glo1
	%t9 =w csltw %t10, %t11
	jnz %t9, @l21, @l22
@l21
	%t14 =w copy %x
	%t15 =w copy %y
	argw %t14
	argw %t15
	%t13 =w call $chk
	%t12 =w ceqw %t13, 0
	jnz %t12, @l23, @l24
@l23
	%t21 =l load $glo3
	%t22 =w copy %x
	%t23 =l extsw %t22
	%t24 =l mul 8, %t23
	%t20 =l add %t21, %t24
	%t19 =l load %t20
	%t25 =w copy %y
	%t26 =l extsw %t25
	%t27 =l mul 4, %t26
	%t18 =l add %t19, %t27
	%t28 =w loadsw %t18
	%t17 =w add %t28, 1
	storew %t17, %t18
	%t31 =w copy %y
	%t30 =w add %t31, 1
	argw %t30
	%t29 =w call $go
	%t37 =l load $glo3
	%t38 =w copy %x
	%t39 =l extsw %t38
	%t40 =l mul 8, %t39
	%t36 =l add %t37, %t40
	%t35 =l load %t36
	%t41 =w copy %y
	%t42 =l extsw %t41
	%t43 =l mul 4, %t42
	%t34 =l add %t35, %t43
	%t44 =w loadsw %t34
	%t33 =w sub %t44, 1
	storew %t33, %t34
@l24
	%t46 =w copy %x
	%t45 =w add %t46, 1
	%x =w copy %t45
	jmp @l20
@l22
	retw 0
}

> After load elimination:
function $go() {
@l16
	%t0 =w par
	nop
	%y =w copy %t0
	nop
	%t2 =w copy %y
	%t3 =w loadsw $glo1
	%t1 =w ceqw %t2, %t3
	jnz %t1, @l17, @l18
@l17
	%t5 =w loadsw $glo2
	%t4 =w add %t5, 1
	storew %t4, $glo2
	retw 0
@l18
	%x.31 =w copy 0
@l20
	%x.32 =w phi @l18 %x.31, @l24 %x.33
	%t10 =w copy %x.32
	%t11 =w loadsw $glo1
	%t9 =w csltw %t10, %t11
	jnz %t9, @l21, @l22
@l21
	%t14 =w copy %x.32
	%t15 =w copy %y
	argw %t14
	argw %t15
	%t13 =w call $chk
	%t12 =w ceqw %t13, 0
	jnz %t12, @l23, @l24
@l23
	%t21 =l load $glo3
	%t22 =w copy %x.32
	%t23 =l extsw %t22
	%t24 =l mul 8, %t23
	%t20 =l add %t21, %t24
	%t19 =l load %t20
	%t25 =w copy %y
	%t26 =l extsw %t25
	%t27 =l mul 4, %t26
	%t18 =l add %t19, %t27
	%t28 =w loadsw %t18
	%t17 =w add %t28, 1
	storew %t17, %t18
	%t31 =w copy %y
	%t30 =w add %t31, 1
	argw %t30
	%t29 =w call $go
	%t37 =l load $glo3
	%t38 =w copy %x.32
	%t39 =l extsw %t38
	%t40 =l mul 8, %t39
	%t36 =l add %t37, %t40
	%t35 =l load %t36
	%t41 =w copy %y
	%t42 =l extsw %t41
	%t43 =l mul 4, %t42
	%t34 =l add %t35, %t43
	%t44 =w loadsw %t34
	%t33 =w sub %t44, 1
	storew %t33, %t34
@l24
	%t46 =w copy %x.32
	%t45 =w add %t46, 1
	%x.33 =w copy %t45
	jmp @l20
@l22
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $go() {
@l16
	%t0 =w par
	nop
	%y =w copy %t0
	nop
	%t2 =w copy %y
	%t3 =w loadsw $glo1
	%t1 =w ceqw %t2, %t3
	jnz %t1, @l17, @l18
@l17
	%t5 =w loadsw $glo2
	%t4 =w add %t5, 1
	storew %t4, $glo2
	retw 0
@l18
	%x.31 =w copy 0
@l20
	%x.32 =w phi @l18 %x.31, @l24 %x.33
	%t10 =w copy %x.32
	%t11 =w loadsw $glo1
	%t9 =w csltw %t10, %t11
	jnz %t9, @l21, @l22
@l21
	%t14 =w copy %x.32
	%t15 =w copy %y
	argw %t14
	argw %t15
	%t13 =w call $chk
	%t12 =w ceqw %t13, 0
	jnz %t12, @l23, @l24
@l23
	%t21 =l load $glo3
	%t22 =w copy %x.32
	%t23 =l extsw %t22
	%t24 =l mul 8, %t23
	%t20 =l add %t21, %t24
	%t19 =l load %t20
	%t25 =w copy %y
	%t26 =l extsw %t25
	%t27 =l mul 4, %t26
	%t18 =l add %t19, %t27
	%t28 =w loadsw %t18
	%t17 =w add %t28, 1
	storew %t17, %t18
	%t31 =w copy %y
	%t30 =w add %t31, 1
	argw %t30
	%t29 =w call $go
	%t37 =l load $glo3
	%t38 =w copy %x.32
	%t39 =l extsw %t38
	%t40 =l mul 8, %t39
	%t36 =l add %t37, %t40
	%t35 =l load %t36
	%t41 =w copy %y
	%t42 =l extsw %t41
	%t43 =l mul 4, %t42
	%t34 =l add %t35, %t43
	%t44 =w loadsw %t34
	%t33 =w sub %t44, 1
	storew %t33, %t34
@l24
	%t46 =w copy %x.32
	%t45 =w add %t46, 1
	%x.33 =w copy %t45
	jmp @l20
@l22
	retw 0
}

**** Function main ****
> After slot promotion:
function $main() {
@l26
	nop
	storew 8, $glo1
	%t4 =w loadsw $glo1
	argw %t4
	argw 8
	%t3 =l call $calloc
	storel %t3, $glo3
	%i =w copy 0
@l27
	%t9 =w copy %i
	%t10 =w loadsw $glo1
	%t8 =w csltw %t9, %t10
	jnz %t8, @l28, @l29
@l28
	%t13 =w loadsw $glo1
	argw %t13
	argw 4
	%t12 =l call $calloc
	%t16 =l load $glo3
	%t17 =w copy %i
	%t18 =l extsw %t17
	%t19 =l mul 8, %t18
	%t15 =l add %t16, %t19
	storel %t12, %t15
	%t21 =w copy %i
	%t20 =w add %t21, 1
	%i =w copy %t20
	jmp @l27
@l29
	argw 0
	%t22 =w call $go
	%t25 =w loadsw $glo2
	%t24 =w cnew %t25, 92
	retw %t24
}

> After load elimination:
function $main() {
@l26
	nop
	storew 8, $glo1
	%t4 =w copy 8
	argw %t4
	argw 8
	%t3 =l call $calloc
	storel %t3, $glo3
	%i.36 =w copy 0
@l27
	%i.37 =w phi @l26 %i.36, @l28 %i.38
	%t9 =w copy %i.37
	%t10 =w loadsw $glo1
	%t8 =w csltw %t9, %t10
	jnz %t8, @l28, @l29
@l28
	%t13 =w copy %t10
	argw %t13
	argw 4
	%t12 =l call $calloc
	%t16 =l load $glo3
	%t17 =w copy %i.37
	%t18 =l extsw %t17
	%t19 =l mul 8, %t18
	%t15 =l add %t16, %t19
	storel %t12, %t15
	%t21 =w copy %i.37
	%t20 =w add %t21, 1
	%i.38 =w copy %t20
	jmp @l27
@l29
	argw 0
	%t22 =w call $go
	%t25 =w loadsw $glo2
	%t24 =w cnew %t25, 92
	retw %t24
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@l26
	nop
	storew 8, $glo1
	%t4 =w copy 8
	argw %t4
	argw 8
	%t3 =l call $calloc
	storel %t3, $glo3
	%i.36 =w copy 0
@l27
	%i.37 =w phi @l26 %i.36, @l28 %i.38
	%t9 =w copy %i.37
	%t10 =w loadsw $glo1
	%t8 =w csltw %t9, %t10
	jnz %t8, @l28, @l29
@l28
	%t13 =w copy %t10
	argw %t13
	argw 4
	%t12 =l call $calloc
	%t16 =l load $glo3
	%t17 =w copy %i.37
	%t18 =l extsw %t17
	%t19 =l mul 8, %t18
	%t15 =l add %t16, %t19
	storel %t12, %t15
	%t21 =w copy %i.37
	%t20 =w add %t21, 1
	%i.38 =w copy %t20
	jmp @l27
@l29
	argw 0
	%t22 =w call $go
	%t25 =w loadsw $glo2
	%t24 =w cnew %t25, 92
	retw %t24
}

