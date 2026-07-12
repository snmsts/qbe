**** Function f ****
> After instruction selection:
function $f() {
@start
	%d2 =d load S-18
	%d1 =d copy R39
	%abi.11 =s copy R38
	%abi.9 =s copy R37
	%abi.7 =s copy R36
	%abi.5 =s copy R35
	%abi.3 =s copy R34
	%abi.1 =s copy R33
	%isel.61 =l copy 8
	%isel.60 =l addr S4
	%abi.12 =l add %isel.60, %isel.61
	stores %abi.11, %abi.12
	%isel.59 =l copy 4
	%isel.58 =l addr S4
	%abi.10 =l add %isel.58, %isel.59
	stores %abi.9, %abi.10
	%isel.57 =l copy 0
	%isel.56 =l addr S4
	%abi.8 =l add %isel.56, %isel.57
	stores %abi.7, %abi.8
	%isel.55 =l copy 8
	%isel.54 =l addr S0
	%abi.6 =l add %isel.54, %isel.55
	stores %abi.5, %abi.6
	%isel.53 =l copy 4
	%isel.52 =l addr S0
	%abi.4 =l add %isel.52, %isel.53
	stores %abi.3, %abi.4
	%isel.51 =l copy 0
	%isel.50 =l addr S0
	%abi.2 =l add %isel.50, %isel.51
	stores %abi.1, %abi.2
	%isel.49 =l copy 8
	%isel.48 =l addr S0
	%abi.23 =l add %isel.48, %isel.49
	R35 =s load %abi.23
	%isel.47 =l copy 4
	%isel.46 =l addr S0
	%abi.22 =l add %isel.46, %isel.47
	R34 =s load %abi.22
	%isel.45 =l copy 0
	%isel.44 =l addr S0
	%abi.21 =l add %isel.44, %isel.45
	R33 =s load %abi.21
	call $phfa3, 0601
	copy R1
	%isel.43 =l copy 8
	%isel.42 =l addr S4
	%abi.20 =l add %isel.42, %isel.43
	R35 =s load %abi.20
	%isel.41 =l copy 4
	%isel.40 =l addr S4
	%abi.19 =l add %isel.40, %isel.41
	R34 =s load %abi.19
	%isel.39 =l copy 0
	%isel.38 =l addr S4
	%abi.18 =l add %isel.38, %isel.39
	R33 =s load %abi.18
	call $phfa3, 0601
	copy R1
	%isel.37 =l copy 8
	%isel.36 =l addr S-2
	%abi.17 =l add %isel.36, %isel.37
	R35 =s load %abi.17
	%isel.35 =l copy 4
	%isel.34 =l addr S-2
	%abi.16 =l add %isel.34, %isel.35
	R34 =s load %abi.16
	%isel.33 =l copy 0
	%isel.32 =l addr S-2
	%abi.15 =l add %isel.32, %isel.33
	R33 =s load %abi.15
	call $phfa3, 0601
	copy R1
	%isel.31 =l copy 16
	R32 =l sub R32, %isel.31
	%isel.30 =l copy 0
	%abi.14 =l add R32, %isel.30
	stored %d1, %abi.14
	%isel.29 =l copy $dfmt
	R1 =l copy %isel.29
	call $printf, 0021
	copy R1
	%isel.28 =l copy 16
	R32 =l add R32, %isel.28
	%isel.27 =l copy 16
	R32 =l sub R32, %isel.27
	%isel.26 =l copy 0
	%abi.13 =l add R32, %isel.26
	stored %d2, %abi.13
	%isel.25 =l copy $dfmt
	R1 =l copy %isel.25
	call $printf, 0021
	copy R1
	%isel.24 =l copy 16
	R32 =l add R32, %isel.24
	ret0
}

