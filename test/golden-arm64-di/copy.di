**** Function f ****
> After instruction selection:
function $f() {
@start
	%isel.1 =l copy $a
	%x0 =w loadsb %isel.1
	%x1 =l extsb %x0
	acmnl %x1, 1
	%c =w flagieq
	R1 =w copy %c
	ret0 0001
}

**** Function g ****
> After instruction selection:
function $g() {
@start
	%arg =w copy R1
@loop
	acmpw %arg, 0
	jfine @end, @loop
@end
	%a0 =w extuh %arg
	%isel.4 =w copy 65536
	%a1 =w or %a0, %isel.4
	%isel.3 =w copy 1
	%a3 =w shr %a1, %isel.3
	%isel.2 =w copy 65537
	%a4 =w or %a0, %isel.2
	%a5 =w or %a3, %a4
	%ret =w extuh %a5
	R1 =w copy %ret
	ret0 0001
}

