**** Function ifmv ****
> After slot promotion:
function $ifmv() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%rt =w add %p2, %p3
	%rf =w sub %p2, %p3
	jnz %p1, @true, @false
@true
	%r =w copy %rt
	jmp @exit
@false
	%r =w copy %rf
@exit
	retw %r
}

> After load elimination:
function $ifmv() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%rt.1 =w add %p2, %p3
	%rf.2 =w sub %p2, %p3
	jnz %p1, @true, @false
@true
	%r.5 =w copy %rt.1
	jmp @exit
@false
	%r.4 =w copy %rf.2
@exit
	%r.3 =w phi @false %r.4, @true %r.5
	retw %r.3
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifmv() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%rt.1 =w add %p2, %p3
	%rf.2 =w sub %p2, %p3
	jnz %p1, @true, @false
@true
	%r.5 =w copy %rt.1
	jmp @exit
@false
	%r.4 =w copy %rf.2
@exit
	%r.3 =w phi @false %r.4, @true %r.5
	retw %r.3
}

**** Function hoist1 ****
> After slot promotion:
function $hoist1() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%n =w copy 0
	%i =w copy %p1
@loop
	%base =w add %p2, %p3
	%i =w sub %i, 1
	%n =w add %n, 1
	jnz %i, @loop, @exit
@exit
	%r =w add %base, %n
	retw %r
}

> After load elimination:
function $hoist1() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%n.6 =w copy 0
	%i.7 =w copy %p1
@loop
	%i.8 =w phi @entry %i.7, @loop %i.11
	%n.9 =w phi @entry %n.6, @loop %n.12
	%base.10 =w add %p2, %p3
	%i.11 =w sub %i.8, 1
	%n.12 =w add %n.9, 1
	jnz %i.11, @loop, @exit
@exit
	%r =w add %base.10, %n.12
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $hoist1() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%n.6 =w copy 0
	%i.7 =w copy %p1
@loop
	%i.8 =w phi @entry %i.7, @loop %i.11
	%n.9 =w phi @entry %n.6, @loop %n.12
	%base.10 =w add %p2, %p3
	%i.11 =w sub %i.8, 1
	%n.12 =w add %n.9, 1
	jnz %i.11, @loop, @exit
@exit
	%r =w add %base.10, %n.12
	retw %r
}

**** Function hoist2 ****
> After slot promotion:
function $hoist2() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%n =w copy 0
	%i =w copy %p1
@loop
	%base =w add %p2, %p3
	%i =w sub %i, 1
	%n =w add %n, %base
	jnz %i, @loop, @exit
@exit
	%r =w add %base, %n
	retw %r
}

> After load elimination:
function $hoist2() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%n.13 =w copy 0
	%i.14 =w copy %p1
@loop
	%i.15 =w phi @entry %i.14, @loop %i.18
	%n.16 =w phi @entry %n.13, @loop %n.19
	%base.17 =w add %p2, %p3
	%i.18 =w sub %i.15, 1
	%n.19 =w add %n.16, %base.17
	jnz %i.18, @loop, @exit
@exit
	%r =w add %base.17, %n.19
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $hoist2() {
@start
	%p1 =w par
	%p2 =w par
	%p3 =w par
@entry
	%n.13 =w copy 0
	%i.14 =w copy %p1
@loop
	%i.15 =w phi @entry %i.14, @loop %i.18
	%n.16 =w phi @entry %n.13, @loop %n.19
	%base.17 =w add %p2, %p3
	%i.18 =w sub %i.15, 1
	%n.19 =w add %n.16, %base.17
	jnz %i.18, @loop, @exit
@exit
	%r =w add %base.17, %n.19
	retw %r
}

