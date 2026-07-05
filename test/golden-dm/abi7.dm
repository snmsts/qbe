**** Function test ****
> After slot promotion:
function $test() {
@start
	retc $s, :s2
}

> After load elimination:
function $test() {
@start
	retc $s, :s2
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	retc $s, :s2
}

