**** Function test ****
> After instruction selection:
function $test() {
@start
	%p2 =w copy R4
	%p1 =w copy R5
	%t2.2 =w add %p1, %p2
	R1 =w copy %t2.2
	ret0 0001
}

