**** Function main ****
> After instruction selection:
function $main() {
@_0
	%isel.14 =l copy 16
	R32 =l sub R32, %isel.14
	%isel.13 =l copy 0
	%abi.1 =l add R32, %isel.13
	%isel.12 =l copy 9223372036854775807
	storel %isel.12, %abi.1
	%isel.11 =l copy 8
	R8 =l copy %isel.11
	%isel.10 =l copy 7
	R7 =l copy %isel.10
	%isel.9 =l copy 6
	R6 =l copy %isel.9
	%isel.8 =l copy 5
	R5 =l copy %isel.8
	%isel.7 =l copy 4
	R4 =l copy %isel.7
	%isel.6 =l copy 3
	R3 =l copy %isel.6
	%isel.5 =l copy 2
	R2 =l copy %isel.5
	%isel.4 =l copy 1
	R1 =l copy %isel.4
	call $myfunc, 0101
	%_1 =w copy R1
	%isel.3 =l copy 16
	R32 =l add R32, %isel.3
	%isel.2 =w copy 0
	R1 =w copy %isel.2
	ret0 0001
}

