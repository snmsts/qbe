**** Function strcmp ****
> After instruction selection:
function $strcmp() {
@.37
	%s2.5.val =l copy R2
	%s1.3.val =l copy R1
	jmp @.5
@.6
	%isel.10 =l copy 1
	%.10 =l add %s1.3.4, %isel.10
	%isel.9 =l copy 1
	%.12 =l add %s2.5.3, %isel.9
@.5
	%s2.5.3 =l phi @.37 %s2.5.val, @.6 %.12
	%s1.3.4 =l phi @.37 %s1.3.val, @.6 %.10
	%.16 =w loadsb %s1.3.4
	acmpw %.16, 0
	jfine @.14, @.8
@.14
	%.20 =w loadsb %s2.5.3
	acmpw %.20, 0
	jfine @.13, @.8
@.13
	acmpw %.16, %.20
	jfieq @.6, @.8
@.8
	%.32 =w extub %.16
	%.34 =w loadub %s2.5.3
	%.36 =w sub %.32, %.34
	R1 =w copy %.36
	ret0 0001
}

