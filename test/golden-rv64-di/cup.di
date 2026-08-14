**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.1 =l copy -1988
@loop
	%n0 =l phi @start %isel.1, @loop %n1
	%n1 =l add %n0, 1
	%isel.2 =w csltl %n1, 1991
	%cmp =w xor %isel.2, 1
	jnz %cmp, @end, @loop
@end
	ret0
}

