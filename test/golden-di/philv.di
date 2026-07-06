**** Function t0 ****
> After instruction selection:
function $t0() {
@start
@loop
	%x0 =w phi @start 256, @loop %y0
	%y0 =w phi @start 128, @loop %y1
	%y1 =w shr %x0, 1
	jfine @loop, @end
@end
	R1 =w copy %x0
	ret0 0001
}

**** Function t1 ****
> After instruction selection:
function $t1() {
@start
@loop
	%y0 =w phi @start 128, @loop %y1
	%x0 =w phi @start 256, @loop %y0
	%y1 =w shr %x0, 1
	jfine @loop, @end
@end
	R1 =w copy %x0
	ret0 0001
}

