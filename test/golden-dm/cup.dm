**** Function test ****
> After slot promotion:
function $test() {
@start
@loop
	%n0 =l phi @start -1988, @loop %n1
	%n1 =l add 1, %n0
	%cmp =w cslel 1991, %n1
	jnz %cmp, @end, @loop
@end
	ret0
}

> After load elimination:
function $test() {
@start
@loop
	%n0 =l phi @start -1988, @loop %n1
	%n1 =l add 1, %n0
	%cmp =w cslel 1991, %n1
	jnz %cmp, @end, @loop
@end
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
@loop
	%n0 =l phi @start -1988, @loop %n1
	%n1 =l add 1, %n0
	%cmp =w cslel 1991, %n1
	jnz %cmp, @end, @loop
@end
	ret0
}

