**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.3 =l addr S0
	%y =l add %isel.3, 8
	%isel.2 =w copy 16
	%isel.1 =l extsw %y
	%m =w rem %isel.1, %isel.2
	storew %m, %y
	storew %m, $a
	ret0
}

