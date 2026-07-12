**** Function sum ****
> After instruction selection:
function $sum() {
@start
	%abi.3 =l copy R2
	%abi.1 =l copy R1
	%isel.11 =l copy 8
	%isel.10 =l addr S0
	%abi.4 =l add %isel.10, %isel.11
	storel %abi.3, %abi.4
	%isel.9 =l copy 0
	%isel.8 =l addr S0
	%abi.2 =l add %isel.8, %isel.9
	storel %abi.1, %abi.2
	%isel.7 =l addr S0
	%f1 =s load %isel.7
	%isel.6 =l copy 8
	%isel.5 =l addr S0
	%p8 =l add %isel.5, %isel.6
	%f2 =s load %p8
	%s =s add %f1, %f2
	R33 =s copy %s
	ret0 0004
}

