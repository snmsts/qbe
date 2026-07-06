**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%x4 =d phi @start [$".Lfp0"], @loop %x5
	%i1 =w phi @start 0, @loop %i2
	%x5 =d add %x4, %x4
	%i2 =w add %i1, 1
	%isel.1 =d copy [$".Lfp1"]
	xcmpd %x5, %isel.1
	jffge @loop, @end
@end
	storew %i2, $a
	ret0
}

