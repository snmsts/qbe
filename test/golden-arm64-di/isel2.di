**** Function lt ****
> After instruction selection:
function $lt() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	%r =w flagflt
	R1 =w copy %r
	ret0 0001
}

**** Function le ****
> After instruction selection:
function $le() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	%r =w flagfle
	R1 =w copy %r
	ret0 0001
}

**** Function gt ****
> After instruction selection:
function $gt() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	%r =w flagfgt
	R1 =w copy %r
	ret0 0001
}

**** Function ge ****
> After instruction selection:
function $ge() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	%r =w flagfge
	R1 =w copy %r
	ret0 0001
}

**** Function eq1 ****
> After instruction selection:
function $eq1() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	%r =w flagfeq
	R1 =w copy %r
	ret0 0001
}

**** Function eq2 ****
> After instruction selection:
function $eq2() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	jffeq @true, @false
@true
	%isel.1 =w copy 1
	R1 =w copy %isel.1
	ret0 0001
@false
	%isel.2 =w copy 0
	R1 =w copy %isel.2
	ret0 0001
}

**** Function eq3 ****
> After instruction selection:
function $eq3() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	jffeq @true, @false
@true
	afcmpd %x, %y
	%snk.3 =w flagfeq
	R1 =w copy %snk.3
	ret0 0001
@false
	%isel.4 =w copy 0
	R1 =w copy %isel.4
	ret0 0001
}

**** Function ne1 ****
> After instruction selection:
function $ne1() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	%r =w flagfne
	R1 =w copy %r
	ret0 0001
}

**** Function ne2 ****
> After instruction selection:
function $ne2() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	jffne @true, @false
@true
	%isel.5 =w copy 1
	R1 =w copy %isel.5
	ret0 0001
@false
	%isel.6 =w copy 0
	R1 =w copy %isel.6
	ret0 0001
}

**** Function ne3 ****
> After instruction selection:
function $ne3() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	jffne @true, @false
@true
	afcmpd %x, %y
	%snk.7 =w flagfne
	R1 =w copy %snk.7
	ret0 0001
@false
	%isel.8 =w copy 0
	R1 =w copy %isel.8
	ret0 0001
}

**** Function o ****
> After instruction selection:
function $o() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	%r =w flagfo
	R1 =w copy %r
	ret0 0001
}

**** Function uo ****
> After instruction selection:
function $uo() {
@start
	%y =d copy R34
	%x =d copy R33
	afcmpd %x, %y
	%r =w flagfuo
	R1 =w copy %r
	ret0 0001
}

