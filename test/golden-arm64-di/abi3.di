**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.18 =l copy $z
	%a =w loadsw %isel.18
	%y =w add %a, %a
	%yl =l extsw %y
	%isel.17 =l copy 12
	%isel.16 =l addr S0
	%s1 =l add %isel.16, %isel.17
	%isel.15 =l addr S0
	%isel.14 =l copy 4
	storel %isel.14, %isel.15
	%isel.13 =w copy 5
	storew %isel.13, %s1
	%isel.12 =l copy $F
	%f =l add %yl, %isel.12
	%isel.11 =w copy 6
	R7 =w copy %isel.11
	%isel.10 =l copy 8
	%isel.9 =l addr S0
	%abi.2 =l add %isel.9, %isel.10
	R6 =l load %abi.2
	%isel.8 =l copy 0
	%isel.7 =l addr S0
	%abi.1 =l add %isel.7, %isel.8
	R5 =l load %abi.1
	%isel.6 =w copy 3
	R4 =w copy %isel.6
	%isel.5 =w copy 2
	R3 =w copy %isel.5
	%isel.4 =w copy 1
	R2 =w copy %isel.4
	R1 =w copy %y
	call %f, 00e1
	%x =w copy R1
	%x1 =w add %y, %x
	%isel.3 =l copy $a
	storew %x1, %isel.3
	ret0
}

