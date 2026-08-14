**** Function lt ****
> After instruction selection:
function $lt() {
@start
	%y =d copy R43
	%x =d copy R42
	%r =w cltd %x, %y
	R7 =w copy %r
	ret0 0001
}

**** Function le ****
> After instruction selection:
function $le() {
@start
	%y =d copy R43
	%x =d copy R42
	%r =w cled %x, %y
	R7 =w copy %r
	ret0 0001
}

**** Function gt ****
> After instruction selection:
function $gt() {
@start
	%y =d copy R43
	%x =d copy R42
	%r =w cgtd %x, %y
	R7 =w copy %r
	ret0 0001
}

**** Function ge ****
> After instruction selection:
function $ge() {
@start
	%y =d copy R43
	%x =d copy R42
	%r =w cged %x, %y
	R7 =w copy %r
	ret0 0001
}

**** Function eq1 ****
> After instruction selection:
function $eq1() {
@start
	%y =d copy R43
	%x =d copy R42
	%r =w ceqd %x, %y
	R7 =w copy %r
	ret0 0001
}

**** Function eq2 ****
> After instruction selection:
function $eq2() {
@start
	%y =d copy R43
	%x =d copy R42
	%r =w ceqd %x, %y
	jnz %r, @true, @false
@true
	%isel.1 =w copy 1
	R7 =w copy %isel.1
	ret0 0001
@false
	%isel.2 =w copy 0
	R7 =w copy %isel.2
	ret0 0001
}

**** Function eq3 ****
> After instruction selection:
function $eq3() {
@start
	%y =d copy R43
	%x =d copy R42
	%r =w ceqd %x, %y
	jnz %r, @true, @false
@true
	%snk.3 =w ceqd %x, %y
	R7 =w copy %snk.3
	ret0 0001
@false
	%isel.4 =w copy 0
	R7 =w copy %isel.4
	ret0 0001
}

**** Function ne1 ****
> After instruction selection:
function $ne1() {
@start
	%y =d copy R43
	%x =d copy R42
	%isel.5 =w ceqd %x, %y
	%r =w xor %isel.5, 1
	R7 =w copy %r
	ret0 0001
}

**** Function ne2 ****
> After instruction selection:
function $ne2() {
@start
	%y =d copy R43
	%x =d copy R42
	%isel.6 =w ceqd %x, %y
	%r =w xor %isel.6, 1
	jnz %r, @true, @false
@true
	%isel.7 =w copy 1
	R7 =w copy %isel.7
	ret0 0001
@false
	%isel.8 =w copy 0
	R7 =w copy %isel.8
	ret0 0001
}

**** Function ne3 ****
> After instruction selection:
function $ne3() {
@start
	%y =d copy R43
	%x =d copy R42
	%isel.10 =w ceqd %x, %y
	%r =w xor %isel.10, 1
	jnz %r, @true, @false
@true
	%isel.11 =w ceqd %x, %y
	%snk.9 =w xor %isel.11, 1
	R7 =w copy %snk.9
	ret0 0001
@false
	%isel.12 =w copy 0
	R7 =w copy %isel.12
	ret0 0001
}

**** Function o ****
> After instruction selection:
function $o() {
@start
	%y =d copy R43
	%x =d copy R42
	%isel.14 =w ceqd %y, %y
	%isel.13 =w ceqd %x, %x
	%r =w and %isel.13, %isel.14
	R7 =w copy %r
	ret0 0001
}

**** Function uo ****
> After instruction selection:
function $uo() {
@start
	%y =d copy R43
	%x =d copy R42
	%isel.17 =w ceqd %y, %y
	%isel.16 =w ceqd %x, %x
	%isel.15 =w and %isel.16, %isel.17
	%r =w xor %isel.15, 1
	R7 =w copy %r
	ret0 0001
}

