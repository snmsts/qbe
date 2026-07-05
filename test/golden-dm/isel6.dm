**** Function main ****
> After slot promotion:
function $main() {
@_0
	argl 1
	argl 2
	argl 3
	argl 4
	argl 5
	argl 6
	argl 7
	argl 8
	argl 9223372036854775807
	%_1 =w call $myfunc
	retw 0
}

> After load elimination:
function $main() {
@_0
	argl 1
	argl 2
	argl 3
	argl 4
	argl 5
	argl 6
	argl 7
	argl 8
	argl 9223372036854775807
	%_1 =w call $myfunc
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@_0
	argl 1
	argl 2
	argl 3
	argl 4
	argl 5
	argl 6
	argl 7
	argl 8
	argl 9223372036854775807
	%_1 =w call $myfunc
	retw 0
}

