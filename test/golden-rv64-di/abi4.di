**** Function alpha ****
> After instruction selection:
function $alpha() {
@ini
	%n =l copy R9
	%l =w copy R8
	%p =l copy R7
	%pe =l add %p, %n
@lop
	%p1 =l phi @ini %p, @lop %p2
	%l1 =w phi @ini %l, @lop %l2
	storeb %l1, %p1
	%p2 =l add %p1, 1
	%l2 =w add %l1, 1
	%isel.2 =l xor %pe, %p1
	%c1 =w reqz %isel.2
	jnz %c1, @end, @lop
@end
	%snk.1 =l add %p, %n
	%isel.3 =w copy 0
	storeb %isel.3, %snk.1
	ret0
}

**** Function test ****
> After instruction selection:
function $test() {
@ini
	%abi.4 =l copy R7
	%isel.19 =l copy 16
	R9 =l copy %isel.19
	%isel.18 =w copy 65
	R8 =w copy %isel.18
	%isel.17 =l addr S0
	R7 =l copy %isel.17
	call $alpha, 0031
	%r0 =w copy R7
	%isel.16 =l addr S0
	%blt.13 =l add %isel.16, 0
	%blt.11 =w loadub %blt.13
	%blt.12 =l add %abi.4, 0
	storeb %blt.11, %blt.12
	%isel.15 =l addr S0
	%blt.10 =l add %isel.15, 1
	%blt.8 =l load %blt.10
	%blt.9 =l add %abi.4, 1
	storel %blt.8, %blt.9
	%isel.14 =l addr S0
	%blt.7 =l add %isel.14, 9
	%blt.5 =l load %blt.7
	%blt.6 =l add %abi.4, 9
	storel %blt.5, %blt.6
	ret0 0000
}

