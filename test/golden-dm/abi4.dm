**** Function alpha ****
> After slot promotion:
function $alpha() {
@ini
	%p =l par
	%l =w par
	%n =l par
	%pe =l add %p, %n
@lop
	%p1 =l phi @ini %p, @lop %p2
	%l1 =w phi @ini %l, @lop %l2
	storeb %l1, %p1
	%p2 =l add %p1, 1
	%l2 =w add %l1, 1
	%c1 =w ceql %p1, %pe
	jnz %c1, @end, @lop
@end
	storeb 0, %pe
	ret0
}

> After load elimination:
function $alpha() {
@ini
	%p =l par
	%l =w par
	%n =l par
	%pe =l add %p, %n
@lop
	%p1 =l phi @ini %p, @lop %p2
	%l1 =w phi @ini %l, @lop %l2
	storeb %l1, %p1
	%p2 =l add %p1, 1
	%l2 =w add %l1, 1
	%c1 =w ceql %p1, %pe
	jnz %c1, @end, @lop
@end
	storeb 0, %pe
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $alpha() {
@ini
	%p =l par
	%l =w par
	%n =l par
	%pe =l add %p, %n
@lop
	%p1 =l phi @ini %p, @lop %p2
	%l1 =w phi @ini %l, @lop %l2
	storeb %l1, %p1
	%p2 =l add %p1, 1
	%l2 =w add %l1, 1
	%c1 =w ceql %p1, %pe
	jnz %c1, @end, @lop
@end
	storeb 0, %pe
	ret0
}

**** Function test ****
> After slot promotion:
function $test() {
@ini
	%p =l alloc4 17
	argl %p
	argw 65
	argl 16
	%r0 =w call $alpha
	retc %p, :mem
}

> After load elimination:
function $test() {
@ini
	%p =l alloc4 17
	argl %p
	argw 65
	argl 16
	%r0 =w call $alpha
	retc %p, :mem
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@ini
	%p =l alloc4 17
	argl %p
	argw 65
	argl 16
	%r0 =w call $alpha
	retc %p, :mem
}

