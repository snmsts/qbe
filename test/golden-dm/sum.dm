**** Function sum ****
> After slot promotion:
function $sum() {
@start
	%arr =l par
	%num =w par
@loop
	%n1 =w phi @start %num, @loop1 %n2
	%s0 =w phi @start 0, @loop1 %s1
	%n2 =w sub %n1, 1
	%c =w cslew %n1, 0
	jnz %c, @end, @loop1
@loop1
	%idx0 =l extsw %n2
	%idx1 =l mul 4, %idx0
	%idx2 =l add %idx1, %arr
	%w =w loadsw %idx2
	%s1 =w add %w, %s0
	jmp @loop
@end
	retw %s0
}

> After load elimination:
function $sum() {
@start
	%arr =l par
	%num =w par
@loop
	%n1 =w phi @start %num, @loop1 %n2
	%s0 =w phi @start 0, @loop1 %s1
	%n2 =w sub %n1, 1
	%c =w cslew %n1, 0
	jnz %c, @end, @loop1
@loop1
	%idx0 =l extsw %n2
	%idx1 =l mul 4, %idx0
	%idx2 =l add %idx1, %arr
	%w =w loadsw %idx2
	%s1 =w add %w, %s0
	jmp @loop
@end
	retw %s0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $sum() {
@start
	%arr =l par
	%num =w par
@loop
	%n1 =w phi @start %num, @loop1 %n2
	%s0 =w phi @start 0, @loop1 %s1
	%n2 =w sub %n1, 1
	%c =w cslew %n1, 0
	jnz %c, @end, @loop1
@loop1
	%idx0 =l extsw %n2
	%idx1 =l mul 4, %idx0
	%idx2 =l add %idx1, %arr
	%w =w loadsw %idx2
	%s1 =w add %w, %s0
	jmp @loop
@end
	retw %s0
}

