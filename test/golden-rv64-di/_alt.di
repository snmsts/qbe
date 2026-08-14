**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =w copy 100
	%isel.1 =w copy 0
@loop
	%alt =w phi @start %isel.1, @left %alt1, @right %alt1
	%cnt =w phi @start %isel.2, @left %cnt, @right %cnt1
	%isel.4 =w copy 1
	%alt1 =w sub %isel.4, %alt
	%isel.3 =w copy 10
	jnz %alt1, @right, @left
@left
	%x =w phi @loop %isel.3, @left %x1
	%isel.5 =w copy 1
	%x1 =w sub %x, %isel.5
	jnz %x, @left, @loop
@right
	%isel.6 =w copy 10
	%cnt1 =w sub %cnt, %isel.6
	jnz %cnt1, @loop, @end
@end
	ret0
}

