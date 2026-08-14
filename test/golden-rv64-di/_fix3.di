**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.12 =w copy 100
	%isel.11 =w copy 0
@l
	%s.3 =w phi @start %isel.11, @c %s.5
	%x.4 =w phi @start %isel.12, @c %x.7
	%isel.14 =w copy 10
	%isel.13 =w csltl %isel.14, %x.4
	%c =w xor %isel.13, 1
	jnz %c, @a, @b
@a
	%s.9 =w add %s.3, %x.4
	%isel.15 =w copy 1
	%x.10 =w sub %x.4, %isel.15
	jmp @c
@b
	%s.8 =w sub %s.3, %x.4
@c
	%s.5 =w phi @b %s.8, @a %s.9
	%x.6 =w phi @b %x.4, @a %x.10
	%isel.16 =w copy 1
	%x.7 =w sub %x.6, %isel.16
	jnz %x.7, @l, @end
@end
	R7 =w copy %s.5
	ret0 0001
}

