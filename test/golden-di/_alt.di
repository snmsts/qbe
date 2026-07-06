**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%alt =w phi @start 0, @left %alt1, @right %alt1
	%cnt =w phi @start 100, @left %cnt, @right %cnt1
	%alt1 =w sub 1, %alt
	jfine @right, @left
@left
	%x =w phi @loop 10, @left %x1
	%x1 =w sub %x, 1
	xcmpw 0, %x
	jfine @left, @loop
@right
	%cnt1 =w sub %cnt, 10
	jfine @loop, @end
@end
	ret0
}

