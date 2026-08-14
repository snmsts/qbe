**** Function f ****
> After instruction selection:
function $f() {
@start
	%d2 =d copy R43
	%abi.11 =l copy R12
	%abi.9 =l copy R11
	%d1 =d copy R42
	%abi.7 =l copy R10
	%abi.5 =l copy R9
	%abi.3 =l copy R8
	%abi.1 =l copy R7
	%isel.34 =l addr S8
	%abi.12 =l add %isel.34, 8
	storel %abi.11, %abi.12
	%isel.33 =l addr S8
	%abi.10 =l add %isel.33, 0
	storel %abi.9, %abi.10
	%isel.32 =l addr S4
	%abi.8 =l add %isel.32, 8
	storel %abi.7, %abi.8
	%isel.31 =l addr S4
	%abi.6 =l add %isel.31, 0
	storel %abi.5, %abi.6
	%isel.30 =l addr S0
	%abi.4 =l add %isel.30, 8
	storel %abi.3, %abi.4
	%isel.29 =l addr S0
	%abi.2 =l add %isel.29, 0
	storel %abi.1, %abi.2
	%isel.28 =l addr S0
	%abi.20 =l add %isel.28, 8
	R8 =l load %abi.20
	%isel.27 =l addr S0
	%abi.19 =l add %isel.27, 0
	R7 =l load %abi.19
	call $phfa3, 0021
	copy R7
	%isel.26 =l addr S4
	%abi.18 =l add %isel.26, 8
	R8 =l load %abi.18
	%isel.25 =l addr S4
	%abi.17 =l add %isel.25, 0
	R7 =l load %abi.17
	call $phfa3, 0021
	copy R7
	%isel.24 =l addr S8
	%abi.16 =l add %isel.24, 8
	R8 =l load %abi.16
	%isel.23 =l addr S8
	%abi.15 =l add %isel.23, 0
	R7 =l load %abi.15
	call $phfa3, 0021
	copy R7
	%abi.14 =l cast %d1
	R8 =l copy %abi.14
	%isel.22 =l copy $dfmt
	R7 =l copy %isel.22
	call $printf, 0021
	copy R7
	%abi.13 =l cast %d2
	R8 =l copy %abi.13
	%isel.21 =l copy $dfmt
	R7 =l copy %isel.21
	call $printf, 0021
	copy R7
	ret0
}

