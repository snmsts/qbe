**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.61 =l copy 0
	R4 =l copy %isel.61
	%isel.60 =l copy $thread
	R3 =l copy %isel.60
	%isel.59 =l copy 0
	R2 =l copy %isel.59
	%isel.58 =l addr S0
	R1 =l copy %isel.58
	call $pthread_create, 0081
	copy R1
	%isel.57 =l addr S0
	%t =l load %isel.57
	%isel.56 =l addr S2
	R2 =l copy %isel.56
	R1 =l copy %t
	call $pthread_join, 0041
	copy R1
	%isel.55 =l copy thread $i
	%isel.54 =l load %isel.55
	R1 =l copy %isel.55
	call %isel.54, 0021
	%isel.53 =l copy R1
	%i0 =w loadsw %isel.53
	%isel.52 =l copy 16
	R32 =l sub R32, %isel.52
	%isel.51 =l copy 8
	%abi.12 =l add R32, %isel.51
	storew %i0, %abi.12
	%isel.50 =l copy 0
	%abi.11 =l add R32, %isel.50
	%isel.49 =w copy 0
	storew %isel.49, %abi.11
	%isel.48 =l copy $fmti
	R1 =l copy %isel.48
	call $printf, 0021
	copy R1
	%isel.47 =l copy 16
	R32 =l add R32, %isel.47
	%isel.46 =l addr S2
	%i1 =w load %isel.46
	%isel.45 =l copy 16
	R32 =l sub R32, %isel.45
	%isel.44 =l copy 8
	%abi.10 =l add R32, %isel.44
	storew %i1, %abi.10
	%isel.43 =l copy 0
	%abi.9 =l add R32, %isel.43
	%isel.42 =w copy 1
	storew %isel.42, %abi.9
	%isel.41 =l copy $fmti
	R1 =l copy %isel.41
	call $printf, 0021
	copy R1
	%isel.40 =l copy 16
	R32 =l add R32, %isel.40
	call $xaddr, 0001
	%a0 =l copy R1
	%x0 =w load %a0
	%isel.39 =l copy 16
	R32 =l sub R32, %isel.39
	%isel.38 =l copy 8
	%abi.8 =l add R32, %isel.38
	storew %x0, %abi.8
	%isel.37 =l copy 0
	%abi.7 =l add R32, %isel.37
	%isel.36 =w copy 0
	storew %isel.36, %abi.7
	%isel.35 =l copy $fmtx
	R1 =l copy %isel.35
	call $printf, 0021
	copy R1
	%isel.34 =l copy 16
	R32 =l add R32, %isel.34
	call $xaddroff4, 0001
	%a4 =l copy R1
	%x4 =w load %a4
	%isel.33 =l copy 16
	R32 =l sub R32, %isel.33
	%isel.32 =l copy 8
	%abi.6 =l add R32, %isel.32
	storew %x4, %abi.6
	%isel.31 =l copy 0
	%abi.5 =l add R32, %isel.31
	%isel.30 =w copy 4
	storew %isel.30, %abi.5
	%isel.29 =l copy $fmtx
	R1 =l copy %isel.29
	call $printf, 0021
	copy R1
	%isel.28 =l copy 16
	R32 =l add R32, %isel.28
	%isel.27 =l copy 8
	R1 =l copy %isel.27
	call $xaddroff, 0021
	%a8 =l copy R1
	%x8 =w load %a8
	%isel.26 =l copy 16
	R32 =l sub R32, %isel.26
	%isel.25 =l copy 8
	%abi.4 =l add R32, %isel.25
	storew %x8, %abi.4
	%isel.24 =l copy 0
	%abi.3 =l add R32, %isel.24
	%isel.23 =w copy 8
	storew %isel.23, %abi.3
	%isel.22 =l copy $fmtx
	R1 =l copy %isel.22
	call $printf, 0021
	copy R1
	%isel.21 =l copy 16
	R32 =l add R32, %isel.21
	%isel.20 =l copy 3
	R1 =l copy %isel.20
	call $xvalcnt, 0021
	%xc =l copy R1
	%isel.19 =l copy 16
	R32 =l sub R32, %isel.19
	%isel.18 =l copy 8
	%abi.2 =l add R32, %isel.18
	storew %xc, %abi.2
	%isel.17 =l copy 0
	%abi.1 =l add R32, %isel.17
	%isel.16 =w copy 12
	storew %isel.16, %abi.1
	%isel.15 =l copy $fmtx
	R1 =l copy %isel.15
	call $printf, 0021
	copy R1
	%isel.14 =l copy 16
	R32 =l add R32, %isel.14
	%isel.13 =w copy 0
	R1 =w copy %isel.13
	ret0 0001
}

**** Function thread ****
> After instruction selection:
function $thread() {
@start
	%arg =l copy R1
	%isel.70 =l copy thread $i
	%isel.69 =l load %isel.70
	R1 =l copy %isel.70
	call %isel.69, 0021
	%isel.68 =l copy R1
	%isel.67 =l add %isel.68, 3
	%isel.66 =w copy 24
	storeb %isel.66, %isel.67
	%isel.65 =l copy thread $i
	%isel.64 =l load %isel.65
	R1 =l copy %isel.65
	call %isel.64, 0021
	%isel.63 =l copy R1
	%ret =l loadsw %isel.63
	R1 =l copy %ret
	ret0 0001
}

**** Function xaddr ****
> After instruction selection:
function $xaddr() {
@start
	%isel.73 =l copy thread $x
	%isel.72 =l load %isel.73
	R1 =l copy %isel.73
	call %isel.72, 0021
	%isel.71 =l copy R1
	R1 =l copy %isel.71
	ret0 0001
}

**** Function xaddroff4 ****
> After instruction selection:
function $xaddroff4() {
@start
	%isel.77 =l copy thread $x
	%isel.76 =l load %isel.77
	R1 =l copy %isel.77
	call %isel.76, 0021
	%isel.75 =l copy R1
	%isel.74 =l add %isel.75, 4
	R1 =l copy %isel.74
	ret0 0001
}

**** Function xaddroff ****
> After instruction selection:
function $xaddroff() {
@start
	%off =l copy R1
	%isel.80 =l copy thread $x
	%isel.79 =l load %isel.80
	R1 =l copy %isel.80
	call %isel.79, 0021
	%isel.78 =l copy R1
	%a =l add %off, %isel.78
	R1 =l copy %a
	ret0 0001
}

**** Function xvalcnt ****
> After instruction selection:
function $xvalcnt() {
@start
	%cnt =l copy R1
	%isel.84 =l copy 4
	%o =l mul %cnt, %isel.84
	%isel.83 =l copy thread $x
	%isel.82 =l load %isel.83
	R1 =l copy %isel.83
	call %isel.82, 0021
	%isel.81 =l copy R1
	%a =l add %o, %isel.81
	%x =w load %a
	R1 =w copy %x
	ret0 0001
}

