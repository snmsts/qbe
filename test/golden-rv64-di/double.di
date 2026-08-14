**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =w copy 0
	%isel.1 =d load $".Lfp0"
@loop
	%x4 =d phi @start %isel.1, @loop %x5
	%i1 =w phi @start %isel.2, @loop %i2
	%x5 =d add %x4, %x4
	%i2 =w add %i1, 1
	%isel.3 =d load $".Lfp1"
	%c0 =w cled %x5, %isel.3
	jnz %c0, @loop, @end
@end
	storew %i2, $a
	ret0
}

