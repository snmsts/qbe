**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%n0 =l phi @start -1988, @loop %n1
	%n1 =l add %n0, 1
	xcmpl 1991, %n1
	jfisge @end, @loop
@end
	ret0
}

