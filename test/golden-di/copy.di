**** Function f ****
> After instruction selection:
function $f() {
@start
	%x0 =w loadsb $a
	%x1 =l extsb %x0
	xcmpl -1, %x1
	%c =w flagieq
	R1 =w copy %c
	ret0 0001
}

**** Function g ****
> After instruction selection:
function $g() {
@start
	%arg =w copy R5
@loop
	xcmpw 0, %arg
	jfine @end, @loop
@end
	%a0 =w extuh %arg
	%a1 =w or %a0, 65536
	%a3 =w shr %a1, 1
	%a4 =w or %a0, 65537
	%a5 =w or %a3, %a4
	%ret =w extuh %a5
	R1 =w copy %ret
	ret0 0001
}

