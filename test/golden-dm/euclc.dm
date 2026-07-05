**** Function test ****
> After slot promotion:
function $test() {
@l0
	nop
	nop
	nop
	%a =w copy 747
	%b =w copy 380
@l1
	%t4 =w copy %b
	jnz %t4, @l2, @l3
@l2
	%t7 =w copy %a
	%t8 =w copy %b
	%t6 =w rem %t7, %t8
	%r =w copy %t6
	%t10 =w copy %b
	%a =w copy %t10
	%t12 =w copy %r
	%b =w copy %t12
	jmp @l1
@l3
	%t13 =w copy %a
	retw %t13
}

> After load elimination:
function $test() {
@l0
	nop
	nop
	nop
	%a.1 =w copy 747
	%b.2 =w copy 380
@l1
	%b.3 =w phi @l0 %b.2, @l2 %b.6
	%a.4 =w phi @l0 %a.1, @l2 %a.5
	%t4 =w copy %b.3
	jnz %t4, @l2, @l3
@l2
	%t7 =w copy %a.4
	%t8 =w copy %b.3
	%t6 =w rem %t7, %t8
	%r =w copy %t6
	%t10 =w copy %b.3
	%a.5 =w copy %t10
	%t12 =w copy %r
	%b.6 =w copy %t12
	jmp @l1
@l3
	%t13 =w copy %a.4
	retw %t13
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@l0
	nop
	nop
	nop
	%a.1 =w copy 747
	%b.2 =w copy 380
@l1
	%b.3 =w phi @l0 %b.2, @l2 %b.6
	%a.4 =w phi @l0 %a.1, @l2 %a.5
	%t4 =w copy %b.3
	jnz %t4, @l2, @l3
@l2
	%t7 =w copy %a.4
	%t8 =w copy %b.3
	%t6 =w rem %t7, %t8
	%r =w copy %t6
	%t10 =w copy %b.3
	%a.5 =w copy %t10
	%t12 =w copy %r
	%b.6 =w copy %t12
	jmp @l1
@l3
	%t13 =w copy %a.4
	retw %t13
}

