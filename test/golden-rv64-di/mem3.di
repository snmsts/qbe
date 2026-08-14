**** Function func ****
> After instruction selection:
function $func() {
@start.0
	%abi.1 =l copy R7
	%isel.24 =l copy 1
	storel %isel.24, S0
	%isel.23 =l addr S0
	%value.22 =l add %isel.23, 8
	%isel.22 =l copy 2
	storel %isel.22, %value.22
	%isel.21 =l addr S0
	%blt.16 =l add %isel.21, 8
	%blt.14 =l load %blt.16
	%blt.15 =l add %value.22, 8
	storel %blt.14, %blt.15
	%isel.20 =l addr S0
	%blt.13 =l add %isel.20, 0
	%blt.11 =l load %blt.13
	%blt.12 =l add %value.22, 0
	storel %blt.11, %blt.12
	%isel.19 =l addr S0
	%blt.10 =l add %isel.19, 0
	%blt.8 =l load %blt.10
	%blt.9 =l add %abi.1, 0
	storel %blt.8, %blt.9
	%isel.18 =l addr S0
	%blt.7 =l add %isel.18, 8
	%blt.5 =l load %blt.7
	%blt.6 =l add %abi.1, 8
	storel %blt.5, %blt.6
	%isel.17 =l addr S0
	%blt.4 =l add %isel.17, 16
	%blt.2 =l load %blt.4
	%blt.3 =l add %abi.1, 16
	storel %blt.2, %blt.3
	ret0 0000
}

**** Function main ****
> After instruction selection:
function $main() {
@start.27
	%isel.27 =l addr S0
	R7 =l copy %isel.27
	call $func, 0011
	copy R7
	%isel.26 =l addr S0
	%value.47 =l add %isel.26, 16
	%load.48 =l load %value.47
	%isel.25 =l xor %load.48, 2
	%.33 =w reqz %isel.25
	jnz %.33, @passed.32, @failed.31
@failed.31
	call $abort, 0001
	copy R7
@passed.32
	%isel.28 =w copy 0
	R7 =w copy %isel.28
	ret0 0001
}

