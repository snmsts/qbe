**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =l copy $"Lfp0"
	%isel.1 =d load %isel.2
@loop
	%x4 =d phi @start %isel.1, @loop %x5
	%i1 =w phi @start 0, @loop %i2
	%x5 =d add %x4, %x4
	%isel.5 =w copy 1
	%i2 =w add %i1, %isel.5
	%isel.4 =l copy $"Lfp1"
	%isel.3 =d load %isel.4
	afcmpd %x5, %isel.3
	jffle @loop, @end
@end
	%isel.6 =l copy $a
	storew %i2, %isel.6
	ret0
}

