**** Function sum ****
> After instruction selection:
function $sum() {
@start
	%num =w copy R8
	%arr =l copy R7
	%isel.1 =w copy 0
@loop
	%n1 =w phi @start %num, @loop1 %n2
	%s0 =w phi @start %isel.1, @loop1 %s1
	%isel.3 =w copy 0
	%isel.2 =w csltl %isel.3, %n1
	%c =w xor %isel.2, 1
	jnz %c, @end, @loop1
@loop1
	%isel.5 =w copy 1
	%n2 =w sub %n1, %isel.5
	%idx0 =l extsw %n2
	%isel.4 =l copy 4
	%idx1 =l mul %idx0, %isel.4
	%idx2 =l add %arr, %idx1
	%w =w loadsw %idx2
	%s1 =w add %s0, %w
	jmp @loop
@end
	R7 =w copy %s0
	ret0 0001
}

