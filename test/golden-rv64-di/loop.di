**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =w copy 100
	%isel.1 =w copy 0
@loop
	%s =w phi @start %isel.1, @loop %s1
	%n =w phi @start %isel.2, @loop %n1
	%s1 =w add %s, %n
	%isel.3 =w copy 1
	%n1 =w sub %n, %isel.3
	jnz %n1, @loop, @end
@end
	storew %s1, $a
	ret0
}

