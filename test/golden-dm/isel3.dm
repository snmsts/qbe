**** Function slt ****
> After slot promotion:
function $slt() {
@start
	%x =w par
	%y =w par
	%r =w csltw %x, %y
	retw %r
}

> After load elimination:
function $slt() {
@start
	%x =w par
	%y =w par
	%r =w csltw %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $slt() {
@start
	%x =w par
	%y =w par
	%r =w csltw %x, %y
	retw %r
}

**** Function sle ****
> After slot promotion:
function $sle() {
@start
	%x =w par
	%y =w par
	%r =w cslew %x, %y
	retw %r
}

> After load elimination:
function $sle() {
@start
	%x =w par
	%y =w par
	%r =w cslew %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $sle() {
@start
	%x =w par
	%y =w par
	%r =w cslew %x, %y
	retw %r
}

**** Function sgt ****
> After slot promotion:
function $sgt() {
@start
	%x =w par
	%y =w par
	%r =w csgtw %x, %y
	retw %r
}

> After load elimination:
function $sgt() {
@start
	%x =w par
	%y =w par
	%r =w csgtw %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $sgt() {
@start
	%x =w par
	%y =w par
	%r =w csgtw %x, %y
	retw %r
}

**** Function sge ****
> After slot promotion:
function $sge() {
@start
	%x =w par
	%y =w par
	%r =w csgew %x, %y
	retw %r
}

> After load elimination:
function $sge() {
@start
	%x =w par
	%y =w par
	%r =w csgew %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $sge() {
@start
	%x =w par
	%y =w par
	%r =w csgew %x, %y
	retw %r
}

**** Function ult ****
> After slot promotion:
function $ult() {
@start
	%x =w par
	%y =w par
	%r =w cultw %x, %y
	retw %r
}

> After load elimination:
function $ult() {
@start
	%x =w par
	%y =w par
	%r =w cultw %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ult() {
@start
	%x =w par
	%y =w par
	%r =w cultw %x, %y
	retw %r
}

**** Function ule ****
> After slot promotion:
function $ule() {
@start
	%x =w par
	%y =w par
	%r =w culew %x, %y
	retw %r
}

> After load elimination:
function $ule() {
@start
	%x =w par
	%y =w par
	%r =w culew %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ule() {
@start
	%x =w par
	%y =w par
	%r =w culew %x, %y
	retw %r
}

**** Function ugt ****
> After slot promotion:
function $ugt() {
@start
	%x =w par
	%y =w par
	%r =w cugtw %x, %y
	retw %r
}

> After load elimination:
function $ugt() {
@start
	%x =w par
	%y =w par
	%r =w cugtw %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ugt() {
@start
	%x =w par
	%y =w par
	%r =w cugtw %x, %y
	retw %r
}

**** Function uge ****
> After slot promotion:
function $uge() {
@start
	%x =w par
	%y =w par
	%r =w cugew %x, %y
	retw %r
}

> After load elimination:
function $uge() {
@start
	%x =w par
	%y =w par
	%r =w cugew %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $uge() {
@start
	%x =w par
	%y =w par
	%r =w cugew %x, %y
	retw %r
}

**** Function eq ****
> After slot promotion:
function $eq() {
@start
	%x =w par
	%y =w par
	%r =w ceqw %x, %y
	retw %r
}

> After load elimination:
function $eq() {
@start
	%x =w par
	%y =w par
	%r =w ceqw %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $eq() {
@start
	%x =w par
	%y =w par
	%r =w ceqw %x, %y
	retw %r
}

**** Function ne ****
> After slot promotion:
function $ne() {
@start
	%x =w par
	%y =w par
	%r =w cnew %x, %y
	retw %r
}

> After load elimination:
function $ne() {
@start
	%x =w par
	%y =w par
	%r =w cnew %x, %y
	retw %r
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ne() {
@start
	%x =w par
	%y =w par
	%r =w cnew %x, %y
	retw %r
}

