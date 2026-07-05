**** Function func ****
> After slot promotion:
function $func() {
@start.0
	%object.5 =l alloc8 24
	%object.7 =l alloc4 8
	%binding.21 =l alloc8 16
	%object.23 =l alloc8 24
@body.4
	%.10 =l add %object.7, 4
	jnz 1, @matches.13, @next.14
@matches.13
	storel 1, %binding.21
	%value.22 =l add %binding.21, 8
	storel 2, %value.22
	%.24 =l add %object.23, 8
	blit0 %binding.21, %.24
	blit1 16
	retc %object.23, :type.1
@next.14
	storew 2543892678, %object.5
	retc %object.5, :type.1
}

> After load elimination:
function $func() {
@start.0
	%object.5 =l alloc8 24
	%object.7 =l alloc4 8
	%binding.21 =l alloc8 16
	%object.23 =l alloc8 24
@body.4
	%.10 =l add %object.7, 4
	jnz 1, @matches.13, @next.14
@matches.13
	storel 1, %binding.21
	%value.22 =l add %binding.21, 8
	storel 2, %value.22
	%.24 =l add %object.23, 8
	blit0 %binding.21, %.24
	blit1 16
	retc %object.23, :type.1
@next.14
	storew 2543892678, %object.5
	retc %object.5, :type.1
}

> Slot coalescing:
	kill [ %object.7 ]
	fuse ( 24b) [ %object.5[3,4) %object.23[8,9) %binding.21[6,8) ]
	sums 8/40/72 (killed/fused/total)

function $func() {
@start.0
	%object.5 =l alloc8 24
	nop
	nop
	nop
@body.4
	nop
	jnz 1, @matches.13, @next.14
@matches.13
	storel 1, %object.5
	%value.22 =l add %object.5, 8
	storel 2, %value.22
	%.24 =l add %object.5, 8
	blit0 %object.5, %.24
	blit1 -16
	retc %object.5, :type.1
@next.14
	storew 2543892678, %object.5
	retc %object.5, :type.1
}

**** Function main ****
> After slot promotion:
function $main() {
@start.27
	nop
	nop
@body.28
	%returns.34 =l call $func, :type.1
	%value.47 =l add %returns.34, 16
	%load.48 =l load %value.47
	%.33 =w ceql %load.48, 2
	jnz %.33, @passed.32, @failed.31
@failed.31
	call $abort
@passed.32
	retw 0
}

> After load elimination:
function $main() {
@start.27
	nop
	nop
@body.28
	%returns.34 =l call $func, :type.1
	%value.47 =l add %returns.34, 16
	%load.48 =l load %value.47
	%.33 =w ceql %load.48, 2
	jnz %.33, @passed.32, @failed.31
@failed.31
	call $abort
@passed.32
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start.27
	nop
	nop
@body.28
	%returns.34 =l call $func, :type.1
	%value.47 =l add %returns.34, 16
	%load.48 =l load %value.47
	%.33 =w ceql %load.48, 2
	jnz %.33, @passed.32, @failed.31
@failed.31
	call $abort
@passed.32
	retw 0
}

