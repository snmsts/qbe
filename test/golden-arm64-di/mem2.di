**** Function func ****
> After instruction selection:
function $func() {
@start.0
	%isel.15 =l addr S0
	%isel.14 =w copy 1
	storew %isel.14, %isel.15
	%isel.13 =l copy 4
	%isel.12 =l addr S0
	%field =l add %isel.12, %isel.13
	%isel.11 =l copy 0
	%isel.10 =l addr S0
	%blt.4 =l add %isel.10, %isel.11
	%blt.2 =w load %blt.4
	%isel.9 =l copy 0
	%blt.3 =l add %field, %isel.9
	storew %blt.2, %blt.3
	%isel.8 =l addr S0
	%isel.7 =w copy 2
	storew %isel.7, %isel.8
	%isel.6 =l copy 0
	%isel.5 =l addr S0
	%abi.1 =l add %isel.5, %isel.6
	R1 =l load %abi.1
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	call $func, 0001
	%abi.16 =l copy R1
	%isel.21 =l copy 0
	%isel.20 =l addr S0
	%abi.17 =l add %isel.20, %isel.21
	storel %abi.16, %abi.17
	%isel.19 =l copy 4
	%isel.18 =l addr S0
	%fptr =l add %isel.18, %isel.19
	%field =w loaduw %fptr
	acmpw %field, 1
	jfieq @passed, @failed
@failed
	call $abort, 0001
	copy R1
@passed
	%isel.22 =w copy 0
	R1 =w copy %isel.22
	ret0 0001
}

