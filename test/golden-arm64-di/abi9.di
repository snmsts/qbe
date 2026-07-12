**** Function f ****
> After instruction selection:
function $f() {
@_0
	%self =l copy R1
	%abi.1 =l copy R9
	%isel.27 =l addr S0
	%isel.26 =l copy 77
	storel %isel.26, %isel.27
	%isel.25 =l copy 0
	%isel.24 =l addr S0
	%blt.13 =l add %isel.24, %isel.25
	%blt.11 =l load %blt.13
	%isel.23 =l copy 0
	%blt.12 =l add %abi.1, %isel.23
	storel %blt.11, %blt.12
	%isel.22 =l copy 8
	%isel.21 =l addr S0
	%blt.10 =l add %isel.21, %isel.22
	%blt.8 =l load %blt.10
	%isel.20 =l copy 8
	%blt.9 =l add %abi.1, %isel.20
	storel %blt.8, %blt.9
	%isel.19 =l copy 16
	%isel.18 =l addr S0
	%blt.7 =l add %isel.18, %isel.19
	%blt.5 =l load %blt.7
	%isel.17 =l copy 16
	%blt.6 =l add %abi.1, %isel.17
	storel %blt.5, %blt.6
	%isel.16 =l copy 24
	%isel.15 =l addr S0
	%blt.4 =l add %isel.15, %isel.16
	%blt.2 =l load %blt.4
	%isel.14 =l copy 24
	%blt.3 =l add %abi.1, %isel.14
	storel %blt.2, %blt.3
	ret0 0000
}

