**** Function lt ****
> After slot promotion:
function $lt() {
@start
	%x =d par
	%y =d par
	%r =w cltd %x, %y
	retw %r
}

> After load elimination:
function $lt() {
@start
	%x =d par
	%y =d par
	%r =w cltd %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $lt() {
@start
	%x =d par
	%y =d par
	%r =w cltd %x, %y
	retw %r
}

**** Function le ****
> After slot promotion:
function $le() {
@start
	%x =d par
	%y =d par
	%r =w cled %x, %y
	retw %r
}

> After load elimination:
function $le() {
@start
	%x =d par
	%y =d par
	%r =w cled %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $le() {
@start
	%x =d par
	%y =d par
	%r =w cled %x, %y
	retw %r
}

**** Function gt ****
> After slot promotion:
function $gt() {
@start
	%x =d par
	%y =d par
	%r =w cgtd %x, %y
	retw %r
}

> After load elimination:
function $gt() {
@start
	%x =d par
	%y =d par
	%r =w cgtd %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $gt() {
@start
	%x =d par
	%y =d par
	%r =w cgtd %x, %y
	retw %r
}

**** Function ge ****
> After slot promotion:
function $ge() {
@start
	%x =d par
	%y =d par
	%r =w cged %x, %y
	retw %r
}

> After load elimination:
function $ge() {
@start
	%x =d par
	%y =d par
	%r =w cged %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ge() {
@start
	%x =d par
	%y =d par
	%r =w cged %x, %y
	retw %r
}

**** Function eq1 ****
> After slot promotion:
function $eq1() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	retw %r
}

> After load elimination:
function $eq1() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $eq1() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	retw %r
}

**** Function eq2 ****
> After slot promotion:
function $eq2() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	jnz %r, @true, @false
@true
	retw 1
@false
	retw 0
}

> After load elimination:
function $eq2() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	jnz %r, @true, @false
@true
	retw 1
@false
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $eq2() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	jnz %r, @true, @false
@true
	retw 1
@false
	retw 0
}

**** Function eq3 ****
> After slot promotion:
function $eq3() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	jnz %r, @true, @false
@true
	retw %r
@false
	retw 0
}

> After load elimination:
function $eq3() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	jnz %r, @true, @false
@true
	retw %r
@false
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $eq3() {
@start
	%x =d par
	%y =d par
	%r =w ceqd %x, %y
	jnz %r, @true, @false
@true
	retw %r
@false
	retw 0
}

**** Function ne1 ****
> After slot promotion:
function $ne1() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	retw %r
}

> After load elimination:
function $ne1() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ne1() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	retw %r
}

**** Function ne2 ****
> After slot promotion:
function $ne2() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	jnz %r, @true, @false
@true
	retw 1
@false
	retw 0
}

> After load elimination:
function $ne2() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	jnz %r, @true, @false
@true
	retw 1
@false
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ne2() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	jnz %r, @true, @false
@true
	retw 1
@false
	retw 0
}

**** Function ne3 ****
> After slot promotion:
function $ne3() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	jnz %r, @true, @false
@true
	retw %r
@false
	retw 0
}

> After load elimination:
function $ne3() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	jnz %r, @true, @false
@true
	retw %r
@false
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ne3() {
@start
	%x =d par
	%y =d par
	%r =w cned %x, %y
	jnz %r, @true, @false
@true
	retw %r
@false
	retw 0
}

**** Function o ****
> After slot promotion:
function $o() {
@start
	%x =d par
	%y =d par
	%r =w cod %x, %y
	retw %r
}

> After load elimination:
function $o() {
@start
	%x =d par
	%y =d par
	%r =w cod %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $o() {
@start
	%x =d par
	%y =d par
	%r =w cod %x, %y
	retw %r
}

**** Function uo ****
> After slot promotion:
function $uo() {
@start
	%x =d par
	%y =d par
	%r =w cuod %x, %y
	retw %r
}

> After load elimination:
function $uo() {
@start
	%x =d par
	%y =d par
	%r =w cuod %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $uo() {
@start
	%x =d par
	%y =d par
	%r =w cuod %x, %y
	retw %r
}

