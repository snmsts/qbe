**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =l addr S0
	%y =l add %isel.2, 8
	%isel.1 =w copy 16
	R1 =w copy %y
	R3 =w sign R1
	xidivw %isel.1
	copy R1
	%m =w copy R3
	storew %m, [8 + S0]
	storew %m, $a
	ret0
}

