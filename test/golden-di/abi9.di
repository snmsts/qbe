**** Function f ****
> After instruction selection:
function $f() {
@_0
	%self =l copy R4
	%abi.1 =l copy R5
	storel 77, [S0]
	%blt.11 =l load [0 + S0]
	storel %blt.11, [0 + %abi.1]
	%blt.8 =l load [8 + S0]
	storel %blt.8, [8 + %abi.1]
	%blt.5 =l load [16 + S0]
	storel %blt.5, [16 + %abi.1]
	%blt.2 =l load [24 + S0]
	storel %blt.2, [24 + %abi.1]
	R1 =l copy %abi.1
	ret0 0001
}

