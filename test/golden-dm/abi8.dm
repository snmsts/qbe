**** Function qfn0 ****
> After slot promotion:
function $qfn0() {
@start
	%p0 =s par
	%p1 =s par
	%p2 =s par
	%p3 =s par
	%p4 =s par
	%p5 =s par
	%p6 =s par
	%p7 =s par
	%p8 =s par
	argl $ctoqbestr
	argv
	argw 0
	%r0 =w call $printf
	args %p8
	call $ps
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn0() {
@start
	%p0 =s par
	%p1 =s par
	%p2 =s par
	%p3 =s par
	%p4 =s par
	%p5 =s par
	%p6 =s par
	%p7 =s par
	%p8 =s par
	argl $ctoqbestr
	argv
	argw 0
	%r0 =w call $printf
	args %p8
	call $ps
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn0() {
@start
	%p0 =s par
	%p1 =s par
	%p2 =s par
	%p3 =s par
	%p4 =s par
	%p5 =s par
	%p6 =s par
	%p7 =s par
	%p8 =s par
	argl $ctoqbestr
	argv
	argw 0
	%r0 =w call $printf
	args %p8
	call $ps
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn1 ****
> After slot promotion:
function $qfn1() {
@start
	%p0 =w par
	%p1 =s par
	%p2 =l parc :fi1
	argl $ctoqbestr
	argv
	argw 1
	%r0 =w call $printf
	argw %p0
	call $pw
	args %p1
	call $ps
	argl %p2
	call $pfi1
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn1() {
@start
	%p0 =w par
	%p1 =s par
	%p2 =l parc :fi1
	argl $ctoqbestr
	argv
	argw 1
	%r0 =w call $printf
	argw %p0
	call $pw
	args %p1
	call $ps
	argl %p2
	call $pfi1
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn1() {
@start
	%p0 =w par
	%p1 =s par
	%p2 =l parc :fi1
	argl $ctoqbestr
	argv
	argw 1
	%r0 =w call $printf
	argw %p0
	call $pw
	args %p1
	call $ps
	argl %p2
	call $pfi1
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn2 ****
> After slot promotion:
function $qfn2() {
@start
	%p0 =w par
	%p1 =l parc :fi2
	%p2 =s par
	argl $ctoqbestr
	argv
	argw 2
	%r0 =w call $printf
	argw %p0
	call $pw
	argl %p1
	call $pfi2
	args %p2
	call $ps
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn2() {
@start
	%p0 =w par
	%p1 =l parc :fi2
	%p2 =s par
	argl $ctoqbestr
	argv
	argw 2
	%r0 =w call $printf
	argw %p0
	call $pw
	argl %p1
	call $pfi2
	args %p2
	call $ps
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn2() {
@start
	%p0 =w par
	%p1 =l parc :fi2
	%p2 =s par
	argl $ctoqbestr
	argv
	argw 2
	%r0 =w call $printf
	argw %p0
	call $pw
	argl %p1
	call $pfi2
	args %p2
	call $ps
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn3 ****
> After slot promotion:
function $qfn3() {
@start
	%p0 =w par
	%p1 =s par
	%p2 =l parc :fi3
	argl $ctoqbestr
	argv
	argw 3
	%r0 =w call $printf
	argw %p0
	call $pw
	args %p1
	call $ps
	argl %p2
	call $pfi3
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn3() {
@start
	%p0 =w par
	%p1 =s par
	%p2 =l parc :fi3
	argl $ctoqbestr
	argv
	argw 3
	%r0 =w call $printf
	argw %p0
	call $pw
	args %p1
	call $ps
	argl %p2
	call $pfi3
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn3() {
@start
	%p0 =w par
	%p1 =s par
	%p2 =l parc :fi3
	argl $ctoqbestr
	argv
	argw 3
	%r0 =w call $printf
	argw %p0
	call $pw
	args %p1
	call $ps
	argl %p2
	call $pfi3
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn4 ****
> After slot promotion:
function $qfn4() {
@start
	%p0 =l parc :ss
	argl $ctoqbestr
	argv
	argw 4
	%r0 =w call $printf
	argl %p0
	call $pss
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn4() {
@start
	%p0 =l parc :ss
	argl $ctoqbestr
	argv
	argw 4
	%r0 =w call $printf
	argl %p0
	call $pss
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn4() {
@start
	%p0 =l parc :ss
	argl $ctoqbestr
	argv
	argw 4
	%r0 =w call $printf
	argl %p0
	call $pss
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn5 ****
> After slot promotion:
function $qfn5() {
@start
	%p0 =d par
	%p1 =d par
	%p2 =d par
	%p3 =d par
	%p4 =d par
	%p5 =d par
	%p6 =d par
	%p7 =l parc :ss
	%p8 =s par
	%p9 =l par
	argl $ctoqbestr
	argv
	argw 5
	%r0 =w call $printf
	argl %p7
	call $pss
	args %p8
	call $ps
	argl %p9
	call $pl
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn5() {
@start
	%p0 =d par
	%p1 =d par
	%p2 =d par
	%p3 =d par
	%p4 =d par
	%p5 =d par
	%p6 =d par
	%p7 =l parc :ss
	%p8 =s par
	%p9 =l par
	argl $ctoqbestr
	argv
	argw 5
	%r0 =w call $printf
	argl %p7
	call $pss
	args %p8
	call $ps
	argl %p9
	call $pl
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn5() {
@start
	%p0 =d par
	%p1 =d par
	%p2 =d par
	%p3 =d par
	%p4 =d par
	%p5 =d par
	%p6 =d par
	%p7 =l parc :ss
	%p8 =s par
	%p9 =l par
	argl $ctoqbestr
	argv
	argw 5
	%r0 =w call $printf
	argl %p7
	call $pss
	args %p8
	call $ps
	argl %p9
	call $pl
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn6 ****
> After slot promotion:
function $qfn6() {
@start
	%p0 =l parc :lb
	argl $ctoqbestr
	argv
	argw 6
	%r0 =w call $printf
	argl %p0
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn6() {
@start
	%p0 =l parc :lb
	argl $ctoqbestr
	argv
	argw 6
	%r0 =w call $printf
	argl %p0
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn6() {
@start
	%p0 =l parc :lb
	argl $ctoqbestr
	argv
	argw 6
	%r0 =w call $printf
	argl %p0
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn7 ****
> After slot promotion:
function $qfn7() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =l parc :lb
	argl $ctoqbestr
	argv
	argw 7
	%r0 =w call $printf
	argl %p7
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn7() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =l parc :lb
	argl $ctoqbestr
	argv
	argw 7
	%r0 =w call $printf
	argl %p7
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn7() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =l parc :lb
	argl $ctoqbestr
	argv
	argw 7
	%r0 =w call $printf
	argl %p7
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn8 ****
> After slot promotion:
function $qfn8() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =w par
	%p8 =l parc :lb
	argl $ctoqbestr
	argv
	argw 8
	%r0 =w call $printf
	argl %p8
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn8() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =w par
	%p8 =l parc :lb
	argl $ctoqbestr
	argv
	argw 8
	%r0 =w call $printf
	argl %p8
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn8() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =w par
	%p8 =l parc :lb
	argl $ctoqbestr
	argv
	argw 8
	%r0 =w call $printf
	argl %p8
	call $plb
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn9 ****
> After slot promotion:
function $qfn9() {
@start
	%p0 =l parc :big
	argl $ctoqbestr
	argv
	argw 9
	%r0 =w call $printf
	argl %p0
	call $pbig
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn9() {
@start
	%p0 =l parc :big
	argl $ctoqbestr
	argv
	argw 9
	%r0 =w call $printf
	argl %p0
	call $pbig
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn9() {
@start
	%p0 =l parc :big
	argl $ctoqbestr
	argv
	argw 9
	%r0 =w call $printf
	argl %p0
	call $pbig
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn10 ****
> After slot promotion:
function $qfn10() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =w par
	%p8 =l parc :big
	%p9 =s par
	%p10 =l par
	argl $ctoqbestr
	argv
	argw 10
	%r0 =w call $printf
	argl %p8
	call $pbig
	args %p9
	call $ps
	argl %p10
	call $pl
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn10() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =w par
	%p8 =l parc :big
	%p9 =s par
	%p10 =l par
	argl $ctoqbestr
	argv
	argw 10
	%r0 =w call $printf
	argl %p8
	call $pbig
	args %p9
	call $ps
	argl %p10
	call $pl
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn10() {
@start
	%p0 =w par
	%p1 =w par
	%p2 =w par
	%p3 =w par
	%p4 =w par
	%p5 =w par
	%p6 =w par
	%p7 =w par
	%p8 =l parc :big
	%p9 =s par
	%p10 =l par
	argl $ctoqbestr
	argv
	argw 10
	%r0 =w call $printf
	argl %p8
	call $pbig
	args %p9
	call $ps
	argl %p10
	call $pl
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function qfn11 ****
> After slot promotion:
function $qfn11() {
@start
	%p0 =l parc :ddd
	argl $ctoqbestr
	argv
	argw 11
	%r0 =w call $printf
	argl %p0
	call $pddd
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> After load elimination:
function $qfn11() {
@start
	%p0 =l parc :ddd
	argl $ctoqbestr
	argv
	argw 11
	%r0 =w call $printf
	argl %p0
	call $pddd
	argl $emptystr
	%r1 =w call $puts
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $qfn11() {
@start
	%p0 =l parc :ddd
	argl $ctoqbestr
	argv
	argw 11
	%r0 =w call $printf
	argl %p0
	call $pddd
	argl $emptystr
	%r1 =w call $puts
	ret0
}

**** Function main ****
> After slot promotion:
function $main() {
@start
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args s_9.900000
	call $cfn0
	argw 1
	args s_2.200000
	argc :fi1, $fi1
	call $cfn1
	argw 1
	argc :fi2, $fi2
	args s_3.300000
	call $cfn2
	argw 1
	args s_2.200000
	argc :fi3, $fi3
	call $cfn3
	argc :ss, $ss
	call $cfn4
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argc :ss, $ss
	args s_9.900000
	argl 10
	call $cfn5
	argc :lb, $lb
	call $cfn6
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :lb, $lb
	call $cfn7
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :lb, $lb
	call $cfn8
	argc :big, $big
	call $cfn9
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :big, $big
	args s_10.100000
	argl 11
	call $cfn10
	argc :ddd, $ddd
	call $cfn11
	retw 0
}

> After load elimination:
function $main() {
@start
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args s_9.900000
	call $cfn0
	argw 1
	args s_2.200000
	argc :fi1, $fi1
	call $cfn1
	argw 1
	argc :fi2, $fi2
	args s_3.300000
	call $cfn2
	argw 1
	args s_2.200000
	argc :fi3, $fi3
	call $cfn3
	argc :ss, $ss
	call $cfn4
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argc :ss, $ss
	args s_9.900000
	argl 10
	call $cfn5
	argc :lb, $lb
	call $cfn6
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :lb, $lb
	call $cfn7
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :lb, $lb
	call $cfn8
	argc :big, $big
	call $cfn9
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :big, $big
	args s_10.100000
	argl 11
	call $cfn10
	argc :ddd, $ddd
	call $cfn11
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args 0
	args s_9.900000
	call $cfn0
	argw 1
	args s_2.200000
	argc :fi1, $fi1
	call $cfn1
	argw 1
	argc :fi2, $fi2
	args s_3.300000
	call $cfn2
	argw 1
	args s_2.200000
	argc :fi3, $fi3
	call $cfn3
	argc :ss, $ss
	call $cfn4
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argd 0
	argc :ss, $ss
	args s_9.900000
	argl 10
	call $cfn5
	argc :lb, $lb
	call $cfn6
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :lb, $lb
	call $cfn7
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :lb, $lb
	call $cfn8
	argc :big, $big
	call $cfn9
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argw 0
	argc :big, $big
	args s_10.100000
	argl 11
	call $cfn10
	argc :ddd, $ddd
	call $cfn11
	retw 0
}

