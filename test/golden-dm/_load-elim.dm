**** Function f ****
> After slot promotion:
function $f() {
@start
	%p =l par
	%c =w par
	jnz %c, @true, @false
@true
	%p1 =l add %p, 4
	%v1 =w loaduw %p1
	jmp @end
@false
	%p2 =l add %p, 4
	%v2 =w loaduw %p2
@end
	retw 0
}

> After load elimination:
function $f() {
@start
	%p =l par
	%c =w par
	jnz %c, @true, @false
@true
	%p1 =l add %p, 4
	%v1 =w loaduw %p1
	jmp @end
@false
	%p2 =l add %p, 4
	%v2 =w loaduw %p2
@end
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%p =l par
	%c =w par
	jnz %c, @true, @false
@true
	%p1 =l add %p, 4
	%v1 =w loaduw %p1
	jmp @end
@false
	%p2 =l add %p, 4
	%v2 =w loaduw %p2
@end
	retw 0
}

