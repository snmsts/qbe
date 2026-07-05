**** Function test ****
> After slot promotion:
function $test() {
@start
@loop
	%s =w phi @start 0, @loop %s1
	%n =w phi @start 100, @loop %n1
	%s1 =w add %s, %n
	%n1 =w sub %n, 1
	jnz %n1, @loop, @end
@end
	storew %s1, $a
	ret0
}

> After load elimination:
function $test() {
@start
@loop
	%s =w phi @start 0, @loop %s1
	%n =w phi @start 100, @loop %n1
	%s1 =w add %s, %n
	%n1 =w sub %n, 1
	jnz %n1, @loop, @end
@end
	storew %s1, $a
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
@loop
	%s =w phi @start 0, @loop %s1
	%n =w phi @start 100, @loop %n1
	%s1 =w add %s, %n
	%n1 =w sub %n, 1
	jnz %n1, @loop, @end
@end
	storew %s1, $a
	ret0
}

