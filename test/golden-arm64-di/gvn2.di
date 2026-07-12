**** Function test ****
> After instruction selection:
function $test() {
@start
	%c =w copy R1
	acmpw %c, 0
	jfine @yes, @no
@yes
	jmp @end
@no
@end
	%rc.1 =w phi @no 0, @yes 1
	R1 =w copy %rc.1
	ret0 0001
}

