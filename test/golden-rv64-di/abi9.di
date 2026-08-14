**** Function f ****
> After instruction selection:
function $f() {
@_0
	%self =l copy R8
	%abi.1 =l copy R7
	%isel.18 =l copy 77
	storel %isel.18, S0
	%isel.17 =l addr S0
	%blt.13 =l add %isel.17, 0
	%blt.11 =l load %blt.13
	%blt.12 =l add %abi.1, 0
	storel %blt.11, %blt.12
	%isel.16 =l addr S0
	%blt.10 =l add %isel.16, 8
	%blt.8 =l load %blt.10
	%blt.9 =l add %abi.1, 8
	storel %blt.8, %blt.9
	%isel.15 =l addr S0
	%blt.7 =l add %isel.15, 16
	%blt.5 =l load %blt.7
	%blt.6 =l add %abi.1, 16
	storel %blt.5, %blt.6
	%isel.14 =l addr S0
	%blt.4 =l add %isel.14, 24
	%blt.2 =l load %blt.4
	%blt.3 =l add %abi.1, 24
	storel %blt.2, %blt.3
	ret0 0000
}

