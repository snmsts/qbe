**** Function test ****
> After instruction selection:
function $test() {
@l0
	%isel.8 =w copy 747
	%isel.7 =w copy 380
@l1
	%b.3 =w phi @l0 %isel.7, @l2 %t6
	%a.4 =w phi @l0 %isel.8, @l2 %b.3
	jnz %b.3, @l2, @l3
@l2
	%t6 =w rem %a.4, %b.3
	jmp @l1
@l3
	R7 =w copy %a.4
	ret0 0001
}

