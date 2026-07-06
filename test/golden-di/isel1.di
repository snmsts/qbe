**** Function f ****
> After instruction selection:
function $f() {
@start
	%j =l copy R4
	%i =l copy R5
	%off1 =l mul %i, 8
	%isel.1 =l addr $a
	%a_i =l add %off1, %isel.1
	%off2 =l mul %j, 4
	%a_ij =l add %a_i, %off2
	%x =w loadsw %a_ij
	R1 =w copy %x
	ret0 0001
}

