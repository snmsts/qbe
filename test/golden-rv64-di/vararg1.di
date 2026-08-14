**** Function f ****
> After instruction selection:
function $f() {
@start
	%x =l copy R7
	%abi.5 =l addr S-3
	storel %abi.5, S0
	%abi.3 =l load S0
	%i =l load %abi.3
	%abi.4 =l add %abi.3, 8
	storel %abi.4, S0
	%abi.1 =l load S0
	%n =d load %abi.1
	%abi.2 =l add %abi.1, 8
	storel %abi.2, S0
	R42 =d copy %n
	ret0 0004
}

**** Function g ****
> After instruction selection:
function $g() {
@start
	%fmt =l copy R7
	%abi.6 =l addr S-3
	storel %abi.6, S0
	%isel.7 =l addr S0
	R8 =l copy %isel.7
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	R7 =w copy %r
	ret0 0001
}

