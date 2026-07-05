**** Function strcmp ****
> After slot promotion:
function $strcmp() {
@.37
	%s1.3.val =l par
	%s2.5.val =l par
	nop
	nop
	%s1.3 =l copy %s1.3.val
	%s2.5 =l copy %s2.5.val
	jmp @.5
@.6
	%.9 =l copy %s1.3
	%.10 =l add %.9, 1
	%s1.3 =l copy %.10
	%.11 =l copy %s2.5
	%.12 =l add %.11, 1
	%s2.5 =l copy %.12
@.5
	%.15 =l copy %s1.3
	%.16 =w loadsb %.15
	%.17 =w extsb %.16
	%.18 =w cnew %.17, 0
	jnz %.18, @.14, @.8
@.14
	%.19 =l copy %s2.5
	%.20 =w loadsb %.19
	%.21 =w extsb %.20
	%.22 =w cnew %.21, 0
	jnz %.22, @.13, @.8
@.13
	%.23 =l copy %s1.3
	%.24 =w loadsb %.23
	%.25 =w extsb %.24
	%.26 =l copy %s2.5
	%.27 =w loadsb %.26
	%.28 =w extsb %.27
	%.29 =w ceqw %.25, %.28
	jnz %.29, @.6, @.8
@.8
@.7
	%.30 =l copy %s1.3
	%.31 =w loadub %.30
	%.32 =w extub %.31
	%.33 =l copy %s2.5
	%.34 =w loadub %.33
	%.35 =w extub %.34
	%.36 =w sub %.32, %.35
	retw %.36
}

> After load elimination:
function $strcmp() {
@.37
	%s1.3.val =l par
	%s2.5.val =l par
	nop
	nop
	%s1.3.1 =l copy %s1.3.val
	%s2.5.2 =l copy %s2.5.val
	jmp @.5
@.6
	%.9 =l copy %s1.3.4
	%.10 =l add %.9, 1
	%s1.3.5 =l copy %.10
	%.11 =l copy %s2.5.3
	%.12 =l add %.11, 1
	%s2.5.6 =l copy %.12
@.5
	%s2.5.3 =l phi @.37 %s2.5.2, @.6 %s2.5.6
	%s1.3.4 =l phi @.37 %s1.3.1, @.6 %s1.3.5
	%.15 =l copy %s1.3.4
	%.16 =w loadsb %.15
	%.17 =w extsb %.16
	%.18 =w cnew %.17, 0
	jnz %.18, @.14, @.8
@.14
	%.19 =l copy %s2.5.3
	%.20 =w loadsb %.19
	%.21 =w extsb %.20
	%.22 =w cnew %.21, 0
	jnz %.22, @.13, @.8
@.13
	%.23 =l copy %s1.3.4
	%.24 =w extsb %.16
	%.25 =w extsb %.24
	%.26 =l copy %s2.5.3
	%.27 =w extsb %.20
	%.28 =w extsb %.27
	%.29 =w ceqw %.25, %.28
	jnz %.29, @.6, @.8
@.8
	%ld.7 =w phi @.5 %.16, @.14 %.16, @.13 %.24
@.7
	%.30 =l copy %s1.3.4
	%.31 =w extub %ld.7
	%.32 =w extub %.31
	%.33 =l copy %s2.5.3
	%.34 =w loadub %.33
	%.35 =w extub %.34
	%.36 =w sub %.32, %.35
	retw %.36
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $strcmp() {
@.37
	%s1.3.val =l par
	%s2.5.val =l par
	nop
	nop
	%s1.3.1 =l copy %s1.3.val
	%s2.5.2 =l copy %s2.5.val
	jmp @.5
@.6
	%.9 =l copy %s1.3.4
	%.10 =l add %.9, 1
	%s1.3.5 =l copy %.10
	%.11 =l copy %s2.5.3
	%.12 =l add %.11, 1
	%s2.5.6 =l copy %.12
@.5
	%s2.5.3 =l phi @.37 %s2.5.2, @.6 %s2.5.6
	%s1.3.4 =l phi @.37 %s1.3.1, @.6 %s1.3.5
	%.15 =l copy %s1.3.4
	%.16 =w loadsb %.15
	%.17 =w extsb %.16
	%.18 =w cnew %.17, 0
	jnz %.18, @.14, @.8
@.14
	%.19 =l copy %s2.5.3
	%.20 =w loadsb %.19
	%.21 =w extsb %.20
	%.22 =w cnew %.21, 0
	jnz %.22, @.13, @.8
@.13
	%.23 =l copy %s1.3.4
	%.24 =w extsb %.16
	%.25 =w extsb %.24
	%.26 =l copy %s2.5.3
	%.27 =w extsb %.20
	%.28 =w extsb %.27
	%.29 =w ceqw %.25, %.28
	jnz %.29, @.6, @.8
@.8
	%ld.7 =w phi @.5 %.16, @.14 %.16, @.13 %.24
@.7
	%.30 =l copy %s1.3.4
	%.31 =w extub %ld.7
	%.32 =w extub %.31
	%.33 =l copy %s2.5.3
	%.34 =w loadub %.33
	%.35 =w extub %.34
	%.36 =w sub %.32, %.35
	retw %.36
}

