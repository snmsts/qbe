**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.1 =l addr $arr
@loop
	%max =w phi @start -1, @new %byt, @old %max
	%loc =l phi @start %isel.1, @new %loc1, @old %loc1
	%byt =w loadub [%loc]
	xcmpw 0, %byt
	jfine @iter, @end
@iter
	xcmpw %byt, %max
	%cmp =w flagisle
	%loc1 =l add %loc, 1
	xcmpw 0, %cmp
	jfine @new, @old
@new
	jmp @loop
@old
	jmp @loop
@end
	storew %max, $a
	ret0
}

