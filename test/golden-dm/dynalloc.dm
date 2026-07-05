**** Function g ****
> After slot promotion:
function $g() {
@start
	ret0
}

> After load elimination:
function $g() {
@start
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $g() {
@start
	ret0
}

**** Function f ****
> After slot promotion:
function $f() {
@start
	%arg =w par
	call $g
@alloc
	%r =l alloc8 16
	storel 180388626474, %r
	%r8 =l add 8, %r
	storel 180388626474, %r8
	retw %arg
}

> After load elimination:
function $f() {
@start
	%arg =w par
	call $g
@alloc
	%r =l alloc8 16
	storel 180388626474, %r
	%r8 =l add 8, %r
	storel 180388626474, %r8
	retw %arg
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%arg =w par
	call $g
@alloc
	%r =l alloc8 16
	storel 180388626474, %r
	%r8 =l add 8, %r
	storel 180388626474, %r8
	retw %arg
}

**** Function main ****
> After slot promotion:
function $main() {
@start
	argw 0
	%a =w call $f
	argw 0
	%b =w call $f
	retw %a
}

> After load elimination:
function $main() {
@start
	argw 0
	%a =w call $f
	argw 0
	%b =w call $f
	retw %a
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start
	argw 0
	%a =w call $f
	argw 0
	%b =w call $f
	retw %a
}

