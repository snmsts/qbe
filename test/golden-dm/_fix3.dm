**** Function test ****
> After slot promotion:
function $test() {
@start
	%x =w copy 100
	%s =w copy 0
@l
	%c =w cslew %x, 10
	jnz %c, @a, @b
@a
	%s =w add %s, %x
	%x =w sub %x, 1
	jmp @c
@b
	%s =w sub %s, %x
@c
	%x =w sub %x, 1
	jnz %x, @l, @end
@end
	retw %s
}

> After load elimination:
function $test() {
@start
	%x.1 =w copy 100
	%s.2 =w copy 0
@l
	%s.3 =w phi @start %s.2, @c %s.5
	%x.4 =w phi @start %x.1, @c %x.7
	%c =w cslew %x.4, 10
	jnz %c, @a, @b
@a
	%s.9 =w add %s.3, %x.4
	%x.10 =w sub %x.4, 1
	jmp @c
@b
	%s.8 =w sub %s.3, %x.4
@c
	%s.5 =w phi @b %s.8, @a %s.9
	%x.6 =w phi @b %x.4, @a %x.10
	%x.7 =w sub %x.6, 1
	jnz %x.7, @l, @end
@end
	retw %s.5
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%x.1 =w copy 100
	%s.2 =w copy 0
@l
	%s.3 =w phi @start %s.2, @c %s.5
	%x.4 =w phi @start %x.1, @c %x.7
	%c =w cslew %x.4, 10
	jnz %c, @a, @b
@a
	%s.9 =w add %s.3, %x.4
	%x.10 =w sub %x.4, 1
	jmp @c
@b
	%s.8 =w sub %s.3, %x.4
@c
	%s.5 =w phi @b %s.8, @a %s.9
	%x.6 =w phi @b %x.4, @a %x.10
	%x.7 =w sub %x.6, 1
	jnz %x.7, @l, @end
@end
	retw %s.5
}

