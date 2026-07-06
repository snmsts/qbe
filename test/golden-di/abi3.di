**** Function test ****
> After instruction selection:
function $test() {
@start
	%a =w loadsw $z
	%y =w add %a, %a
	%yl =l extsw %y
	storel 4, [S0]
	storew 5, [12 + S0]
	%isel.4 =l addr $F
	%f =l add %yl, %isel.4
	%abi.2 =l salloc 16
	storel 6, [0 + %abi.2]
	R6 =l load [S0]
	R7 =l load [8 + S0]
	R2 =w copy 3
	R3 =w copy 2
	R4 =w copy 1
	R5 =w copy %y
	call %f, 0061
	%x =w copy R1
	salloc -16
	%x1 =w add %y, %x
	storew %x1, $a
	ret0
}

