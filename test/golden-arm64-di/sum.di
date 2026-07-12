**** Function sum ****
> After instruction selection:
function $sum() {
@start
	%num =w copy R2
	%arr =l copy R1
@loop
	%n1 =w phi @start %num, @loop1 %n2
	%s0 =w phi @start 0, @loop1 %s1
	acmpw %n1, 0
	jfisle @end, @loop1
@loop1
	%isel.2 =w copy 1
	%n2 =w sub %n1, %isel.2
	%idx0 =l extsw %n2
	%isel.1 =l copy 4
	%idx1 =l mul %idx0, %isel.1
	%idx2 =l add %arr, %idx1
	%w =w loadsw %idx2
	%s1 =w add %s0, %w
	jmp @loop
@end
	R1 =w copy %s0
	ret0 0001
}

