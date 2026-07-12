**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%max =w phi @start -1, @new %byt, @old %max
	%loc =l phi @start $arr, @new %loc1, @old %loc1
	%byt =w loadub %loc
	acmpw %byt, 0
	jfine @iter, @end
@iter
	%isel.1 =l copy 1
	%loc1 =l add %loc, %isel.1
	acmpw %max, %byt
	jfisle @new, @old
@new
	jmp @loop
@old
	jmp @loop
@end
	%isel.2 =l copy $a
	storew %max, %isel.2
	ret0
}

