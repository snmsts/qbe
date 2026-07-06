**** Function strspn_ ****
> After instruction selection:
function $strspn_() {
@.64
	%s2.82.val =l copy R4
	%s1.81.val =l copy R5
	jmp @.27
@.28
	jmp @.29
@.30
	%.41 =l add %p.85.8, 1
@.29
	%p.85.8 =l phi @.28 %s2.82.val, @.30 %.41
	%.44 =w loadsb [%p.85.8]
	xcmpw 0, %.44
	jfine @.42, @.36
@.42
	xcmpw %.60, %.44
	jfine @.30, @.36
@.36
	xcmpw 0, %.44
	jfine @.33, @.37
@.37
	jmp @.34
@.33
	%.57 =w add %n.83.3, 1
	%.59 =l add %s1.81.4, 1
@.27
	%n.83.3 =w phi @.64 0, @.33 %.57
	%s1.81.4 =l phi @.64 %s1.81.val, @.33 %.59
	%.60 =w loadsb [%s1.81.4]
	xcmpw 0, %.60
	jfine @.28, @.38
@.38
@.34
	R1 =w copy %n.83.3
	ret0 0001
}

