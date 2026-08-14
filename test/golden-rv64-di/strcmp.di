**** Function strcmp ****
> After instruction selection:
function $strcmp() {
@.37
	%s2.5.val =l copy R8
	%s1.3.val =l copy R7
	jmp @.5
@.6
	%.10 =l add %s1.3.4, 1
	%.12 =l add %s2.5.3, 1
@.5
	%s2.5.3 =l phi @.37 %s2.5.val, @.6 %.12
	%s1.3.4 =l phi @.37 %s1.3.val, @.6 %.10
	%.16 =w loadsb %s1.3.4
	%isel.9 =w xor %.16, 0
	%.18 =w rnez %isel.9
	jnz %.18, @.14, @.8
@.14
	%.20 =w loadsb %s2.5.3
	%isel.10 =w xor %.20, 0
	%.22 =w rnez %isel.10
	jnz %.22, @.13, @.8
@.13
	%isel.11 =w xor %.16, %.20
	%.29 =w reqz %isel.11
	jnz %.29, @.6, @.8
@.8
	%.32 =w extub %.16
	%.34 =w loadub %s2.5.3
	%.36 =w sub %.32, %.34
	R7 =w copy %.36
	ret0 0001
}

