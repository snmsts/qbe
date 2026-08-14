**** Function ifmv ****
> After instruction selection:
function $ifmv() {
@start
	%p3 =w copy R9
	%p2 =w copy R8
	%p1 =w copy R7
	jnz %p1, @true, @false
@true
	%rt.1 =w add %p2, %p3
	jmp @exit
@false
	%rf.2 =w sub %p2, %p3
@exit
	%r.3 =w phi @false %rf.2, @true %rt.1
	R7 =w copy %r.3
	ret0 0001
}

**** Function hoist1 ****
> After instruction selection:
function $hoist1() {
@start
	%p3 =w copy R9
	%p2 =w copy R8
	%p1 =w copy R7
	%isel.13 =w copy 0
@loop
	%i.8 =w phi @start %p1, @loop %i.11
	%n.9 =w phi @start %isel.13, @loop %n.12
	%isel.14 =w copy 1
	%i.11 =w sub %i.8, %isel.14
	%n.12 =w add %n.9, 1
	jnz %i.11, @loop, @exit
@exit
	%base.10 =w add %p2, %p3
	%r =w add %base.10, %n.12
	R7 =w copy %r
	ret0 0001
}

**** Function hoist2 ****
> After instruction selection:
function $hoist2() {
@start
	%p3 =w copy R9
	%p2 =w copy R8
	%p1 =w copy R7
	%base.19 =w add %p2, %p3
	%isel.22 =w copy 0
@loop
	%i.17 =w phi @start %p1, @loop %i.20
	%n.18 =w phi @start %isel.22, @loop %n.21
	%isel.23 =w copy 1
	%i.20 =w sub %i.17, %isel.23
	%n.21 =w add %n.18, %base.19
	jnz %i.20, @loop, @exit
@exit
	%r =w add %base.19, %n.21
	R7 =w copy %r
	ret0 0001
}

