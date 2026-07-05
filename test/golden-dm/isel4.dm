**** Function f0 ****
> After slot promotion:
function $f0() {
@start
	%a =l par
	%b =l par
	%c =l add %b, 2
	%d =l mul %c, 4
	%e =l add %a, %d
	%q =l loadsw %e
	retw %q
}

> After load elimination:
function $f0() {
@start
	%a =l par
	%b =l par
	%c =l add %b, 2
	%d =l mul %c, 4
	%e =l add %a, %d
	%q =l loadsw %e
	retw %q
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f0() {
@start
	%a =l par
	%b =l par
	%c =l add %b, 2
	%d =l mul %c, 4
	%e =l add %a, %d
	%q =l loadsw %e
	retw %q
}

**** Function f1 ****
> After slot promotion:
function $f1() {
@start
	%a =l par
	%b =l par
	%c =l add 1, %b
	%f =l add %c, 1
	%d =l mul %f, 4
	%e =l add %d, %a
	%q =l loadsw %e
	retw %q
}

> After load elimination:
function $f1() {
@start
	%a =l par
	%b =l par
	%c =l add 1, %b
	%f =l add %c, 1
	%d =l mul %f, 4
	%e =l add %d, %a
	%q =l loadsw %e
	retw %q
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f1() {
@start
	%a =l par
	%b =l par
	%c =l add 1, %b
	%f =l add %c, 1
	%d =l mul %f, 4
	%e =l add %d, %a
	%q =l loadsw %e
	retw %q
}

**** Function f2 ****
> After slot promotion:
function $f2() {
@start
	%a =l par
	%b =l par
	%l =l mul %b, 4
	%d =l add 8, %l
	%e =l add %a, %d
	%q =l loadsw %e
	retw %q
}

> After load elimination:
function $f2() {
@start
	%a =l par
	%b =l par
	%l =l mul %b, 4
	%d =l add 8, %l
	%e =l add %a, %d
	%q =l loadsw %e
	retw %q
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f2() {
@start
	%a =l par
	%b =l par
	%l =l mul %b, 4
	%d =l add 8, %l
	%e =l add %a, %d
	%q =l loadsw %e
	retw %q
}

**** Function f3 ****
> After slot promotion:
function $f3() {
@start
	%a =l par
	%b =l par
	%l =l mul %b, 4
	%d =l add 4, %l
	%f =l add 4, %d
	%e =l add %a, %f
	%q =l loadsw %e
	retw %q
}

> After load elimination:
function $f3() {
@start
	%a =l par
	%b =l par
	%l =l mul %b, 4
	%d =l add 4, %l
	%f =l add 4, %d
	%e =l add %a, %f
	%q =l loadsw %e
	retw %q
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f3() {
@start
	%a =l par
	%b =l par
	%l =l mul %b, 4
	%d =l add 4, %l
	%f =l add 4, %d
	%e =l add %a, %f
	%q =l loadsw %e
	retw %q
}

**** Function f4 ****
> After slot promotion:
function $f4() {
@start
	%a =l par
	%b =l par
	%c =l add 1, %b
	%d =l mul %c, 4
	%e =l add 4, %d
	%f =l add %e, %a
	%q =l loadsw %f
	retw %q
}

> After load elimination:
function $f4() {
@start
	%a =l par
	%b =l par
	%c =l add 1, %b
	%d =l mul %c, 4
	%e =l add 4, %d
	%f =l add %e, %a
	%q =l loadsw %f
	retw %q
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f4() {
@start
	%a =l par
	%b =l par
	%c =l add 1, %b
	%d =l mul %c, 4
	%e =l add 4, %d
	%f =l add %e, %a
	%q =l loadsw %f
	retw %q
}

