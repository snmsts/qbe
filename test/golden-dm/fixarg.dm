**** Function test ****
> After slot promotion:
function $test() {
@start
	%x1 =l alloc8 8
	%x2 =l alloc8 8
	%r =w cnel %x1, %x2
	retw %r
}

> After load elimination:
function $test() {
@start
	%x1 =l alloc8 8
	%x2 =l alloc8 8
	%r =w cnel %x1, %x2
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%x1 =l alloc8 8
	%x2 =l alloc8 8
	%r =w cnel %x1, %x2
	retw %r
}

