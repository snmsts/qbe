**** Function test ****
> After instruction selection:
function $test() {
@start
	%c =w copy R5
	xcmpw 1, %c
	%cmp.1 =w flagiugt
	%isel.4 =w copy 1
	%cmp.2 =w xseliugt %isel.4, %cmp.1
@no
	R1 =w copy %cmp.2
	ret0 0001
}

