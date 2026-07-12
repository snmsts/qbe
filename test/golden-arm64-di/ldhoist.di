**** Function f ****
> After instruction selection:
function $f() {
@start
	%p =l copy R2
	%n.1 =w copy R1
@loop
	%r.3 =w phi @start 0, @loop1 %r.6
	%n.4 =w phi @start %n.1, @loop1 %n.5
	%isel.8 =w copy 1
	%n.5 =w sub %n.4, %isel.8
	acmpw %n.5, 0
	jfisge @loop1, @end
@loop1
	%r.6 =w loadsw %p
	jmp @loop
@end
	R1 =w copy %r.3
	ret0 0001
}

