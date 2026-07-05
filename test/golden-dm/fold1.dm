**** Function f1 ****
> After slot promotion:
function $f1() {
@start
	%x =w sar 2147483648, 31
	retw %x
}

> After load elimination:
function $f1() {
@start
	%x =w sar 2147483648, 31
	retw %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f1() {
@start
	%x =w sar 2147483648, 31
	retw %x
}

**** Function f2 ****
> After slot promotion:
function $f2() {
@start
	%x =w div 4294967040, 8
	retw %x
}

> After load elimination:
function $f2() {
@start
	%x =w div 4294967040, 8
	retw %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f2() {
@start
	%x =w div 4294967040, 8
	retw %x
}

**** Function f3 ****
> After slot promotion:
function $f3() {
@start
	%x =w rem 4294967284, 7
	retw %x
}

> After load elimination:
function $f3() {
@start
	%x =w rem 4294967284, 7
	retw %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f3() {
@start
	%x =w rem 4294967284, 7
	retw %x
}

**** Function f4 ****
> After slot promotion:
function $f4() {
@start
	%x =w shr 4294967296, 1
	retw %x
}

> After load elimination:
function $f4() {
@start
	%x =w shr 4294967296, 1
	retw %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f4() {
@start
	%x =w shr 4294967296, 1
	retw %x
}

**** Function f5 ****
> After slot promotion:
function $f5() {
@start
	%x =w udiv 1, 4294967297
	retw %x
}

> After load elimination:
function $f5() {
@start
	%x =w udiv 1, 4294967297
	retw %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f5() {
@start
	%x =w udiv 1, 4294967297
	retw %x
}

**** Function f6 ****
> After slot promotion:
function $f6() {
@start
	%x =w urem 4294967296, 7
	retw %x
}

> After load elimination:
function $f6() {
@start
	%x =w urem 4294967296, 7
	retw %x
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f6() {
@start
	%x =w urem 4294967296, 7
	retw %x
}

