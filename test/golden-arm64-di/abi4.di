**** Function alpha ****
> After instruction selection:
function $alpha() {
@ini
	%n =l copy R3
	%l =w copy R2
	%p =l copy R1
	%pe =l add %p, %n
@lop
	%p1 =l phi @ini %p, @lop %p2
	%l1 =w phi @ini %l, @lop %l2
	storeb %l1, %p1
	%isel.3 =l copy 1
	%p2 =l add %p1, %isel.3
	%isel.2 =w copy 1
	%l2 =w add %l1, %isel.2
	acmpl %pe, %p1
	jfieq @end, @lop
@end
	%snk.1 =l add %p, %n
	%isel.4 =w copy 0
	storeb %isel.4, %snk.1
	ret0
}

**** Function test ****
> After instruction selection:
function $test() {
@ini
	%abi.5 =l copy R9
	%isel.26 =l copy 16
	R3 =l copy %isel.26
	%isel.25 =w copy 65
	R2 =w copy %isel.25
	%isel.24 =l addr S0
	R1 =l copy %isel.24
	call $alpha, 0061
	%r0 =w copy R1
	%isel.23 =l copy 0
	%isel.22 =l addr S0
	%blt.14 =l add %isel.22, %isel.23
	%blt.12 =w loadub %blt.14
	%isel.21 =l copy 0
	%blt.13 =l add %abi.5, %isel.21
	storeb %blt.12, %blt.13
	%isel.20 =l copy 1
	%isel.19 =l addr S0
	%blt.11 =l add %isel.19, %isel.20
	%blt.9 =l load %blt.11
	%isel.18 =l copy 1
	%blt.10 =l add %abi.5, %isel.18
	storel %blt.9, %blt.10
	%isel.17 =l copy 9
	%isel.16 =l addr S0
	%blt.8 =l add %isel.16, %isel.17
	%blt.6 =l load %blt.8
	%isel.15 =l copy 9
	%blt.7 =l add %abi.5, %isel.15
	storel %blt.6, %blt.7
	ret0 0000
}

