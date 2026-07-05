**** Function f ****
> After slot promotion:
function $f() {
@_0
	%self =l par
	%_1 =l alloc8 16
	storel 77, %_1
	retc %_1, :obj
}

> After load elimination:
function $f() {
@_0
	%self =l par
	%_1 =l alloc8 16
	storel 77, %_1
	retc %_1, :obj
}

> Slot coalescing:
	fuse ( 16b) [ %_1[1,2) ]
	sums 0/0/16 (killed/fused/total)

function $f() {
@_0
	%self =l par
	%_1 =l alloc8 16
	storel 77, %_1
	retc %_1, :obj
}

