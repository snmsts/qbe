**** Function main ****
> After instruction selection:
function $main() {
@start
	storeb 0, [1 + S0]
@loop
	%n =w phi @start 0, @loop %n1
	%c =w add %n, 48
	storeb %c, [S0]
	%isel.1 =l addr S0
	R5 =l copy %isel.1
	call $puts, 0011
	%r =w copy R1
	%n1 =w add %n, 1
	xcmpw 9, %n1
	jfisle @loop, @end
@end
	ret0
}

