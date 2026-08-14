**** Function test ****
> After instruction selection:
function $test() {
@start
	%a =w loadsw $z
	%y =w add %a, %a
	%yl =l extsw %y
	%isel.12 =l addr S0
	%s1 =l add %isel.12, 12
	%isel.11 =l copy 4
	storel %isel.11, S0
	%isel.10 =w copy 5
	storew %isel.10, %s1
	%isel.9 =l copy $F
	%f =l add %yl, %isel.9
	%isel.8 =w copy 6
	R13 =w copy %isel.8
	%isel.7 =l addr S0
	%abi.2 =l add %isel.7, 8
	R12 =l load %abi.2
	%isel.6 =l addr S0
	%abi.1 =l add %isel.6, 0
	R11 =l load %abi.1
	%isel.5 =w copy 3
	R10 =w copy %isel.5
	%isel.4 =w copy 2
	R9 =w copy %isel.4
	%isel.3 =w copy 1
	R8 =w copy %isel.3
	R7 =w copy %y
	call %f, 0071
	%x =w copy R7
	%x1 =w add %y, %x
	storew %x1, $a
	ret0
}

