**** Function test ****
> After instruction selection:
function $test() {
@start
@l
	%s.3 =w phi @start 0, @c %s.5
	%x.4 =w phi @start 100, @c %x.7
	acmpw %x.4, 10
	jfisle @a, @b
@a
	%s.9 =w add %s.3, %x.4
	%isel.11 =w copy 1
	%x.10 =w sub %x.4, %isel.11
	jmp @c
@b
	%s.8 =w sub %s.3, %x.4
@c
	%s.5 =w phi @b %s.8, @a %s.9
	%x.6 =w phi @b %x.4, @a %x.10
	%isel.12 =w copy 1
	%x.7 =w sub %x.6, %isel.12
	acmpw %x.7, 0
	jfine @l, @end
@end
	R1 =w copy %s.5
	ret0 0001
}

