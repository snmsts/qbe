**** Function f ****
> After slot promotion:
function $f() {
@start
	%x =l par
	%vp =l alloc8 32
	vastart %vp
	%i =l vaarg %vp
	%n =d vaarg %vp
	retd %n
}

> After load elimination:
function $f() {
@start
	%x =l par
	%vp =l alloc8 32
	vastart %vp
	%i =l vaarg %vp
	%n =d vaarg %vp
	retd %n
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%x =l par
	%vp =l alloc8 32
	vastart %vp
	%i =l vaarg %vp
	%n =d vaarg %vp
	retd %n
}

**** Function g ****
> After slot promotion:
function $g() {
@start
	%fmt =l par
	%vp =l alloc8 32
	vastart %vp
	argl %fmt
	argl %vp
	%r =w call $print
	retw %r
}

> After load elimination:
function $g() {
@start
	%fmt =l par
	%vp =l alloc8 32
	vastart %vp
	argl %fmt
	argl %vp
	%r =w call $print
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $g() {
@start
	%fmt =l par
	%vp =l alloc8 32
	vastart %vp
	argl %fmt
	argl %vp
	%r =w call $print
	retw %r
}

