**** Function f ****
> After instruction selection:
function $f() {
@start
	%cond =w copy R5
	storew 0, [S0]
	xcmpw 0, %cond
	%isel.2 =l addr S1
	%isel.1 =l addr S0
	%ptr =l xseline %isel.1, %isel.2
@end
	storew 1, [%ptr]
	%result =w loadsw [S0]
	R1 =w copy %result
	ret0 0001
}

