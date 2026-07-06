**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =l addr S0
	%isel.1 =l addr S2
	xcmpl %isel.1, %isel.2
	%r =w flagine
	R1 =w copy %r
	ret0 0001
}

