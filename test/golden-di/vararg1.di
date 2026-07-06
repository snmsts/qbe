**** Function f ****
> After instruction selection:
function $f() {
@start
	%x =l copy R5
	storew 8, [S0]
	storew 48, [4 + S0]
	%abi.28 =l add R15, 16
	storel %abi.28, [8 + S0]
	%abi.26 =l add R15, -176
	storel %abi.26, [16 + S0]
	%abi.15 =l loadsw [0 + S0]
	xcmpw 48, %abi.15
	jfiult @start.5, @start.6
@start.6
	%abi.20 =l load [8 + S0]
	%abi.22 =l add %abi.20, 8
	storel %abi.22, [8 + S0]
	jmp @start.4
@start.5
	%abi.19 =l load [16 + S0]
	%abi.14 =l add %abi.19, %abi.15
	%abi.16 =w add %abi.15, 8
	storew %abi.16, [0 + S0]
@start.4
	%abi.13 =l phi @start.6 %abi.20, @start.5 %abi.14
	%abi.3 =l loadsw [4 + S0]
	xcmpw 176, %abi.3
	jfiult @start.2, @start.3
@start.3
	%abi.8 =l load [8 + S0]
	%abi.10 =l add %abi.8, 8
	storel %abi.10, [8 + S0]
	jmp @start.1
@start.2
	%abi.7 =l load [16 + S0]
	%abi.2 =l add %abi.7, %abi.3
	%abi.4 =w add %abi.3, 16
	storew %abi.4, [4 + S0]
@start.1
	%abi.1 =l phi @start.3 %abi.8, @start.2 %abi.2
	%n =d load [%abi.1]
	R17 =d copy %n
	ret0 0004
}

**** Function g ****
> After instruction selection:
function $g() {
@start
	%fmt =l copy R5
	storew 8, [S0]
	storew 48, [4 + S0]
	%abi.33 =l add R15, 16
	storel %abi.33, [8 + S0]
	%abi.31 =l add R15, -176
	storel %abi.31, [16 + S0]
	%isel.35 =l addr S0
	R4 =l copy %isel.35
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	R1 =w copy %r
	ret0 0001
}

