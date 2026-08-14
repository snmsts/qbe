**** Function alpha ****
> After instruction selection:
function $alpha() {
@ini
	%n =l copy R9
	%l =w copy R8
	%p =l copy R7
	%pe =l add %p, %n
@lop
	%p1 =l phi @ini %p, @lop %p2
	%l1 =w phi @ini %l, @lop %l2
	storeb %l1, %p1
	%p2 =l add %p1, 1
	%l2 =w add %l1, 1
	%isel.2 =l xor %pe, %p1
	%c1 =w reqz %isel.2
	jnz %c1, @end, @lop
@end
	%snk.1 =l add %p, %n
	%isel.3 =w copy 0
	storeb %isel.3, %snk.1
	ret0
}

**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.60 =l copy 16
	R9 =l copy %isel.60
	%isel.59 =w copy 65
	R8 =w copy %isel.59
	%isel.58 =l addr S12
	R7 =l copy %isel.58
	call $alpha, 0031
	%r0 =w copy R7
	%isel.57 =l copy 16
	R9 =l copy %isel.57
	%isel.56 =w copy 97
	R8 =w copy %isel.56
	%isel.55 =l addr S17
	R7 =l copy %isel.55
	call $alpha, 0031
	%r1 =w copy R7
	%isel.54 =l copy 32
	%abi.6 =l salloc %isel.54
	%abi.11 =l add %abi.6, 16
	%isel.53 =l addr S6
	storel %isel.53, %abi.11
	%abi.9 =l add %abi.6, 8
	%isel.52 =w copy 9
	%abi.10 =l extsw %isel.52
	storel %abi.10, %abi.9
	%abi.7 =l add %abi.6, 0
	%isel.51 =w copy 8
	%abi.8 =l extsw %isel.51
	storel %abi.8, %abi.7
	%isel.50 =l addr S17
	%blt.29 =l add %isel.50, 0
	%blt.27 =w loadub %blt.29
	%isel.49 =l addr S6
	%blt.28 =l add %isel.49, 0
	storeb %blt.27, %blt.28
	%isel.48 =l addr S17
	%blt.26 =l add %isel.48, 1
	%blt.24 =l load %blt.26
	%isel.47 =l addr S6
	%blt.25 =l add %isel.47, 1
	storel %blt.24, %blt.25
	%isel.46 =l addr S17
	%blt.23 =l add %isel.46, 9
	%blt.21 =l load %blt.23
	%isel.45 =l addr S6
	%blt.22 =l add %isel.45, 9
	storel %blt.21, %blt.22
	%isel.44 =l addr S12
	%blt.20 =l add %isel.44, 0
	%blt.18 =w loadub %blt.20
	%isel.43 =l addr S0
	%blt.19 =l add %isel.43, 0
	storeb %blt.18, %blt.19
	%isel.42 =l addr S12
	%blt.17 =l add %isel.42, 1
	%blt.15 =l load %blt.17
	%isel.41 =l addr S0
	%blt.16 =l add %isel.41, 1
	storel %blt.15, %blt.16
	%isel.40 =l addr S12
	%blt.14 =l add %isel.40, 9
	%blt.12 =l load %blt.14
	%isel.39 =l addr S0
	%blt.13 =l add %isel.39, 9
	storel %blt.12, %blt.13
	%isel.38 =w copy 7
	R14 =w copy %isel.38
	%isel.37 =w copy 6
	R13 =w copy %isel.37
	%isel.36 =w copy 5
	R12 =w copy %isel.36
	%isel.35 =w copy 4
	R11 =w copy %isel.35
	%isel.34 =w copy 3
	R10 =w copy %isel.34
	%isel.33 =w copy 2
	R9 =w copy %isel.33
	%isel.32 =w copy 1
	R8 =w copy %isel.32
	%isel.31 =l addr S0
	R7 =l copy %isel.31
	call $fcb, 0081
	%r2 =w copy R7
	%isel.30 =l copy -32
	salloc %isel.30
	ret0
}

