**** Function f ****
> After instruction selection:
function $f() {
@start
	%d2 =d copy R24
	%abi.8 =d copy R23
	%abi.9 =d copy R22
	%d1 =d copy R21
	%abi.5 =d copy R20
	%abi.6 =d copy R19
	%abi.2 =d copy R18
	%abi.3 =d copy R17
	storel %abi.9, [S0]
	storel %abi.8, [8 + S0]
	storel %abi.6, [S4]
	storel %abi.5, [8 + S4]
	storel %abi.3, [S8]
	storel %abi.2, [8 + S8]
	R17 =d load [S8]
	R18 =d load [8 + S8]
	call $phfa3, 0201
	copy R1
	R17 =d load [S4]
	R18 =d load [8 + S4]
	call $phfa3, 0201
	copy R1
	R17 =d load [S0]
	R18 =d load [8 + S0]
	call $phfa3, 0201
	copy R1
	R17 =d copy %d1
	%isel.14 =l addr $dfmt
	R5 =l copy %isel.14
	R1 =w copy 1
	call $printf, 1111
	copy R1
	R17 =d copy %d2
	%isel.13 =l addr $dfmt
	R5 =l copy %isel.13
	R1 =w copy 1
	call $printf, 1111
	copy R1
	ret0
}

