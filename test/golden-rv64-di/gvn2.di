**** Function test ****
> After instruction selection:
function $test() {
@start
	%c =w copy R7
	jnz %c, @yes, @no
@yes
	%isel.6 =w copy 1
	jmp @end
@no
	%isel.7 =w copy 0
@end
	%rc.1 =w phi @no %isel.7, @yes %isel.6
	R7 =w copy %rc.1
	ret0 0001
}

