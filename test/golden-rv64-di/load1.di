**** Function f ****
> After instruction selection:
function $f() {
@start
	%cond =w copy R7
	%isel.1 =w copy 0
	storew %isel.1, S0
	jnz %cond, @true, @false
@true
	%isel.2 =l addr S0
	jmp @end
@false
	%isel.3 =l addr S1
@end
	%ptr =l phi @true %isel.2, @false %isel.3
	%isel.4 =w copy 1
	storew %isel.4, %ptr
	%result =w loadsw S0
	R7 =w copy %result
	ret0 0001
}

