**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.3 =l copy 1
	%isel.2 =l addr S0
	%y1 =l add %isel.2, %isel.3
	%isel.1 =w copy 0
	storeb %isel.1, %y1
@loop
	%n =w phi @start 0, @loop %n1
	%isel.7 =w copy 48
	%c =w add %n, %isel.7
	%isel.6 =l addr S0
	storeb %c, %isel.6
	%isel.5 =l addr S0
	R1 =l copy %isel.5
	call $puts, 0021
	%r =w copy R1
	%isel.4 =w copy 1
	%n1 =w add %n, %isel.4
	acmpw %n1, 9
	jfisle @loop, @end
@end
	ret0
}

