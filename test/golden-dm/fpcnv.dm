**** Function fneg ****
> After slot promotion:
function $fneg() {
@fneg
	%f =s par
	%b0 =w cast %f
	%b1 =w xor 2147483648, %b0
	%rs =s cast %b1
	rets %rs
}

> After load elimination:
function $fneg() {
@fneg
	%f =s par
	%b0 =w cast %f
	%b1 =w xor 2147483648, %b0
	%rs =s cast %b1
	rets %rs
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $fneg() {
@fneg
	%f =s par
	%b0 =w cast %f
	%b1 =w xor 2147483648, %b0
	%rs =s cast %b1
	rets %rs
}

**** Function ftrunc ****
> After slot promotion:
function $ftrunc() {
@ftrunc
	%f =d par
	%l0 =w dtosi %f
	%rt =d swtof %l0
	retd %rt
}

> After load elimination:
function $ftrunc() {
@ftrunc
	%f =d par
	%l0 =w dtosi %f
	%rt =d swtof %l0
	retd %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ftrunc() {
@ftrunc
	%f =d par
	%l0 =w dtosi %f
	%rt =d swtof %l0
	retd %rt
}

**** Function wtos ****
> After slot promotion:
function $wtos() {
@start
	%w =w par
	%rt =s uwtof %w
	rets %rt
}

> After load elimination:
function $wtos() {
@start
	%w =w par
	%rt =s uwtof %w
	rets %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $wtos() {
@start
	%w =w par
	%rt =s uwtof %w
	rets %rt
}

**** Function wtod ****
> After slot promotion:
function $wtod() {
@start
	%w =w par
	%rt =d uwtof %w
	retd %rt
}

> After load elimination:
function $wtod() {
@start
	%w =w par
	%rt =d uwtof %w
	retd %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $wtod() {
@start
	%w =w par
	%rt =d uwtof %w
	retd %rt
}

**** Function ltos ****
> After slot promotion:
function $ltos() {
@start
	%l =l par
	%rt =s ultof %l
	rets %rt
}

> After load elimination:
function $ltos() {
@start
	%l =l par
	%rt =s ultof %l
	rets %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ltos() {
@start
	%l =l par
	%rt =s ultof %l
	rets %rt
}

**** Function ltod ****
> After slot promotion:
function $ltod() {
@start
	%l =l par
	%rt =d ultof %l
	retd %rt
}

> After load elimination:
function $ltod() {
@start
	%l =l par
	%rt =d ultof %l
	retd %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ltod() {
@start
	%l =l par
	%rt =d ultof %l
	retd %rt
}

**** Function stow ****
> After slot promotion:
function $stow() {
@start
	%f =s par
	%rt =w stoui %f
	retw %rt
}

> After load elimination:
function $stow() {
@start
	%f =s par
	%rt =w stoui %f
	retw %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $stow() {
@start
	%f =s par
	%rt =w stoui %f
	retw %rt
}

**** Function dtow ****
> After slot promotion:
function $dtow() {
@start
	%f =d par
	%rt =w dtoui %f
	retw %rt
}

> After load elimination:
function $dtow() {
@start
	%f =d par
	%rt =w dtoui %f
	retw %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $dtow() {
@start
	%f =d par
	%rt =w dtoui %f
	retw %rt
}

**** Function stol ****
> After slot promotion:
function $stol() {
@start
	%f =s par
	%rt =l stoui %f
	retl %rt
}

> After load elimination:
function $stol() {
@start
	%f =s par
	%rt =l stoui %f
	retl %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $stol() {
@start
	%f =s par
	%rt =l stoui %f
	retl %rt
}

**** Function dtol ****
> After slot promotion:
function $dtol() {
@start
	%f =d par
	%rt =l dtoui %f
	retl %rt
}

> After load elimination:
function $dtol() {
@start
	%f =d par
	%rt =l dtoui %f
	retl %rt
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $dtol() {
@start
	%f =d par
	%rt =l dtoui %f
	retl %rt
}

