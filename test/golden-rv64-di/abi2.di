**** Function sum ****
> After instruction selection:
function $sum() {
@start
	%abi.3 =l copy R8
	%abi.1 =l copy R7
	%isel.7 =l addr S0
	%abi.4 =l add %isel.7, 8
	storel %abi.3, %abi.4
	%isel.6 =l addr S0
	%abi.2 =l add %isel.6, 0
	storel %abi.1, %abi.2
	%f1 =s load S0
	%isel.5 =l addr S0
	%p8 =l add %isel.5, 8
	%f2 =s load %p8
	%s =s add %f1, %f2
	R42 =s copy %s
	ret0 0004
}

