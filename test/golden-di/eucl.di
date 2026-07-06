**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%a =w phi @start 380, @loop %r
	%b =w phi @start 747, @loop %a
	R1 =w copy %b
	R3 =w sign R1
	xidivw %a
	copy R1
	%r =w copy R3
	xcmpw 0, %r
	jfine @loop, @end
@end
	storew %a, $a
	ret0
}

