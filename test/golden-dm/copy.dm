**** Function f ****
> After slot promotion:
function $f() {
@start
	%x0 =w loadsb $a
	%x1 =l extsb %x0
	%c =w ceql %x1, -1
	retw %c
}

> After load elimination:
function $f() {
@start
	%x0 =w loadsb $a
	%x1 =l extsb %x0
	%c =w ceql %x1, -1
	retw %c
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%x0 =w loadsb $a
	%x1 =l extsb %x0
	%c =w ceql %x1, -1
	retw %c
}

**** Function g ****
> After slot promotion:
function $g() {
@start
	%arg =w par
	%a0 =w extuh %arg
	%a1 =w or 65536, %a0
@loop
	%a2 =w phi @loop %a2, @start %a1
	jnz %arg, @end, @loop
@end
	%a3 =w shr %a2, 1
	%a4 =w or %a2, 1
	%a5 =w or %a3, %a4
	%ret =w extuh %a5
	retw %ret
}

> After load elimination:
function $g() {
@start
	%arg =w par
	%a0 =w extuh %arg
	%a1 =w or 65536, %a0
@loop
	%a2 =w phi @loop %a2, @start %a1
	jnz %arg, @end, @loop
@end
	%a3 =w shr %a2, 1
	%a4 =w or %a2, 1
	%a5 =w or %a3, %a4
	%ret =w extuh %a5
	retw %ret
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $g() {
@start
	%arg =w par
	%a0 =w extuh %arg
	%a1 =w or 65536, %a0
@loop
	%a2 =w phi @loop %a2, @start %a1
	jnz %arg, @end, @loop
@end
	%a3 =w shr %a2, 1
	%a4 =w or %a2, 1
	%a5 =w or %a3, %a4
	%ret =w extuh %a5
	retw %ret
}

