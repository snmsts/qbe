**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.6 =l copy 8
	%isel.5 =l copy $s
	%abi.2 =l add %isel.5, %isel.6
	R2 =l load %abi.2
	%isel.4 =l copy 0
	%isel.3 =l copy $s
	%abi.1 =l add %isel.3, %isel.4
	R1 =l load %abi.1
	ret0 0002
}

