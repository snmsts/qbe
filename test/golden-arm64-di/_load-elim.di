**** Function f ****
> After instruction selection:
function $f() {
@start
	%c =w copy R2
	%p =l copy R1
	acmpw %c, 0
	jfine @true, @false
@true
	jmp @end
@false
@end
	%isel.1 =w copy 0
	R1 =w copy %isel.1
	ret0 0001
}

