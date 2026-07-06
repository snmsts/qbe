**** Function main ****
> After instruction selection:
function $main() {
@start
	R2 =l copy 0
	%isel.9 =l addr $thread
	R3 =l copy %isel.9
	R4 =l copy 0
	%isel.8 =l addr S0
	R5 =l copy %isel.8
	call $pthread_create, 0041
	copy R1
	%t =l load [S0]
	%isel.7 =l addr S2
	R4 =l copy %isel.7
	R5 =l copy %t
	call $pthread_join, 0021
	copy R1
	%i0 =w loadsw thread $i
	R3 =w copy %i0
	R4 =w copy 0
	%isel.6 =l addr $fmti
	R5 =l copy %isel.6
	R1 =w copy 0
	call $printf, 1031
	copy R1
	%i1 =w load [S2]
	R3 =w copy %i1
	R4 =w copy 1
	%isel.5 =l addr $fmti
	R5 =l copy %isel.5
	R1 =w copy 0
	call $printf, 1031
	copy R1
	call $xaddr, 0001
	%a0 =l copy R1
	%x0 =w load [%a0]
	R3 =w copy %x0
	R4 =w copy 0
	%isel.4 =l addr $fmtx
	R5 =l copy %isel.4
	R1 =w copy 0
	call $printf, 1031
	copy R1
	call $xaddroff4, 0001
	%a4 =l copy R1
	%x4 =w load [%a4]
	R3 =w copy %x4
	R4 =w copy 4
	%isel.3 =l addr $fmtx
	R5 =l copy %isel.3
	R1 =w copy 0
	call $printf, 1031
	copy R1
	R5 =l copy 8
	call $xaddroff, 0011
	%a8 =l copy R1
	%x8 =w load [%a8]
	R3 =w copy %x8
	R4 =w copy 8
	%isel.2 =l addr $fmtx
	R5 =l copy %isel.2
	R1 =w copy 0
	call $printf, 1031
	copy R1
	R5 =l copy 3
	call $xvalcnt, 0011
	%xc =l copy R1
	R3 =w copy %xc
	R4 =w copy 12
	%isel.1 =l addr $fmtx
	R5 =l copy %isel.1
	R1 =w copy 0
	call $printf, 1031
	copy R1
	R1 =w copy 0
	ret0 0001
}

**** Function thread ****
> After instruction selection:
function $thread() {
@start
	%arg =l copy R5
	storeb 24, thread $i+3
	%ret =l loadsw thread $i
	R1 =l copy %ret
	ret0 0001
}

**** Function xaddr ****
> After instruction selection:
function $xaddr() {
@start
	%isel.11 =l addr thread $x
	R1 =l copy %isel.11
	ret0 0001
}

**** Function xaddroff4 ****
> After instruction selection:
function $xaddroff4() {
@start
	%isel.12 =l addr thread $x+4
	R1 =l copy %isel.12
	ret0 0001
}

**** Function xaddroff ****
> After instruction selection:
function $xaddroff() {
@start
	%off =l copy R5
	%isel.13 =l addr thread $x
	%a =l add %off, %isel.13
	R1 =l copy %a
	ret0 0001
}

**** Function xvalcnt ****
> After instruction selection:
function $xvalcnt() {
@start
	%cnt =l copy R5
	%isel.14 =l addr thread $x
	%x =w load [%isel.14 + 4 * %cnt]
	R1 =w copy %x
	ret0 0001
}

