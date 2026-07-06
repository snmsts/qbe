**** Function alpha ****
> After instruction selection:
function $alpha() {
@ini
	%n =l copy R3
	%l =w copy R4
	%p =l copy R5
	%pe =l add %p, %n
@lop
	%p1 =l phi @ini %p, @lop %p2
	%l1 =w phi @ini %l, @lop %l2
	storeb %l1, [%p1]
	%p2 =l add %p1, 1
	%l2 =w add %l1, 1
	xcmpl %p1, %pe
	jfieq @end, @lop
@end
	storeb 0, [%p + 1 * %n]
	ret0
}

**** Function test ****
> After instruction selection:
function $test() {
@ini
	%abi.2 =l copy R5
	R3 =l copy 16
	R4 =w copy 65
	%isel.12 =l addr S0
	R5 =l copy %isel.12
	call $alpha, 0031
	%r0 =w copy R1
	%blt.9 =w loadub [0 + S0]
	storeb %blt.9, [0 + %abi.2]
	%blt.6 =l load [1 + S0]
	storel %blt.6, [1 + %abi.2]
	%blt.3 =l load [9 + S0]
	storel %blt.3, [9 + %abi.2]
	R1 =l copy %abi.2
	ret0 0001
}

