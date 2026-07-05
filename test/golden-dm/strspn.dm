**** Function strspn_ ****
> After slot promotion:
function $strspn_() {
@.64
	%s1.81.val =l par
	%s2.82.val =l par
	nop
	nop
	nop
	nop
	nop
	%s1.81 =l copy %s1.81.val
	%s2.82 =l copy %s2.82.val
	%n.83 =w copy 0
	jmp @.27
@.28
	%.39 =l copy %s2.82
	%p.85 =l copy %.39
	jmp @.29
@.30
@.31
	%.40 =l copy %p.85
	%.41 =l add %.40, 1
	%p.85 =l copy %.41
@.29
	%.43 =l copy %p.85
	%.44 =w loadsb %.43
	%.45 =w extsb %.44
	%.46 =w cnew %.45, 0
	jnz %.46, @.42, @.36
@.42
	%.47 =l copy %p.85
	%.48 =w loadsb %.47
	%.49 =w extsb %.48
	%.50 =w copy %c.84
	%.51 =w cnew %.49, %.50
	jnz %.51, @.30, @.36
@.36
@.32
	%.52 =l copy %p.85
	%.53 =w loadsb %.52
	%.54 =w extsb %.53
	%.55 =w cnew %.54, 0
	jnz %.55, @.33, @.37
@.37
	jmp @.34
@.33
@.35
	%.56 =w copy %n.83
	%.57 =w add %.56, 1
	%n.83 =w copy %.57
@.27
	%.58 =l copy %s1.81
	%.59 =l add %.58, 1
	%s1.81 =l copy %.59
	%.60 =w loadsb %.58
	%.61 =w extsb %.60
	%c.84 =w copy %.61
	%.62 =w cnew %.61, 0
	jnz %.62, @.28, @.38
@.38
@.34
	%.63 =w copy %n.83
	retw %.63
}

> After load elimination:
function $strspn_() {
@.64
	%s1.81.val =l par
	%s2.82.val =l par
	nop
	nop
	nop
	nop
	nop
	%s1.81.1 =l copy %s1.81.val
	%s2.82 =l copy %s2.82.val
	%n.83.2 =w copy 0
	jmp @.27
@.28
	%.39 =l copy %s2.82
	%p.85.7 =l copy %.39
	jmp @.29
@.30
@.31
	%.40 =l copy %p.85.8
	%.41 =l add %.40, 1
	%p.85.10 =l copy %.41
@.29
	%p.85.8 =l phi @.28 %p.85.7, @.31 %p.85.10
	%.43 =l copy %p.85.8
	%.44 =w loadsb %.43
	%.45 =w extsb %.44
	%.46 =w cnew %.45, 0
	jnz %.46, @.42, @.36
@.42
	%.47 =l copy %p.85.8
	%.48 =w extsb %.44
	%.49 =w extsb %.48
	%.50 =w copy %c.84.6
	%.51 =w cnew %.49, %.50
	jnz %.51, @.30, @.36
@.36
	%ld.11 =w phi @.29 %.44, @.42 %.48
@.32
	%.52 =l copy %p.85.8
	%.53 =w extsb %ld.11
	%.54 =w extsb %.53
	%.55 =w cnew %.54, 0
	jnz %.55, @.33, @.37
@.37
	jmp @.34
@.33
@.35
	%.56 =w copy %n.83.3
	%.57 =w add %.56, 1
	%n.83.9 =w copy %.57
@.27
	%n.83.3 =w phi @.64 %n.83.2, @.35 %n.83.9
	%s1.81.4 =l phi @.64 %s1.81.1, @.35 %s1.81.5
	%.58 =l copy %s1.81.4
	%.59 =l add %.58, 1
	%s1.81.5 =l copy %.59
	%.60 =w loadsb %.58
	%.61 =w extsb %.60
	%c.84.6 =w copy %.61
	%.62 =w cnew %.61, 0
	jnz %.62, @.28, @.38
@.38
@.34
	%.63 =w copy %n.83.3
	retw %.63
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $strspn_() {
@.64
	%s1.81.val =l par
	%s2.82.val =l par
	nop
	nop
	nop
	nop
	nop
	%s1.81.1 =l copy %s1.81.val
	%s2.82 =l copy %s2.82.val
	%n.83.2 =w copy 0
	jmp @.27
@.28
	%.39 =l copy %s2.82
	%p.85.7 =l copy %.39
	jmp @.29
@.30
@.31
	%.40 =l copy %p.85.8
	%.41 =l add %.40, 1
	%p.85.10 =l copy %.41
@.29
	%p.85.8 =l phi @.28 %p.85.7, @.31 %p.85.10
	%.43 =l copy %p.85.8
	%.44 =w loadsb %.43
	%.45 =w extsb %.44
	%.46 =w cnew %.45, 0
	jnz %.46, @.42, @.36
@.42
	%.47 =l copy %p.85.8
	%.48 =w extsb %.44
	%.49 =w extsb %.48
	%.50 =w copy %c.84.6
	%.51 =w cnew %.49, %.50
	jnz %.51, @.30, @.36
@.36
	%ld.11 =w phi @.29 %.44, @.42 %.48
@.32
	%.52 =l copy %p.85.8
	%.53 =w extsb %ld.11
	%.54 =w extsb %.53
	%.55 =w cnew %.54, 0
	jnz %.55, @.33, @.37
@.37
	jmp @.34
@.33
@.35
	%.56 =w copy %n.83.3
	%.57 =w add %.56, 1
	%n.83.9 =w copy %.57
@.27
	%n.83.3 =w phi @.64 %n.83.2, @.35 %n.83.9
	%s1.81.4 =l phi @.64 %s1.81.1, @.35 %s1.81.5
	%.58 =l copy %s1.81.4
	%.59 =l add %.58, 1
	%s1.81.5 =l copy %.59
	%.60 =w loadsb %.58
	%.61 =w extsb %.60
	%c.84.6 =w copy %.61
	%.62 =w cnew %.61, 0
	jnz %.62, @.28, @.38
@.38
@.34
	%.63 =w copy %n.83.3
	retw %.63
}

