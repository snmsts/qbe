**** Function func ****
> After instruction selection:
function $func() {
@start.0
	%abi.1 =l copy R9
	%isel.36 =l addr S0
	%isel.35 =l copy 1
	storel %isel.35, %isel.36
	%isel.34 =l copy 8
	%isel.33 =l addr S0
	%value.22 =l add %isel.33, %isel.34
	%isel.32 =l copy 2
	storel %isel.32, %value.22
	%isel.31 =l copy 8
	%isel.30 =l addr S0
	%blt.16 =l add %isel.30, %isel.31
	%blt.14 =l load %blt.16
	%isel.29 =l copy 8
	%blt.15 =l add %value.22, %isel.29
	storel %blt.14, %blt.15
	%isel.28 =l copy 0
	%isel.27 =l addr S0
	%blt.13 =l add %isel.27, %isel.28
	%blt.11 =l load %blt.13
	%isel.26 =l copy 0
	%blt.12 =l add %value.22, %isel.26
	storel %blt.11, %blt.12
	%isel.25 =l copy 0
	%isel.24 =l addr S0
	%blt.10 =l add %isel.24, %isel.25
	%blt.8 =l load %blt.10
	%isel.23 =l copy 0
	%blt.9 =l add %abi.1, %isel.23
	storel %blt.8, %blt.9
	%isel.22 =l copy 8
	%isel.21 =l addr S0
	%blt.7 =l add %isel.21, %isel.22
	%blt.5 =l load %blt.7
	%isel.20 =l copy 8
	%blt.6 =l add %abi.1, %isel.20
	storel %blt.5, %blt.6
	%isel.19 =l copy 16
	%isel.18 =l addr S0
	%blt.4 =l add %isel.18, %isel.19
	%blt.2 =l load %blt.4
	%isel.17 =l copy 16
	%blt.3 =l add %abi.1, %isel.17
	storel %blt.2, %blt.3
	ret0 0000
}

**** Function main ****
> After instruction selection:
function $main() {
@start.27
	%isel.39 =l addr S0
	R9 =l copy %isel.39
	call $func, 2001
	copy R1
	%isel.38 =l copy 16
	%isel.37 =l addr S0
	%value.47 =l add %isel.37, %isel.38
	%load.48 =l load %value.47
	acmpl %load.48, 2
	jfieq @passed.32, @failed.31
@failed.31
	call $abort, 0001
	copy R1
@passed.32
	%isel.40 =w copy 0
	R1 =w copy %isel.40
	ret0 0001
}

