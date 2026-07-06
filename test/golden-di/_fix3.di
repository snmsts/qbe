**** Function test ****
> After instruction selection:
function $test() {
@start
@l
	%s.3 =w phi @start 0, @c %s.5
	%x.4 =w phi @start 100, @c %x.7
	xcmpw 10, %x.4
	%c =w flagisle
	%s.9 =w add %s.3, %x.4
	%x.10 =w sub %x.4, 1
	%s.8 =w sub %s.3, %x.4
	xcmpw 0, %c
	%s.5 =w xseline %s.9, %s.8
	%x.6 =w xseline %x.10, %x.4
@c
	%x.7 =w sub %x.6, 1
	jfine @l, @end
@end
	R1 =w copy %s.5
	ret0 0001
}

