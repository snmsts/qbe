**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.4 =l copy 8
	%isel.3 =l addr S0
	%y =l add %isel.3, %isel.4
	%isel.2 =w copy 16
	%m =w rem %y, %isel.2
	storew %m, %y
	%isel.1 =l copy $a
	storew %m, %isel.1
	ret0
}

