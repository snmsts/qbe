**** Function main ****
> After instruction selection:
function $main() {
@_0
	%isel.14 =l copy 16
	%abi.1 =l salloc %isel.14
	%abi.2 =l add %abi.1, 0
	%isel.13 =l copy 9223372036854775807
	storel %isel.13, %abi.2
	%isel.12 =l copy 8
	R14 =l copy %isel.12
	%isel.11 =l copy 7
	R13 =l copy %isel.11
	%isel.10 =l copy 6
	R12 =l copy %isel.10
	%isel.9 =l copy 5
	R11 =l copy %isel.9
	%isel.8 =l copy 4
	R10 =l copy %isel.8
	%isel.7 =l copy 3
	R9 =l copy %isel.7
	%isel.6 =l copy 2
	R8 =l copy %isel.6
	%isel.5 =l copy 1
	R7 =l copy %isel.5
	call $myfunc, 0081
	%_1 =w copy R7
	%isel.4 =l copy -16
	salloc %isel.4
	%isel.3 =w copy 0
	R7 =w copy %isel.3
	ret0 0001
}

