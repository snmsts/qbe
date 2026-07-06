**** Function lt ****
> After instruction selection:
function $lt() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %x, %y
	%r =w flagfgt
	R1 =w copy %r
	ret0 0001
}

**** Function le ****
> After instruction selection:
function $le() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %x, %y
	%r =w flagfge
	R1 =w copy %r
	ret0 0001
}

**** Function gt ****
> After instruction selection:
function $gt() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%r =w flagfgt
	R1 =w copy %r
	ret0 0001
}

**** Function ge ****
> After instruction selection:
function $ge() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%r =w flagfge
	R1 =w copy %r
	ret0 0001
}

**** Function eq1 ****
> After instruction selection:
function $eq1() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%isel.1 =w flagfeq
	%isel.2 =w flagfo
	%r =w and %isel.1, %isel.2
	R1 =w copy %r
	ret0 0001
}

**** Function eq2 ****
> After instruction selection:
function $eq2() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%isel.3 =w flagfeq
	%isel.4 =w flagfo
	%r =w and %isel.3, %isel.4
	copy %r
	jfine @true, @false
@true
	R1 =w copy 1
	ret0 0001
@false
	R1 =w copy 0
	ret0 0001
}

**** Function eq3 ****
> After instruction selection:
function $eq3() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%isel.6 =w flagfeq
	%isel.7 =w flagfo
	%r =w and %isel.6, %isel.7
	copy %r
	jfine @true, @false
@true
	xcmpd %y, %x
	%isel.8 =w flagfeq
	%isel.9 =w flagfo
	%snk.5 =w and %isel.8, %isel.9
	R1 =w copy %snk.5
	ret0 0001
@false
	R1 =w copy 0
	ret0 0001
}

**** Function ne1 ****
> After instruction selection:
function $ne1() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%isel.10 =w flagfne
	%isel.11 =w flagfuo
	%r =w or %isel.10, %isel.11
	R1 =w copy %r
	ret0 0001
}

**** Function ne2 ****
> After instruction selection:
function $ne2() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%isel.12 =w flagfne
	%isel.13 =w flagfuo
	%r =w or %isel.12, %isel.13
	copy %r
	jfine @true, @false
@true
	R1 =w copy 1
	ret0 0001
@false
	R1 =w copy 0
	ret0 0001
}

**** Function ne3 ****
> After instruction selection:
function $ne3() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%isel.15 =w flagfne
	%isel.16 =w flagfuo
	%r =w or %isel.15, %isel.16
	copy %r
	jfine @true, @false
@true
	xcmpd %y, %x
	%isel.17 =w flagfne
	%isel.18 =w flagfuo
	%snk.14 =w or %isel.17, %isel.18
	R1 =w copy %snk.14
	ret0 0001
@false
	R1 =w copy 0
	ret0 0001
}

**** Function o ****
> After instruction selection:
function $o() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%r =w flagfo
	R1 =w copy %r
	ret0 0001
}

**** Function uo ****
> After instruction selection:
function $uo() {
@start
	%y =d copy R18
	%x =d copy R17
	xcmpd %y, %x
	%r =w flagfuo
	R1 =w copy %r
	ret0 0001
}

