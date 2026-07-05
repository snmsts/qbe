**** Function f ****
> After slot promotion:
function $f() {
@start
	%i =l par
	%j =l par
	%off1 =l mul %i, 8
	%a_i =l add $a, %off1
	%off2 =l mul %j, 4
	%a_ij =l add %a_i, %off2
	%x =w loadsw %a_ij
	retw %x
}

> After load elimination:
function $f() {
@start
	%i =l par
	%j =l par
	%off1 =l mul %i, 8
	%a_i =l add $a, %off1
	%off2 =l mul %j, 4
	%a_ij =l add %a_i, %off2
	%x =w loadsw %a_ij
	retw %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%i =l par
	%j =l par
	%off1 =l mul %i, 8
	%a_i =l add $a, %off1
	%off2 =l mul %j, 4
	%a_ij =l add %a_i, %off2
	%x =w loadsw %a_ij
	retw %x
}

