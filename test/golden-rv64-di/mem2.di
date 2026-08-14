**** Function func ****
> After instruction selection:
function $func() {
@start.0
	%isel.9 =w copy 1
	storew %isel.9, S0
	%isel.8 =l addr S0
	%field =l add %isel.8, 4
	%isel.7 =l addr S0
	%blt.4 =l add %isel.7, 0
	%blt.2 =w load %blt.4
	%blt.3 =l add %field, 0
	storew %blt.2, %blt.3
	%isel.6 =w copy 2
	storew %isel.6, S0
	%isel.5 =l addr S0
	%abi.1 =l add %isel.5, 0
	R7 =l load %abi.1
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	call $func, 0001
	%abi.10 =l copy R7
	%isel.14 =l addr S0
	%abi.11 =l add %isel.14, 0
	storel %abi.10, %abi.11
	%isel.13 =l addr S0
	%fptr =l add %isel.13, 4
	%field =w loaduw %fptr
	%isel.12 =w xor %field, 1
	%x =w reqz %isel.12
	jnz %x, @passed, @failed
@failed
	call $abort, 0001
	copy R7
@passed
	%isel.15 =w copy 0
	R7 =w copy %isel.15
	ret0 0001
}

