**** Function f ****
> After instruction selection:
function $f() {
@start
	%j =l copy R8
	%i =l copy R7
	%isel.3 =l copy 8
	%off1 =l mul %i, %isel.3
	%isel.2 =l copy $a
	%a_i =l add %off1, %isel.2
	%isel.1 =l copy 4
	%off2 =l mul %j, %isel.1
	%a_ij =l add %a_i, %off2
	%x =w loadsw %a_ij
	R7 =w copy %x
	ret0 0001
}

