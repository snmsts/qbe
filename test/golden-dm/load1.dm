**** Function f ****
> After slot promotion:
function $f() {
@start
	%cond =w par
	%x =l alloc4 4
	%y =l alloc4 4
	storew 0, %x
	jnz %cond, @true, @false
@true
	jmp @end
@false
@end
	%ptr =l phi @true %x, @false %y
	storew 1, %ptr
	%result =w loadsw %x
	retw %result
}

> After load elimination:
function $f() {
@start
	%cond =w par
	%x =l alloc4 4
	%y =l alloc4 4
	storew 0, %x
	jnz %cond, @true, @false
@true
	jmp @end
@false
@end
	%ptr =l phi @true %x, @false %y
	storew 1, %ptr
	%result =w loadsw %x
	retw %result
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%cond =w par
	%x =l alloc4 4
	%y =l alloc4 4
	storew 0, %x
	jnz %cond, @true, @false
@true
	jmp @end
@false
@end
	%ptr =l phi @true %x, @false %y
	storew 1, %ptr
	%result =w loadsw %x
	retw %result
}

