**** Function func ****
> After slot promotion:
function $func() {
@start.0
	%temp =l alloc4 4
	%ret =l alloc4 8
	storew 1, %temp
	%field =l add %ret, 4
	storew 2, %ret
	blit0 %temp, %field
	blit1 4
	storew 2, %ret
	retc %ret, :t
}

> After load elimination:
function $func() {
@start.0
	%temp =l alloc4 4
	%ret =l alloc4 8
	storew 1, %temp
	%field =l add %ret, 4
	storew 2, %ret
	blit0 %temp, %field
	blit1 4
	storew 2, %ret
	retc %ret, :t
}

> Slot coalescing:
	fuse (  8b) [ %ret[3,5) %temp[1,3) ]
	sums 0/4/12 (killed/fused/total)

function $func() {
@start.0
	%ret =l alloc4 8
	nop
	storew 1, %ret
	%field =l add %ret, 4
	nop
	blit0 %ret, %field
	blit1 -4
	storew 2, %ret
	retc %ret, :t
}

**** Function main ****
> After slot promotion:
function $main() {
@start
	%ret =l call $func, :t
	%fptr =l add %ret, 4
	%field =w loaduw %fptr
	%x =w ceqw %field, 1
	jnz %x, @passed, @failed
@failed
	call $abort
@passed
	retw 0
}

> After load elimination:
function $main() {
@start
	%ret =l call $func, :t
	%fptr =l add %ret, 4
	%field =w loaduw %fptr
	%x =w ceqw %field, 1
	jnz %x, @passed, @failed
@failed
	call $abort
@passed
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start
	%ret =l call $func, :t
	%fptr =l add %ret, 4
	%field =w loaduw %fptr
	%x =w ceqw %field, 1
	jnz %x, @passed, @failed
@failed
	call $abort
@passed
	retw 0
}

