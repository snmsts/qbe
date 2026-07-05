**** Function test ****
> After slot promotion:
function $test() {
@start
@loop
	%max =w phi @start -1, @new %byt, @old %max
	%loc =l phi @start $arr, @new %loc1, @old %loc1
	%byt =w loadub %loc
	%loc1 =l add 1, %loc
	jnz %byt, @iter, @end
@iter
	%cmp =w cslew %max, %byt
	jnz %cmp, @new, @old
@new
	jmp @loop
@old
	jmp @loop
@end
	storew %max, $a
	ret0
}

> After load elimination:
function $test() {
@start
@loop
	%max =w phi @start -1, @new %byt, @old %max
	%loc =l phi @start $arr, @new %loc1, @old %loc1
	%byt =w loadub %loc
	%loc1 =l add 1, %loc
	jnz %byt, @iter, @end
@iter
	%cmp =w cslew %max, %byt
	jnz %cmp, @new, @old
@new
	jmp @loop
@old
	jmp @loop
@end
	storew %max, $a
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
@loop
	%max =w phi @start -1, @new %byt, @old %max
	%loc =l phi @start $arr, @new %loc1, @old %loc1
	%byt =w loadub %loc
	%loc1 =l add 1, %loc
	jnz %byt, @iter, @end
@iter
	%cmp =w cslew %max, %byt
	jnz %cmp, @new, @old
@new
	jmp @loop
@old
	jmp @loop
@end
	storew %max, $a
	ret0
}

