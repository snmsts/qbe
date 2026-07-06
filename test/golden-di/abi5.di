**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.34 =l addr S18
	R5 =l copy %isel.34
	call $t1, 0011
	%r1 =l copy R1
	R4 =l copy %r1
	%isel.33 =l addr $fmt1
	R5 =l copy %isel.33
	R1 =w copy 0
	call $printf, 1021
	%i1 =w copy R1
	call $t2, 0001
	%abi.20 =l copy R1
	storel %abi.20, [S16]
	%w2 =w loadsw [S16]
	R4 =w copy %w2
	%isel.32 =l addr $fmt2
	R5 =l copy %isel.32
	R1 =w copy 0
	call $printf, 1021
	%i2 =w copy R1
	call $t3, 0001
	%abi.19 =l copy R1
	storel %abi.19, [S14]
	%s3 =s load [S14]
	%w3 =w loadsw [4 + S14]
	%p3 =d exts %s3
	R4 =w copy %w3
	R17 =d copy %p3
	%isel.31 =l addr $fmt3
	R5 =l copy %isel.31
	R1 =w copy 1
	call $printf, 1121
	%i3 =w copy R1
	call $t4, 0005
	%abi.18 =l copy R1
	%abi.17 =d copy R17
	storel %abi.18, [S32]
	storel %abi.17, [8 + S32]
	%w4 =w loadsw [S32]
	%d4 =d load [8 + S32]
	R17 =d copy %d4
	R4 =w copy %w4
	%isel.30 =l addr $fmt4
	R5 =l copy %isel.30
	R1 =w copy 1
	call $printf, 1121
	%i4 =w copy R1
	call $t5, 0005
	%abi.15 =d copy R17
	%abi.14 =l copy R1
	storel %abi.15, [S28]
	storel %abi.14, [8 + S28]
	%s5 =s load [S28]
	%d5 =d exts %s5
	%l5 =l load [8 + S28]
	R4 =l copy %l5
	R17 =d copy %d5
	%isel.29 =l addr $fmt5
	R5 =l copy %isel.29
	R1 =w copy 1
	call $printf, 1121
	%i5 =w copy R1
	call $t6, 0002
	%abi.12 =l copy R1
	%abi.11 =l copy R3
	storel %abi.12, [S10]
	storel %abi.11, [8 + S10]
	%isel.28 =l addr S10
	R4 =l copy %isel.28
	%isel.27 =l addr $fmt6
	R5 =l copy %isel.27
	R1 =w copy 0
	call $printf, 1021
	%i6 =w copy R1
	call $t7, 0008
	%abi.9 =d copy R17
	%abi.8 =d copy R18
	storel %abi.9, [S24]
	storel %abi.8, [8 + S24]
	%s7 =s load [S24]
	%d71 =d exts %s7
	%d72 =d load [8 + S24]
	R18 =d copy %d72
	R17 =d copy %d71
	%isel.26 =l addr $fmt7
	R5 =l copy %isel.26
	R1 =w copy 2
	call $printf, 1211
	%i7 =w copy R1
	call $t8, 0002
	%abi.6 =l copy R1
	%abi.5 =l copy R3
	storel %abi.6, [S6]
	storel %abi.5, [8 + S6]
	%w81 =w loadsw [S6]
	%w82 =w loadsw [4 + S6]
	%w83 =w loadsw [8 + S6]
	%w84 =w loadsw [12 + S6]
	R6 =w copy %w84
	R2 =w copy %w83
	R3 =w copy %w82
	R4 =w copy %w81
	%isel.25 =l addr $fmt8
	R5 =l copy %isel.25
	R1 =w copy 0
	call $printf, 1051
	%i8 =w copy R1
	call $t9, 0001
	%abi.3 =l copy R1
	storel %abi.3, [S4]
	%w9 =w loadsw [S4]
	%s9 =s load [4 + S4]
	%d9 =d exts %s9
	R17 =d copy %d9
	R4 =w copy %w9
	%isel.24 =l addr $fmt9
	R5 =l copy %isel.24
	R1 =w copy 1
	call $printf, 1121
	%i9 =w copy R1
	call $ta, 0001
	%abi.2 =l copy R1
	storel %abi.2, [S2]
	%wa =w loadsb [S2]
	%sa =s load [4 + S2]
	%da =d exts %sa
	R17 =d copy %da
	R4 =w copy %wa
	%isel.23 =l addr $fmta
	R5 =l copy %isel.23
	R1 =w copy 1
	call $printf, 1121
	%ia =w copy R1
	call $tb, 0001
	%abi.1 =l copy R1
	storel %abi.1, [S0]
	%w0b =w loadsb [S0]
	%w1b =w loadsb [1 + S0]
	%sb =s load [4 + S0]
	%db =d exts %sb
	R17 =d copy %db
	R3 =w copy %w1b
	R4 =w copy %w0b
	%isel.22 =l addr $fmtb
	R5 =l copy %isel.22
	R1 =w copy 1
	call $printf, 1131
	%ib =w copy R1
	ret0
}

