**** Function alpha ****
> After instruction selection:
function $alpha() {
@ini
	%n =l copy R3
	%l =w copy R2
	%p =l copy R1
	%pe =l add %p, %n
@lop
	%p1 =l phi @ini %p, @lop %p2
	%l1 =w phi @ini %l, @lop %l2
	storeb %l1, %p1
	%isel.3 =l copy 1
	%p2 =l add %p1, %isel.3
	%isel.2 =w copy 1
	%l2 =w add %l1, %isel.2
	acmpl %pe, %p1
	jfieq @end, @lop
@end
	%snk.1 =l add %p, %n
	%isel.4 =w copy 0
	storeb %isel.4, %snk.1
	ret0
}

**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.73 =l copy 16
	R3 =l copy %isel.73
	%isel.72 =w copy 65
	R2 =w copy %isel.72
	%isel.71 =l addr S10
	R1 =l copy %isel.71
	call $alpha, 0061
	%r0 =w copy R1
	%isel.70 =l copy 16
	R3 =l copy %isel.70
	%isel.69 =w copy 97
	R2 =w copy %isel.69
	%isel.68 =l addr S15
	R1 =l copy %isel.68
	call $alpha, 0061
	%r1 =w copy R1
	%isel.67 =l copy 0
	%isel.66 =l addr S15
	%blt.27 =l add %isel.66, %isel.67
	%blt.25 =w loadub %blt.27
	%isel.65 =l copy 0
	%isel.64 =l addr S5
	%blt.26 =l add %isel.64, %isel.65
	storeb %blt.25, %blt.26
	%isel.63 =l copy 1
	%isel.62 =l addr S15
	%blt.24 =l add %isel.62, %isel.63
	%blt.22 =l load %blt.24
	%isel.61 =l copy 1
	%isel.60 =l addr S5
	%blt.23 =l add %isel.60, %isel.61
	storel %blt.22, %blt.23
	%isel.59 =l copy 9
	%isel.58 =l addr S15
	%blt.21 =l add %isel.58, %isel.59
	%blt.19 =l load %blt.21
	%isel.57 =l copy 9
	%isel.56 =l addr S5
	%blt.20 =l add %isel.56, %isel.57
	storel %blt.19, %blt.20
	%isel.55 =l copy 0
	%isel.54 =l addr S10
	%blt.18 =l add %isel.54, %isel.55
	%blt.16 =w loadub %blt.18
	%isel.53 =l copy 0
	%isel.52 =l addr S0
	%blt.17 =l add %isel.52, %isel.53
	storeb %blt.16, %blt.17
	%isel.51 =l copy 1
	%isel.50 =l addr S10
	%blt.15 =l add %isel.50, %isel.51
	%blt.13 =l load %blt.15
	%isel.49 =l copy 1
	%isel.48 =l addr S0
	%blt.14 =l add %isel.48, %isel.49
	storel %blt.13, %blt.14
	%isel.47 =l copy 9
	%isel.46 =l addr S10
	%blt.12 =l add %isel.46, %isel.47
	%blt.10 =l load %blt.12
	%isel.45 =l copy 9
	%isel.44 =l addr S0
	%blt.11 =l add %isel.44, %isel.45
	storel %blt.10, %blt.11
	%isel.43 =l copy 16
	R32 =l sub R32, %isel.43
	%isel.42 =l copy 8
	%abi.9 =l add R32, %isel.42
	%isel.41 =l addr S5
	storel %isel.41, %abi.9
	%isel.40 =l copy 4
	%abi.8 =l add R32, %isel.40
	%isel.39 =w copy 9
	storew %isel.39, %abi.8
	%isel.38 =l copy 0
	%abi.7 =l add R32, %isel.38
	%isel.37 =w copy 8
	storew %isel.37, %abi.7
	%isel.36 =w copy 7
	R8 =w copy %isel.36
	%isel.35 =w copy 6
	R7 =w copy %isel.35
	%isel.34 =w copy 5
	R6 =w copy %isel.34
	%isel.33 =w copy 4
	R5 =w copy %isel.33
	%isel.32 =w copy 3
	R4 =w copy %isel.32
	%isel.31 =w copy 2
	R3 =w copy %isel.31
	%isel.30 =w copy 1
	R2 =w copy %isel.30
	%isel.29 =l addr S0
	R1 =l copy %isel.29
	call $fcb, 0101
	%r2 =w copy R1
	%isel.28 =l copy 16
	R32 =l add R32, %isel.28
	ret0
}

