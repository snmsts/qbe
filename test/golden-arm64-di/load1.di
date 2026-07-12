**** Function f ****
> After instruction selection:
function $f() {
@start
	%cond =w copy R1
	%isel.2 =l addr S0
	%isel.1 =w copy 0
	storew %isel.1, %isel.2
	acmpw %cond, 0
	jfine @true, @false
@true
	%isel.3 =l addr S0
	jmp @end
@false
	%isel.4 =l addr S1
@end
	%ptr =l phi @true %isel.3, @false %isel.4
	%isel.6 =w copy 1
	storew %isel.6, %ptr
	%isel.5 =l addr S0
	%result =w loadsw %isel.5
	R1 =w copy %result
	ret0 0001
}

