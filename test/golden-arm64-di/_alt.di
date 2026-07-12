**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%alt =w phi @start 0, @left %alt1, @right %alt1
	%cnt =w phi @start 100, @left %cnt, @right %cnt1
	%isel.1 =w copy 1
	%alt1 =w sub %isel.1, %alt
	acmpw %alt1, 0
	jfine @right, @left
@left
	%x =w phi @loop 10, @left %x1
	%isel.2 =w copy 1
	%x1 =w sub %x, %isel.2
	acmpw %x, 0
	jfine @left, @loop
@right
	%isel.3 =w copy 10
	%cnt1 =w sub %cnt, %isel.3
	acmpw %cnt1, 0
	jfine @loop, @end
@end
	ret0
}

