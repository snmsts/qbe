**** Function sum ****
> After instruction selection:
function $sum() {
@start
	%num =w copy R4
	%arr =l copy R5
@loop
	%n1 =w phi @start %num, @loop1 %n2
	%s0 =w phi @start 0, @loop1 %s1
	xcmpw 0, %n1
	jfisle @end, @loop1
@loop1
	%n2 =w sub %n1, 1
	%idx0 =l extsw %n2
	%w =w loadsw [%arr + 4 * %idx0]
	%s1 =w add %s0, %w
	jmp @loop
@end
	R1 =w copy %s0
	ret0 0001
}

