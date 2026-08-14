**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.21 =l copy 0
	R10 =l copy %isel.21
	%isel.20 =l copy $thread
	R9 =l copy %isel.20
	%isel.19 =l copy 0
	R8 =l copy %isel.19
	%isel.18 =l addr S0
	R7 =l copy %isel.18
	call $pthread_create, 0041
	copy R7
	%t =l load S0
	%isel.17 =l addr S2
	R8 =l copy %isel.17
	R7 =l copy %t
	call $pthread_join, 0021
	copy R7
	%i0 =w loadsw thread $i
	R9 =w copy %i0
	%isel.16 =w copy 0
	R8 =w copy %isel.16
	%isel.15 =l copy $fmti
	R7 =l copy %isel.15
	call $printf, 0031
	copy R7
	%i1 =w load S2
	R9 =w copy %i1
	%isel.14 =w copy 1
	R8 =w copy %isel.14
	%isel.13 =l copy $fmti
	R7 =l copy %isel.13
	call $printf, 0031
	copy R7
	call $xaddr, 0001
	%a0 =l copy R7
	%x0 =w load %a0
	R9 =w copy %x0
	%isel.12 =w copy 0
	R8 =w copy %isel.12
	%isel.11 =l copy $fmtx
	R7 =l copy %isel.11
	call $printf, 0031
	copy R7
	call $xaddroff4, 0001
	%a4 =l copy R7
	%x4 =w load %a4
	R9 =w copy %x4
	%isel.10 =w copy 4
	R8 =w copy %isel.10
	%isel.9 =l copy $fmtx
	R7 =l copy %isel.9
	call $printf, 0031
	copy R7
	%isel.8 =l copy 8
	R7 =l copy %isel.8
	call $xaddroff, 0011
	%a8 =l copy R7
	%x8 =w load %a8
	R9 =w copy %x8
	%isel.7 =w copy 8
	R8 =w copy %isel.7
	%isel.6 =l copy $fmtx
	R7 =l copy %isel.6
	call $printf, 0031
	copy R7
	%isel.5 =l copy 3
	R7 =l copy %isel.5
	call $xvalcnt, 0011
	%xc =l copy R7
	%isel.4 =l extsw %xc
	R9 =w copy %isel.4
	%isel.3 =w copy 12
	R8 =w copy %isel.3
	%isel.2 =l copy $fmtx
	R7 =l copy %isel.2
	call $printf, 0031
	copy R7
	%isel.1 =w copy 0
	R7 =w copy %isel.1
	ret0 0001
}

**** Function thread ****
> After instruction selection:
function $thread() {
@start
	%arg =l copy R7
	%isel.23 =w copy 24
	storeb %isel.23, thread $i+3
	%ret =l loadsw thread $i
	R7 =l copy %ret
	ret0 0001
}

**** Function xaddr ****
> After instruction selection:
function $xaddr() {
@start
	%isel.24 =l copy thread $x
	R7 =l copy %isel.24
	ret0 0001
}

**** Function xaddroff4 ****
> After instruction selection:
function $xaddroff4() {
@start
	%isel.25 =l copy thread $x+4
	R7 =l copy %isel.25
	ret0 0001
}

**** Function xaddroff ****
> After instruction selection:
function $xaddroff() {
@start
	%off =l copy R7
	%isel.26 =l copy thread $x
	%a =l add %off, %isel.26
	R7 =l copy %a
	ret0 0001
}

**** Function xvalcnt ****
> After instruction selection:
function $xvalcnt() {
@start
	%cnt =l copy R7
	%isel.28 =l copy 4
	%o =l mul %cnt, %isel.28
	%isel.27 =l copy thread $x
	%a =l add %o, %isel.27
	%x =w load %a
	R7 =w copy %x
	ret0 0001
}

