**** Function f ****
> After instruction selection:
function $f() {
@start
	%p =l copy R8
	%n.1 =w copy R7
	%isel.8 =w copy 0
@loop
	%r.3 =w phi @start %isel.8, @loop1 %r.6
	%n.4 =w phi @start %n.1, @loop1 %n.5
	%isel.10 =w copy 1
	%n.5 =w sub %n.4, %isel.10
	%isel.9 =w csltl %n.5, 0
	%c =w xor %isel.9, 1
	jnz %c, @loop1, @end
@loop1
	%r.6 =w loadsw %p
	jmp @loop
@end
	R7 =w copy %r.3
	ret0 0001
}

