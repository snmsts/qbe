**** Function test ****
> After instruction selection:
function $test() {
@start
	%c =w copy R1
	acmpw %c, 1
	%cmp.1 =w flagiugt
	acmpw %cmp.1, 0
	jfine @yes, @no
@yes
@no
	%cmp.2 =w phi @start %cmp.1, @yes 1
	R1 =w copy %cmp.2
	ret0 0001
}

