**** Function test ****
> After slot promotion:
function $test() {
@start
@loop
	%a =w phi @start 380, @loop %r
	%b =w phi @start 747, @loop %a
	%r =w rem %b, %a
	jnz %r, @loop, @end
@end
	storew %a, $a
	ret0
}

> After load elimination:
function $test() {
@start
@loop
	%a =w phi @start 380, @loop %r
	%b =w phi @start 747, @loop %a
	%r =w rem %b, %a
	jnz %r, @loop, @end
@end
	storew %a, $a
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
@loop
	%a =w phi @start 380, @loop %r
	%b =w phi @start 747, @loop %a
	%r =w rem %b, %a
	jnz %r, @loop, @end
@end
	storew %a, $a
	ret0
}

