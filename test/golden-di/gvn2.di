**** Function test ****
> After instruction selection:
function $test() {
@start
	%c =w copy R5
	xcmpw 0, %c
	%isel.7 =w copy 0
	%isel.6 =w copy 1
	%rc.1 =w xseline %isel.6, %isel.7
@end
	R1 =w copy %rc.1
	ret0 0001
}

