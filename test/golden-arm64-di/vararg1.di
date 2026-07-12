**** Function f ****
> After instruction selection:
function $f() {
@start
	%x =l copy R1
	%abi.5 =l addr S-1
	%isel.14 =l copy 0
	%abi.6 =l add %abi.5, %isel.14
	%isel.13 =l addr S0
	storel %abi.6, %isel.13
	%isel.12 =l addr S0
	%abi.4 =l load %isel.12
	%i =l load %abi.4
	%isel.11 =l copy 8
	%abi.3 =l add %abi.4, %isel.11
	%isel.10 =l addr S0
	storel %abi.3, %isel.10
	%isel.9 =l addr S0
	%abi.2 =l load %isel.9
	%n =d load %abi.2
	%isel.8 =l copy 8
	%abi.1 =l add %abi.2, %isel.8
	%isel.7 =l addr S0
	storel %abi.1, %isel.7
	R33 =d copy %n
	ret0 0004
}

**** Function g ****
> After instruction selection:
function $g() {
@start
	%fmt =l copy R1
	%abi.15 =l addr S-1
	%isel.19 =l copy 0
	%abi.16 =l add %abi.15, %isel.19
	%isel.18 =l addr S0
	storel %abi.16, %isel.18
	%isel.17 =l addr S0
	R2 =l copy %isel.17
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	R1 =w copy %r
	ret0 0001
}

