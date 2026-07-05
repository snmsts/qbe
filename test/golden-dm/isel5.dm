**** Function main ****
> After slot promotion:
function $main() {
@start
	%r =d copy d_1.200000
	argl $fmt
	argv
	argd %r
	%x =w call $printf
	retw 0
}

> After load elimination:
function $main() {
@start
	%r =d copy d_1.200000
	argl $fmt
	argv
	argd %r
	%x =w call $printf
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start
	%r =d copy d_1.200000
	argl $fmt
	argv
	argd %r
	%x =w call $printf
	retw 0
}

