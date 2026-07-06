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
@start
	R3 =l copy 16
	R4 =w copy 65
	%isel.27 =l addr S0
	R5 =l copy %isel.27
	call $alpha, 0031
	%r0 =w copy R1
	R3 =l copy 16
	R4 =w copy 97
	%isel.26 =l addr S5
	R5 =l copy %isel.26
	call $alpha, 0031
	%r1 =w copy R1
	%abi.2 =l salloc 80
	%blt.23 =w loadub [0 + S5]
	storeb %blt.23, [48 + %abi.2]
	%blt.20 =l load [1 + S5]
	storel %blt.20, [49 + %abi.2]
	%blt.17 =l load [9 + S5]
	storel %blt.17, [57 + %abi.2]
	storel 9, [40 + %abi.2]
	storel 8, [32 + %abi.2]
	storel 7, [24 + %abi.2]
	%blt.14 =w loadub [0 + S0]
	storeb %blt.14, [0 + %abi.2]
	%blt.11 =l load [1 + S0]
	storel %blt.11, [1 + %abi.2]
	%blt.8 =l load [9 + S0]
	storel %blt.8, [9 + %abi.2]
	R7 =w copy 6
	R6 =w copy 5
	R2 =w copy 4
	R3 =w copy 3
	R4 =w copy 2
	R5 =w copy 1
	call $fcb, 0061
	%r2 =w copy R1
	salloc -80
	ret0
}

