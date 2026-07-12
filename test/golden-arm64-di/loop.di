**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%s =w phi @start 0, @loop %s1
	%n =w phi @start 100, @loop %n1
	%s1 =w add %s, %n
	%isel.1 =w copy 1
	%n1 =w sub %n, %isel.1
	acmpw %n1, 0
	jfine @loop, @end
@end
	%isel.2 =l copy $a
	storew %s1, %isel.2
	ret0
}

