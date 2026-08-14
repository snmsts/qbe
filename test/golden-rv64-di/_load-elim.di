**** Function f ****
> After instruction selection:
function $f() {
@start
	%c =w copy R8
	%p =l copy R7
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%isel.1 =w copy 0
	R7 =w copy %isel.1
	ret0 0001
}

