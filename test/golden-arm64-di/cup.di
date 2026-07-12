**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%n0 =l phi @start -1988, @loop %n1
	%isel.1 =l copy 1
	%n1 =l add %n0, %isel.1
	acmpl %n1, 1991
	jfisge @end, @loop
@end
	ret0
}

