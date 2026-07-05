**** Function main ****
> After slot promotion:
function $main() {
@start
	%pthr =l alloc8 8
	%rval =l alloc8 8
	argl %pthr
	argl 0
	argl $thread
	argl 0
	call $pthread_create
	%t =l load %pthr
	argl %t
	argl %rval
	call $pthread_join
	%i0 =w loadsw thread $i
	argl $fmti
	argv
	argw 0
	argw %i0
	call $printf
	%i1 =w load %rval
	argl $fmti
	argv
	argw 1
	argw %i1
	call $printf
	%a0 =l call $xaddr
	%x0 =w load %a0
	argl $fmtx
	argv
	argw 0
	argw %x0
	call $printf
	%a4 =l call $xaddroff4
	%x4 =w load %a4
	argl $fmtx
	argv
	argw 4
	argw %x4
	call $printf
	argl 8
	%a8 =l call $xaddroff
	%x8 =w load %a8
	argl $fmtx
	argv
	argw 8
	argw %x8
	call $printf
	argl 3
	%xc =l call $xvalcnt
	argl $fmtx
	argv
	argw 12
	argw %xc
	call $printf
	retw 0
}

> After load elimination:
function $main() {
@start
	%pthr =l alloc8 8
	%rval =l alloc8 8
	argl %pthr
	argl 0
	argl $thread
	argl 0
	call $pthread_create
	%t =l load %pthr
	argl %t
	argl %rval
	call $pthread_join
	%i0 =w loadsw thread $i
	argl $fmti
	argv
	argw 0
	argw %i0
	call $printf
	%i1 =w load %rval
	argl $fmti
	argv
	argw 1
	argw %i1
	call $printf
	%a0 =l call $xaddr
	%x0 =w load %a0
	argl $fmtx
	argv
	argw 0
	argw %x0
	call $printf
	%a4 =l call $xaddroff4
	%x4 =w load %a4
	argl $fmtx
	argv
	argw 4
	argw %x4
	call $printf
	argl 8
	%a8 =l call $xaddroff
	%x8 =w load %a8
	argl $fmtx
	argv
	argw 8
	argw %x8
	call $printf
	argl 3
	%xc =l call $xvalcnt
	argl $fmtx
	argv
	argw 12
	argw %xc
	call $printf
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start
	%pthr =l alloc8 8
	%rval =l alloc8 8
	argl %pthr
	argl 0
	argl $thread
	argl 0
	call $pthread_create
	%t =l load %pthr
	argl %t
	argl %rval
	call $pthread_join
	%i0 =w loadsw thread $i
	argl $fmti
	argv
	argw 0
	argw %i0
	call $printf
	%i1 =w load %rval
	argl $fmti
	argv
	argw 1
	argw %i1
	call $printf
	%a0 =l call $xaddr
	%x0 =w load %a0
	argl $fmtx
	argv
	argw 0
	argw %x0
	call $printf
	%a4 =l call $xaddroff4
	%x4 =w load %a4
	argl $fmtx
	argv
	argw 4
	argw %x4
	call $printf
	argl 8
	%a8 =l call $xaddroff
	%x8 =w load %a8
	argl $fmtx
	argv
	argw 8
	argw %x8
	call $printf
	argl 3
	%xc =l call $xvalcnt
	argl $fmtx
	argv
	argw 12
	argw %xc
	call $printf
	retw 0
}

**** Function thread ****
> After slot promotion:
function $thread() {
@start
	%arg =l par
	%i3 =l add thread $i, 3
	storeb 24, %i3
	%ret =l loadsw thread $i
	retl %ret
}

> After load elimination:
function $thread() {
@start
	%arg =l par
	%i3 =l add thread $i, 3
	storeb 24, %i3
	%ret =l loadsw thread $i
	retl %ret
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $thread() {
@start
	%arg =l par
	%i3 =l add thread $i, 3
	storeb 24, %i3
	%ret =l loadsw thread $i
	retl %ret
}

**** Function xaddr ****
> After slot promotion:
function $xaddr() {
@start
	retl thread $x
}

> After load elimination:
function $xaddr() {
@start
	retl thread $x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $xaddr() {
@start
	retl thread $x
}

**** Function xaddroff4 ****
> After slot promotion:
function $xaddroff4() {
@start
	%a =l add 4, thread $x
	retl %a
}

> After load elimination:
function $xaddroff4() {
@start
	%a =l add 4, thread $x
	retl %a
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $xaddroff4() {
@start
	%a =l add 4, thread $x
	retl %a
}

**** Function xaddroff ****
> After slot promotion:
function $xaddroff() {
@start
	%off =l par
	%a =l add thread $x, %off
	retl %a
}

> After load elimination:
function $xaddroff() {
@start
	%off =l par
	%a =l add thread $x, %off
	retl %a
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $xaddroff() {
@start
	%off =l par
	%a =l add thread $x, %off
	retl %a
}

**** Function xvalcnt ****
> After slot promotion:
function $xvalcnt() {
@start
	%cnt =l par
	%o =l mul 4, %cnt
	%a =l add thread $x, %o
	%x =w load %a
	retw %x
}

> After load elimination:
function $xvalcnt() {
@start
	%cnt =l par
	%o =l mul 4, %cnt
	%a =l add thread $x, %o
	%x =w load %a
	retw %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $xvalcnt() {
@start
	%cnt =l par
	%o =l mul 4, %cnt
	%a =l add thread $x, %o
	%x =w load %a
	retw %x
}

