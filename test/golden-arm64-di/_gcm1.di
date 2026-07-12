**** Function ifmv ****
> After instruction selection:
function $ifmv() {
@start
	%p3 =w copy R3
	%p2 =w copy R2
	%p1 =w copy R1
	acmpw %p1, 0
	jfine @true, @false
@true
	%rt.1 =w add %p2, %p3
	jmp @exit
@false
	%rf.2 =w sub %p2, %p3
@exit
	%r.3 =w phi @false %rf.2, @true %rt.1
	R1 =w copy %r.3
	ret0 0001
}

**** Function hoist1 ****
> After instruction selection:
function $hoist1() {
@start
	%p3 =w copy R3
	%p2 =w copy R2
	%p1 =w copy R1
@loop
	%i.8 =w phi @start %p1, @loop %i.11
	%n.9 =w phi @start 0, @loop %n.12
	%isel.14 =w copy 1
	%i.11 =w sub %i.8, %isel.14
	%isel.13 =w copy 1
	%n.12 =w add %n.9, %isel.13
	acmpw %i.11, 0
	jfine @loop, @exit
@exit
	%base.10 =w add %p2, %p3
	%r =w add %base.10, %n.12
	R1 =w copy %r
	ret0 0001
}

**** Function hoist2 ****
> After instruction selection:
function $hoist2() {
@start
	%p3 =w copy R3
	%p2 =w copy R2
	%p1 =w copy R1
	%base.19 =w add %p2, %p3
@loop
	%i.17 =w phi @start %p1, @loop %i.20
	%n.18 =w phi @start 0, @loop %n.21
	%isel.22 =w copy 1
	%i.20 =w sub %i.17, %isel.22
	%n.21 =w add %n.18, %base.19
	acmpw %i.20, 0
	jfine @loop, @exit
@exit
	%r =w add %base.19, %n.21
	R1 =w copy %r
	ret0 0001
}

