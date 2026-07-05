**** Function f ****
> After slot promotion:
function $f() {
@start
	%n =w par
	%p =l par
	%r =w copy 0
@loop
	%n =w sub %n, 1
	%c =w csgew %n, 0
	jnz %c, @loop1, @end
@loop1
	%r =w loadsw %p
	jmp @loop
@end
	retw %r
}

> After load elimination:
function $f() {
@start
	%n.1 =w par
	%p =l par
	%r.2 =w copy 0
@loop
	%r.3 =w phi @start %r.2, @loop1 %r.6
	%n.4 =w phi @start %n.1, @loop1 %n.5
	%n.5 =w sub %n.4, 1
	%c =w csgew %n.5, 0
	jnz %c, @loop1, @end
@loop1
	%r.6 =w loadsw %p
	jmp @loop
@end
	retw %r.3
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%n.1 =w par
	%p =l par
	%r.2 =w copy 0
@loop
	%r.3 =w phi @start %r.2, @loop1 %r.6
	%n.4 =w phi @start %n.1, @loop1 %n.5
	%n.5 =w sub %n.4, 1
	%c =w csgew %n.5, 0
	jnz %c, @loop1, @end
@loop1
	%r.6 =w loadsw %p
	jmp @loop
@end
	retw %r.3
}

