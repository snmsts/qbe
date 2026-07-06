**** Function test ****
> After instruction selection:
function $test() {
@l0
@l1
	%b.3 =w phi @l0 380, @l2 %t6
	%a.4 =w phi @l0 747, @l2 %b.3
	xcmpw 0, %b.3
	jfine @l2, @l3
@l2
	R1 =w copy %a.4
	R3 =w sign R1
	xidivw %b.3
	copy R1
	%t6 =w copy R3
	jmp @l1
@l3
	R1 =w copy %a.4
	ret0 0001
}

