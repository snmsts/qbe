**** Function f ****
> After instruction selection:
function $f() {
@start
	%x0 =w loadsb $a
	%x1 =l extsb %x0
	%isel.1 =l xor %x1, -1
	%c =w reqz %isel.1
	R7 =w copy %c
	ret0 0001
}

**** Function g ****
> After instruction selection:
function $g() {
@start
	%arg =w copy R7
@loop
	jnz %arg, @end, @loop
@end
	%a0 =w extuh %arg
	%isel.3 =w copy 65536
	%a1 =w or %a0, %isel.3
	%a3 =w shr %a1, 1
	%isel.2 =w copy 65537
	%a4 =w or %a0, %isel.2
	%a5 =w or %a3, %a4
	%ret =w extuh %a5
	R7 =w copy %ret
	ret0 0001
}

