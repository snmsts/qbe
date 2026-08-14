**** Function test ****
> After instruction selection:
function $test() {
@start
	%c =w copy R7
	%isel.4 =w copy 1
	%cmp.1 =w cultl %isel.4, %c
	jnz %cmp.1, @yes, @no
@yes
	%isel.5 =w copy 1
@no
	%cmp.2 =w phi @start %cmp.1, @yes %isel.5
	R7 =w copy %cmp.2
	ret0 0001
}

