**** Function sum ****
> After instruction selection:
function $sum() {
@start
	%abi.2 =d copy R17
	%abi.3 =l copy R5
	storel %abi.3, [S0]
	storel %abi.2, [8 + S0]
	%f1 =s load [S0]
	%f2 =s load [8 + S0]
	%s =s add %f1, %f2
	R17 =s copy %s
	ret0 0004
}

