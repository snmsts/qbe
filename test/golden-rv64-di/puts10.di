**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.3 =l addr S0
	%y1 =l add %isel.3, 1
	%isel.2 =w copy 0
	storeb %isel.2, %y1
	%isel.1 =w copy 0
@loop
	%n =w phi @start %isel.1, @loop %n1
	%c =w add %n, 48
	storeb %c, S0
	%isel.6 =l addr S0
	R7 =l copy %isel.6
	call $puts, 0011
	%r =w copy R7
	%n1 =w add %n, 1
	%isel.5 =w copy 9
	%isel.4 =w csltl %isel.5, %n1
	%cmp =w xor %isel.4, 1
	jnz %cmp, @loop, @end
@end
	ret0
}

