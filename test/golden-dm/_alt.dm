**** Function test ****
> After slot promotion:
function $test() {
@start
	%ten =w copy 10
	%dum =w copy 0
@loop
	%alt =w phi @start 0, @left %alt1, @right %alt1
	%cnt =w phi @start 100, @left %cnt, @right %cnt1
	%alt1 =w sub 1, %alt
	jnz %alt1, @right, @left
@left
	%x =w phi @loop 10, @left %x1
	%x1 =w sub %x, 1
	%z =w copy %x
	jnz %z, @left, @loop
@right
	%cnt1 =w sub %cnt, %ten
	jnz %cnt1, @loop, @end
@end
	%ret =w add %cnt, %dum
	ret0
}

> After load elimination:
function $test() {
@start
	%ten =w copy 10
	%dum =w copy 0
@loop
	%alt =w phi @start 0, @left %alt1, @right %alt1
	%cnt =w phi @start 100, @left %cnt, @right %cnt1
	%alt1 =w sub 1, %alt
	jnz %alt1, @right, @left
@left
	%x =w phi @loop 10, @left %x1
	%x1 =w sub %x, 1
	%z =w copy %x
	jnz %z, @left, @loop
@right
	%cnt1 =w sub %cnt, %ten
	jnz %cnt1, @loop, @end
@end
	%ret =w add %cnt, %dum
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%ten =w copy 10
	%dum =w copy 0
@loop
	%alt =w phi @start 0, @left %alt1, @right %alt1
	%cnt =w phi @start 100, @left %cnt, @right %cnt1
	%alt1 =w sub 1, %alt
	jnz %alt1, @right, @left
@left
	%x =w phi @loop 10, @left %x1
	%x1 =w sub %x, 1
	%z =w copy %x
	jnz %z, @left, @loop
@right
	%cnt1 =w sub %cnt, %ten
	jnz %cnt1, @loop, @end
@end
	%ret =w add %cnt, %dum
	ret0
}

