**** Function func ****
> After instruction selection:
function $func() {
@start.0
	storew 1, [S0]
	%blt.1 =w load [0 + S0]
	storew %blt.1, [4 + S0]
	storew 2, [S0]
	R1 =l load [S0]
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	call $func, 0001
	%abi.4 =l copy R1
	storel %abi.4, [S0]
	%field =w loaduw [4 + S0]
	xcmpw 1, %field
	jfieq @passed, @failed
@failed
	call $abort, 0001
	copy R1
@passed
	R1 =w copy 0
	ret0 0001
}

