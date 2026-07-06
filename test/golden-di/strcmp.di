**** Function strcmp ****
> After instruction selection:
function $strcmp() {
@.37
	%s2.5.val =l copy R4
	%s1.3.val =l copy R5
	jmp @.5
@.6
	%.10 =l add %s1.3.4, 1
	%.12 =l add %s2.5.3, 1
@.5
	%s2.5.3 =l phi @.37 %s2.5.val, @.6 %.12
	%s1.3.4 =l phi @.37 %s1.3.val, @.6 %.10
	%.16 =w loadsb [%s1.3.4]
	xcmpw 0, %.16
	jfine @.14, @.8
@.14
	%.20 =w loadsb [%s2.5.3]
	xcmpw 0, %.20
	jfine @.13, @.8
@.13
	xcmpw %.20, %.16
	jfieq @.6, @.8
@.8
	%.32 =w extub %.16
	%.34 =w loadub [%s2.5.3]
	%.36 =w sub %.32, %.34
	R1 =w copy %.36
	ret0 0001
}

