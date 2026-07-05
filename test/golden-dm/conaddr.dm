**** Function f0 ****
> After slot promotion:
function $f0() {
@start
	%o =l par
	%addr =l add $a, %o
	%char =w loadub %addr
	retw %char
}

> After load elimination:
function $f0() {
@start
	%o =l par
	%addr =l add $a, %o
	%char =w loadub %addr
	retw %char
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f0() {
@start
	%o =l par
	%addr =l add $a, %o
	%char =w loadub %addr
	retw %char
}

**** Function f1 ****
> After slot promotion:
function $f1() {
@start
	%o =l par
	%o1 =l mul %o, 1
	%addr =l add 10, %o1
	%char =w loadub %addr
	retw %char
}

> After load elimination:
function $f1() {
@start
	%o =l par
	%o1 =l mul %o, 1
	%addr =l add 10, %o1
	%char =w loadub %addr
	retw %char
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f1() {
@start
	%o =l par
	%o1 =l mul %o, 1
	%addr =l add 10, %o1
	%char =w loadub %addr
	retw %char
}

**** Function f2 ****
> After slot promotion:
function $f2() {
@start
	%o1 =l par
	%o2 =l par
	%o22 =l mul %o2, 2
	%o =l add %o1, %o22
	%addr =l add $a, %o
	%char =w loadub %addr
	retw %char
}

> After load elimination:
function $f2() {
@start
	%o1 =l par
	%o2 =l par
	%o22 =l mul %o2, 2
	%o =l add %o1, %o22
	%addr =l add $a, %o
	%char =w loadub %addr
	retw %char
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f2() {
@start
	%o1 =l par
	%o2 =l par
	%o22 =l mul %o2, 2
	%o =l add %o1, %o22
	%addr =l add $a, %o
	%char =w loadub %addr
	retw %char
}

**** Function f3 ****
> After slot promotion:
function $f3() {
@start
	%o =l par
	%addr =l add %o, $a
	retl %addr
}

> After load elimination:
function $f3() {
@start
	%o =l par
	%addr =l add %o, $a
	retl %addr
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f3() {
@start
	%o =l par
	%addr =l add %o, $a
	retl %addr
}

**** Function f4 ****
> After slot promotion:
function $f4() {
@start
	storel $p, $p
	ret0
}

> After load elimination:
function $f4() {
@start
	storel $p, $p
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f4() {
@start
	storel $p, $p
	ret0
}

**** Function writeto0 ****
> After slot promotion:
function $writeto0() {
@start
	storel 0, 0
	ret0
}

> After load elimination:
function $writeto0() {
@start
	storel 0, 0
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $writeto0() {
@start
	storel 0, 0
	ret0
}

