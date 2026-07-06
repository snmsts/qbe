**** Function test ****
> After instruction selection:
function $test() {
@start
	R1 =l load $s
	%isel.2 =l addr $s
	%abi.1 =l add %isel.2, 8
	R3 =l load [%abi.1]
	ret0 0002
}

