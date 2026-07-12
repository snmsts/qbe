**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%a =w phi @start 380, @loop %r
	%b =w phi @start 747, @loop %a
	%r =w rem %b, %a
	acmpw %r, 0
	jfine @loop, @end
@end
	%isel.1 =l copy $a
	storew %a, %isel.1
	ret0
}

