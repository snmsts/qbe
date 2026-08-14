**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.3 =l addr S2
	%isel.2 =l addr S0
	%isel.1 =l xor %isel.2, %isel.3
	%r =w rnez %isel.1
	R7 =w copy %r
	ret0 0001
}

