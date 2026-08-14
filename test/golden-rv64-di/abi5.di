**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.84 =l addr S18
	R7 =l copy %isel.84
	call $t1, 0011
	copy R7
	%isel.83 =l addr S18
	R8 =l copy %isel.83
	%isel.82 =l copy $fmt1
	R7 =l copy %isel.82
	call $printf, 0021
	%i1 =w copy R7
	call $t2, 0001
	%abi.41 =l copy R7
	%isel.81 =l addr S16
	%abi.42 =l add %isel.81, 0
	storel %abi.41, %abi.42
	%w2 =w loadsw S16
	R8 =w copy %w2
	%isel.80 =l copy $fmt2
	R7 =l copy %isel.80
	call $printf, 0021
	%i2 =w copy R7
	call $t3, 0005
	%abi.39 =w copy R7
	%abi.37 =s copy R42
	%isel.79 =l addr S14
	%abi.40 =l add %isel.79, 4
	storew %abi.39, %abi.40
	%isel.78 =l addr S14
	%abi.38 =l add %isel.78, 0
	stores %abi.37, %abi.38
	%s3 =s load S14
	%isel.77 =l addr S14
	%r34 =l add %isel.77, 4
	%w3 =w loadsw %r34
	%p3 =d exts %s3
	%abi.36 =l cast %p3
	R9 =w copy %w3
	R8 =l copy %abi.36
	%isel.76 =l copy $fmt3
	R7 =l copy %isel.76
	call $printf, 0031
	%i3 =w copy R7
	call $t4, 0005
	%abi.34 =d copy R42
	%abi.32 =w copy R7
	%isel.75 =l addr S32
	%abi.35 =l add %isel.75, 8
	stored %abi.34, %abi.35
	%isel.74 =l addr S32
	%abi.33 =l add %isel.74, 0
	storew %abi.32, %abi.33
	%w4 =w loadsw S32
	%isel.73 =l addr S32
	%r48 =l add %isel.73, 8
	%d4 =d load %r48
	%abi.31 =l cast %d4
	R9 =l copy %abi.31
	R8 =w copy %w4
	%isel.72 =l copy $fmt4
	R7 =l copy %isel.72
	call $printf, 0031
	%i4 =w copy R7
	call $t5, 0005
	%abi.29 =l copy R7
	%abi.27 =s copy R42
	%isel.71 =l addr S28
	%abi.30 =l add %isel.71, 8
	storel %abi.29, %abi.30
	%isel.70 =l addr S28
	%abi.28 =l add %isel.70, 0
	stores %abi.27, %abi.28
	%s5 =s load S28
	%d5 =d exts %s5
	%isel.69 =l addr S28
	%r58 =l add %isel.69, 8
	%l5 =l load %r58
	%abi.26 =l cast %d5
	R9 =l copy %l5
	R8 =l copy %abi.26
	%isel.68 =l copy $fmt5
	R7 =l copy %isel.68
	call $printf, 0031
	%i5 =w copy R7
	call $t6, 0002
	%abi.24 =l copy R8
	%abi.22 =l copy R7
	%isel.67 =l addr S10
	%abi.25 =l add %isel.67, 8
	storel %abi.24, %abi.25
	%isel.66 =l addr S10
	%abi.23 =l add %isel.66, 0
	storel %abi.22, %abi.23
	%isel.65 =l addr S10
	R8 =l copy %isel.65
	%isel.64 =l copy $fmt6
	R7 =l copy %isel.64
	call $printf, 0021
	%i6 =w copy R7
	call $t7, 0008
	%abi.20 =d copy R43
	%abi.18 =s copy R42
	%isel.63 =l addr S24
	%abi.21 =l add %isel.63, 8
	stored %abi.20, %abi.21
	%isel.62 =l addr S24
	%abi.19 =l add %isel.62, 0
	stores %abi.18, %abi.19
	%s7 =s load S24
	%d71 =d exts %s7
	%isel.61 =l addr S24
	%r78 =l add %isel.61, 8
	%d72 =d load %r78
	%abi.17 =l cast %d72
	%abi.16 =l cast %d71
	R9 =l copy %abi.17
	R8 =l copy %abi.16
	%isel.60 =l copy $fmt7
	R7 =l copy %isel.60
	call $printf, 0031
	%i7 =w copy R7
	call $t8, 0002
	%abi.14 =l copy R8
	%abi.12 =l copy R7
	%isel.59 =l addr S6
	%abi.15 =l add %isel.59, 8
	storel %abi.14, %abi.15
	%isel.58 =l addr S6
	%abi.13 =l add %isel.58, 0
	storel %abi.12, %abi.13
	%isel.57 =l addr S6
	%r84 =l add %isel.57, 4
	%isel.56 =l addr S6
	%r88 =l add %isel.56, 8
	%isel.55 =l addr S6
	%r812 =l add %isel.55, 12
	%w81 =w loadsw S6
	%w82 =w loadsw %r84
	%w83 =w loadsw %r88
	%w84 =w loadsw %r812
	R11 =w copy %w84
	R10 =w copy %w83
	R9 =w copy %w82
	R8 =w copy %w81
	%isel.54 =l copy $fmt8
	R7 =l copy %isel.54
	call $printf, 0051
	%i8 =w copy R7
	call $t9, 0001
	%abi.10 =l copy R7
	%isel.53 =l addr S4
	%abi.11 =l add %isel.53, 0
	storel %abi.10, %abi.11
	%isel.52 =l addr S4
	%r94 =l add %isel.52, 4
	%w9 =w loadsw S4
	%s9 =s load %r94
	%d9 =d exts %s9
	%abi.9 =l cast %d9
	R9 =l copy %abi.9
	R8 =w copy %w9
	%isel.51 =l copy $fmt9
	R7 =l copy %isel.51
	call $printf, 0031
	%i9 =w copy R7
	call $ta, 0005
	%abi.7 =s copy R42
	%abi.5 =w copy R7
	%isel.50 =l addr S2
	%abi.8 =l add %isel.50, 4
	stores %abi.7, %abi.8
	%isel.49 =l addr S2
	%abi.6 =l add %isel.49, 0
	storew %abi.5, %abi.6
	%isel.48 =l addr S2
	%ra4 =l add %isel.48, 4
	%wa =w loadsb S2
	%sa =s load %ra4
	%da =d exts %sa
	%abi.4 =l cast %da
	R9 =l copy %abi.4
	R8 =w copy %wa
	%isel.47 =l copy $fmta
	R7 =l copy %isel.47
	call $printf, 0031
	%ia =w copy R7
	call $tb, 0001
	%abi.2 =l copy R7
	%isel.46 =l addr S0
	%abi.3 =l add %isel.46, 0
	storel %abi.2, %abi.3
	%isel.45 =l addr S0
	%rb1 =l add %isel.45, 1
	%isel.44 =l addr S0
	%rb4 =l add %isel.44, 4
	%w0b =w loadsb S0
	%w1b =w loadsb %rb1
	%sb =s load %rb4
	%db =d exts %sb
	%abi.1 =l cast %db
	R10 =l copy %abi.1
	R9 =w copy %w1b
	R8 =w copy %w0b
	%isel.43 =l copy $fmtb
	R7 =l copy %isel.43
	call $printf, 0041
	%ib =w copy R7
	ret0
}

