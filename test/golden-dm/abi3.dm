**** Function test ****
> After slot promotion:
function $test() {
@start
	%a =w loadsw $z
	%y =w add %a, %a
	%yl =l extsw %y
	%s =l alloc8 16
	%s1 =l add %s, 12
	storel 4, %s
	storew 5, %s1
	%f =l add $F, %yl
	argw %y
	argw 1
	argw 2
	argw 3
	argc :four, %s
	argw 6
	%x =w call %f
	%x1 =w add %y, %x
	storew %x1, $a
	ret0
}

> After load elimination:
function $test() {
@start
	%a =w loadsw $z
	%y =w add %a, %a
	%yl =l extsw %y
	%s =l alloc8 16
	%s1 =l add %s, 12
	storel 4, %s
	storew 5, %s1
	%f =l add $F, %yl
	argw %y
	argw 1
	argw 2
	argw 3
	argc :four, %s
	argw 6
	%x =w call %f
	%x1 =w add %y, %x
	storew %x1, $a
	ret0
}

> Slot coalescing:
	fuse ( 16b) [ %s[2,4) ]
	sums 0/0/16 (killed/fused/total)

function $test() {
@start
	%a =w loadsw $z
	%y =w add %a, %a
	%yl =l extsw %y
	%s =l alloc8 16
	%s1 =l add %s, 12
	storel 4, %s
	storew 5, %s1
	%f =l add $F, %yl
	argw %y
	argw 1
	argw 2
	argw 3
	argc :four, %s
	argw 6
	%x =w call %f
	%x1 =w add %y, %x
	storew %x1, $a
	ret0
}

