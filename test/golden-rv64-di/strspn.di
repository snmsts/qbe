**** Function strspn_ ****
> After instruction selection:
function $strspn_() {
@.64
	%s2.82.val =l copy R8
	%s1.81.val =l copy R7
	%isel.13 =w copy 0
	jmp @.27
@.28
	jmp @.29
@.30
	%.41 =l add %p.85.8, 1
@.29
	%p.85.8 =l phi @.28 %s2.82.val, @.30 %.41
	%.44 =w loadsb %p.85.8
	%isel.14 =w xor %.44, 0
	%.46 =w rnez %isel.14
	jnz %.46, @.42, @.36
@.42
	%isel.15 =w xor %.44, %.60
	%.51 =w rnez %isel.15
	jnz %.51, @.30, @.36
@.36
	%isel.16 =w xor %.44, 0
	%snk.12 =w rnez %isel.16
	jnz %snk.12, @.33, @.37
@.37
	jmp @.34
@.33
	%.57 =w add %n.83.3, 1
	%.59 =l add %s1.81.4, 1
@.27
	%n.83.3 =w phi @.64 %isel.13, @.33 %.57
	%s1.81.4 =l phi @.64 %s1.81.val, @.33 %.59
	%.60 =w loadsb %s1.81.4
	%isel.17 =w xor %.60, 0
	%.62 =w rnez %isel.17
	jnz %.62, @.28, @.38
@.38
@.34
	R7 =w copy %n.83.3
	ret0 0001
}

