**** Function qfn0 ****
> After instruction selection:
function $qfn0() {
@start
	%p8 =s load S-4
	%p7 =s copy R24
	%p6 =s copy R23
	%p5 =s copy R22
	%p4 =s copy R21
	%p3 =s copy R20
	%p2 =s copy R19
	%p1 =s copy R18
	%p0 =s copy R17
	R4 =w copy 0
	%isel.2 =l addr $ctoqbestr
	R5 =l copy %isel.2
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	R17 =s copy %p8
	call $ps, 0101
	copy R1
	%isel.1 =l addr $emptystr
	R5 =l copy %isel.1
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn1 ****
> After instruction selection:
function $qfn1() {
@start
	%abi.3 =l copy R4
	%p1 =s copy R17
	%p0 =w copy R5
	storel %abi.3, [S0]
	R4 =w copy 1
	%isel.6 =l addr $ctoqbestr
	R5 =l copy %isel.6
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	R5 =w copy %p0
	call $pw, 0011
	copy R1
	R17 =s copy %p1
	call $ps, 0101
	copy R1
	%isel.5 =l addr S0
	R5 =l copy %isel.5
	call $pfi1, 0011
	copy R1
	%isel.4 =l addr $emptystr
	R5 =l copy %isel.4
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn2 ****
> After instruction selection:
function $qfn2() {
@start
	%p2 =s copy R17
	%abi.7 =l copy R4
	%p0 =w copy R5
	storel %abi.7, [S0]
	R4 =w copy 2
	%isel.10 =l addr $ctoqbestr
	R5 =l copy %isel.10
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	R5 =w copy %p0
	call $pw, 0011
	copy R1
	%isel.9 =l addr S0
	R5 =l copy %isel.9
	call $pfi2, 0011
	copy R1
	R17 =s copy %p2
	call $ps, 0101
	copy R1
	%isel.8 =l addr $emptystr
	R5 =l copy %isel.8
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn3 ****
> After instruction selection:
function $qfn3() {
@start
	%abi.11 =l copy R4
	%p1 =s copy R17
	%p0 =w copy R5
	storel %abi.11, [S0]
	R4 =w copy 3
	%isel.14 =l addr $ctoqbestr
	R5 =l copy %isel.14
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	R5 =w copy %p0
	call $pw, 0011
	copy R1
	R17 =s copy %p1
	call $ps, 0101
	copy R1
	%isel.13 =l addr S0
	R5 =l copy %isel.13
	call $pfi3, 0011
	copy R1
	%isel.12 =l addr $emptystr
	R5 =l copy %isel.12
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn4 ****
> After instruction selection:
function $qfn4() {
@start
	%abi.15 =d copy R17
	storel %abi.15, [S0]
	R4 =w copy 4
	%isel.18 =l addr $ctoqbestr
	R5 =l copy %isel.18
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	%isel.17 =l addr S0
	R5 =l copy %isel.17
	call $pss, 0011
	copy R1
	%isel.16 =l addr $emptystr
	R5 =l copy %isel.16
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn5 ****
> After instruction selection:
function $qfn5() {
@start
	%p9 =l copy R5
	%p8 =s load S-4
	%abi.19 =d copy R24
	%p6 =d copy R23
	%p5 =d copy R22
	%p4 =d copy R21
	%p3 =d copy R20
	%p2 =d copy R19
	%p1 =d copy R18
	%p0 =d copy R17
	storel %abi.19, [S0]
	R4 =w copy 5
	%isel.22 =l addr $ctoqbestr
	R5 =l copy %isel.22
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	%isel.21 =l addr S0
	R5 =l copy %isel.21
	call $pss, 0011
	copy R1
	R17 =s copy %p8
	call $ps, 0101
	copy R1
	R5 =l copy %p9
	call $pl, 0011
	copy R1
	%isel.20 =l addr $emptystr
	R5 =l copy %isel.20
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn6 ****
> After instruction selection:
function $qfn6() {
@start
	%abi.24 =l copy R4
	%abi.25 =l copy R5
	storel %abi.25, [S0]
	storel %abi.24, [8 + S0]
	R4 =w copy 6
	%isel.28 =l addr $ctoqbestr
	R5 =l copy %isel.28
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	%isel.27 =l addr S0
	R5 =l copy %isel.27
	call $plb, 0011
	copy R1
	%isel.26 =l addr $emptystr
	R5 =l copy %isel.26
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn7 ****
> After instruction selection:
function $qfn7() {
@start
	%p5 =w copy R7
	%p4 =w copy R6
	%p3 =w copy R2
	%p2 =w copy R3
	%p1 =w copy R4
	%p0 =w copy R5
	R4 =w copy 7
	%isel.31 =l addr $ctoqbestr
	R5 =l copy %isel.31
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	%isel.30 =l addr S-6
	R5 =l copy %isel.30
	call $plb, 0011
	copy R1
	%isel.29 =l addr $emptystr
	R5 =l copy %isel.29
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn8 ****
> After instruction selection:
function $qfn8() {
@start
	%p5 =w copy R7
	%p4 =w copy R6
	%p3 =w copy R2
	%p2 =w copy R3
	%p1 =w copy R4
	%p0 =w copy R5
	R4 =w copy 8
	%isel.34 =l addr $ctoqbestr
	R5 =l copy %isel.34
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	%isel.33 =l addr S-8
	R5 =l copy %isel.33
	call $plb, 0011
	copy R1
	%isel.32 =l addr $emptystr
	R5 =l copy %isel.32
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn9 ****
> After instruction selection:
function $qfn9() {
@start
	R4 =w copy 9
	%isel.37 =l addr $ctoqbestr
	R5 =l copy %isel.37
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	%isel.36 =l addr S-4
	R5 =l copy %isel.36
	call $pbig, 0011
	copy R1
	%isel.35 =l addr $emptystr
	R5 =l copy %isel.35
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn10 ****
> After instruction selection:
function $qfn10() {
@start
	%p10 =l load S-14
	%p9 =s copy R17
	%p5 =w copy R7
	%p4 =w copy R6
	%p3 =w copy R2
	%p2 =w copy R3
	%p1 =w copy R4
	%p0 =w copy R5
	R4 =w copy 10
	%isel.40 =l addr $ctoqbestr
	R5 =l copy %isel.40
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	%isel.39 =l addr S-8
	R5 =l copy %isel.39
	call $pbig, 0011
	copy R1
	R17 =s copy %p9
	call $ps, 0101
	copy R1
	R5 =l copy %p10
	call $pl, 0011
	copy R1
	%isel.38 =l addr $emptystr
	R5 =l copy %isel.38
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function qfn11 ****
> After instruction selection:
function $qfn11() {
@start
	R4 =w copy 11
	%isel.43 =l addr $ctoqbestr
	R5 =l copy %isel.43
	R1 =w copy 0
	call $printf, 1021
	%r0 =w copy R1
	%isel.42 =l addr S-4
	R5 =l copy %isel.42
	call $pddd, 0011
	copy R1
	%isel.41 =l addr $emptystr
	R5 =l copy %isel.41
	call $puts, 0011
	%r1 =w copy R1
	ret0
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	%abi.63 =l salloc 16
	storel s_9.900000, [0 + %abi.63]
	R24 =s copy [$".Lfp1"]
	R23 =s copy [$".Lfp1"]
	R22 =s copy [$".Lfp1"]
	R21 =s copy [$".Lfp1"]
	R20 =s copy [$".Lfp1"]
	R19 =s copy [$".Lfp1"]
	R18 =s copy [$".Lfp1"]
	R17 =s copy [$".Lfp1"]
	call $cfn0, 0801
	copy R1
	salloc -16
	R4 =l load $fi1
	R17 =s copy [$".Lfp2"]
	R5 =w copy 1
	call $cfn1, 0121
	copy R1
	R17 =s copy [$".Lfp3"]
	R4 =l load $fi2
	R5 =w copy 1
	call $cfn2, 0121
	copy R1
	R4 =l load $fi3
	R17 =s copy [$".Lfp2"]
	R5 =w copy 1
	call $cfn3, 0121
	copy R1
	R17 =d load $ss
	call $cfn4, 0101
	copy R1
	%abi.61 =l salloc 16
	storel s_9.900000, [0 + %abi.61]
	R5 =l copy 10
	R24 =d load $ss
	R23 =d copy [$".Lfp1"]
	R22 =d copy [$".Lfp1"]
	R21 =d copy [$".Lfp1"]
	R20 =d copy [$".Lfp1"]
	R19 =d copy [$".Lfp1"]
	R18 =d copy [$".Lfp1"]
	R17 =d copy [$".Lfp1"]
	call $cfn5, 0811
	copy R1
	salloc -16
	R5 =l load $lb
	%isel.117 =l addr $lb
	%abi.60 =l add %isel.117, 8
	R4 =l load [%abi.60]
	call $cfn6, 0021
	copy R1
	%abi.57 =l salloc 32
	%isel.116 =l addr $lb
	%blt.103 =l add %isel.116, 0
	%blt.101 =l load [%blt.103]
	storel %blt.101, [8 + %abi.57]
	%isel.115 =l addr $lb
	%blt.100 =l add %isel.115, 8
	%blt.98 =l load [%blt.100]
	storel %blt.98, [16 + %abi.57]
	storel 0, [0 + %abi.57]
	R7 =w copy 0
	R6 =w copy 0
	R2 =w copy 0
	R3 =w copy 0
	R4 =w copy 0
	R5 =w copy 0
	call $cfn7, 0061
	copy R1
	salloc -32
	%abi.53 =l salloc 32
	%isel.114 =l addr $lb
	%blt.97 =l add %isel.114, 0
	%blt.95 =l load [%blt.97]
	storel %blt.95, [16 + %abi.53]
	%isel.113 =l addr $lb
	%blt.94 =l add %isel.113, 8
	%blt.92 =l load [%blt.94]
	storel %blt.92, [24 + %abi.53]
	storel 0, [8 + %abi.53]
	storel 0, [0 + %abi.53]
	R7 =w copy 0
	R6 =w copy 0
	R2 =w copy 0
	R3 =w copy 0
	R4 =w copy 0
	R5 =w copy 0
	call $cfn8, 0061
	copy R1
	salloc -32
	%abi.51 =l salloc 32
	%isel.112 =l addr $big
	%blt.91 =l add %isel.112, 0
	%blt.89 =w loadub [%blt.91]
	storeb %blt.89, [0 + %abi.51]
	%isel.111 =l addr $big
	%blt.88 =l add %isel.111, 1
	%blt.86 =l load [%blt.88]
	storel %blt.86, [1 + %abi.51]
	%isel.110 =l addr $big
	%blt.85 =l add %isel.110, 9
	%blt.83 =l load [%blt.85]
	storel %blt.83, [9 + %abi.51]
	call $cfn9, 0001
	copy R1
	salloc -32
	%abi.46 =l salloc 48
	storel 11, [40 + %abi.46]
	%isel.109 =l addr $big
	%blt.82 =l add %isel.109, 0
	%blt.80 =w loadub [%blt.82]
	storeb %blt.80, [16 + %abi.46]
	%isel.108 =l addr $big
	%blt.79 =l add %isel.108, 1
	%blt.77 =l load [%blt.79]
	storel %blt.77, [17 + %abi.46]
	%isel.107 =l addr $big
	%blt.76 =l add %isel.107, 9
	%blt.74 =l load [%blt.76]
	storel %blt.74, [25 + %abi.46]
	storel 0, [8 + %abi.46]
	storel 0, [0 + %abi.46]
	R17 =s copy [$".Lfp0"]
	R7 =w copy 0
	R6 =w copy 0
	R2 =w copy 0
	R3 =w copy 0
	R4 =w copy 0
	R5 =w copy 0
	call $cfn10, 0161
	copy R1
	salloc -48
	%abi.44 =l salloc 32
	%isel.106 =l addr $ddd
	%blt.73 =l add %isel.106, 0
	%blt.71 =l load [%blt.73]
	storel %blt.71, [0 + %abi.44]
	%isel.105 =l addr $ddd
	%blt.70 =l add %isel.105, 8
	%blt.68 =l load [%blt.70]
	storel %blt.68, [8 + %abi.44]
	%isel.104 =l addr $ddd
	%blt.67 =l add %isel.104, 16
	%blt.65 =l load [%blt.67]
	storel %blt.65, [16 + %abi.44]
	call $cfn11, 0001
	copy R1
	salloc -32
	R1 =w copy 0
	ret0 0001
}

