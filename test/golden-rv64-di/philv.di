**** Function t0 ****
> After instruction selection:
function $t0() {
@start
	%isel.2 =w copy 128
	%isel.1 =w copy 256
@loop
	%x0 =w phi @start %isel.1, @loop %y0
	%y0 =w phi @start %isel.2, @loop %y1
	%y1 =w shr %x0, 1
	jnz %y1, @loop, @end
@end
	R7 =w copy %x0
	ret0 0001
}

**** Function t1 ****
> After instruction selection:
function $t1() {
@start
	%isel.4 =w copy 256
	%isel.3 =w copy 128
@loop
	%y0 =w phi @start %isel.3, @loop %y1
	%x0 =w phi @start %isel.4, @loop %y0
	%y1 =w shr %x0, 1
	jnz %y1, @loop, @end
@end
	R7 =w copy %x0
	ret0 0001
}

