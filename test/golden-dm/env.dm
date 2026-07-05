**** Function epar ****
> After slot promotion:
function $epar() {
@start
	%e =l pare
	%i =l par
	%x =l add %e, %i
	retl %x
}

> After load elimination:
function $epar() {
@start
	%e =l pare
	%i =l par
	%x =l add %e, %i
	retl %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $epar() {
@start
	%e =l pare
	%i =l par
	%x =l add %e, %i
	retl %x
}

**** Function earg ****
> After slot promotion:
function $earg() {
@start
	%a =l par
	%b =l par
	arge %a
	argl %b
	%r1 =l call $epar
	arge 113
	argl %r1
	%r2 =l call $labs
	retl %r2
}

> After load elimination:
function $earg() {
@start
	%a =l par
	%b =l par
	arge %a
	argl %b
	%r1 =l call $epar
	arge 113
	argl %r1
	%r2 =l call $labs
	retl %r2
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $earg() {
@start
	%a =l par
	%b =l par
	arge %a
	argl %b
	%r1 =l call $epar
	arge 113
	argl %r1
	%r2 =l call $labs
	retl %r2
}

