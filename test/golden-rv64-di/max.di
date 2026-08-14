**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =l copy $arr
	%isel.1 =w copy -1
@loop
	%max =w phi @start %isel.1, @new %byt, @old %max
	%loc =l phi @start %isel.2, @new %loc1, @old %loc1
	%byt =w loadub %loc
	jnz %byt, @iter, @end
@iter
	%isel.3 =w csltl %byt, %max
	%cmp =w xor %isel.3, 1
	%loc1 =l add %loc, 1
	jnz %cmp, @new, @old
@new
	jmp @loop
@old
	jmp @loop
@end
	storew %max, $a
	ret0
}

