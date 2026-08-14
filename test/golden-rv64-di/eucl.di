**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =w copy 747
	%isel.1 =w copy 380
@loop
	%a =w phi @start %isel.1, @loop %r
	%b =w phi @start %isel.2, @loop %a
	%r =w rem %b, %a
	jnz %r, @loop, @end
@end
	storew %a, $a
	ret0
}

