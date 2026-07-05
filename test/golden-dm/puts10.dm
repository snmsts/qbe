**** Function main ****
> After slot promotion:
function $main() {
@start
	%y =l alloc4 4
	%y1 =l add %y, 1
	storeb 0, %y1
@loop
	%n =w phi @start 0, @loop %n1
	%c =w add %n, 48
	storeb %c, %y
	argl %y
	%r =w call $puts
	%n1 =w add %n, 1
	%cmp =w cslew %n1, 9
	jnz %cmp, @loop, @end
@end
	ret0
}

> After load elimination:
function $main() {
@start
	%y =l alloc4 4
	%y1 =l add %y, 1
	storeb 0, %y1
@loop
	%n =w phi @start 0, @loop %n1
	%c =w add %n, 48
	storeb %c, %y
	argl %y
	%r =w call $puts
	%n1 =w add %n, 1
	%cmp =w cslew %n1, 9
	jnz %cmp, @loop, @end
@end
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start
	%y =l alloc4 4
	%y1 =l add %y, 1
	storeb 0, %y1
@loop
	%n =w phi @start 0, @loop %n1
	%c =w add %n, 48
	storeb %c, %y
	argl %y
	%r =w call $puts
	%n1 =w add %n, 1
	%cmp =w cslew %n1, 9
	jnz %cmp, @loop, @end
@end
	ret0
}

