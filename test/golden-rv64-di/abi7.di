**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.4 =l copy $s
	%abi.2 =l add %isel.4, 8
	R8 =l load %abi.2
	%isel.3 =l copy $s
	%abi.1 =l add %isel.3, 0
	R7 =l load %abi.1
	ret0 0002
}

