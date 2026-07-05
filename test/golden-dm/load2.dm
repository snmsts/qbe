**** Function f ****
> After slot promotion:
function $f() {
@start
	%x =l alloc4 12
	%y =l alloc4 12
	%x1 =l add 1, %x
	%x2 =l add 1, %x1
	%x3 =l add 1, %x2
	%x4 =l add 1, %x3
	%x5 =l add 1, %x4
	%x6 =l add 1, %x5
	%x7 =l add 1, %x6
	%x8 =l add 1, %x7
	%x9 =l add 1, %x8
	%xa =l add 1, %x9
	%xb =l add 1, %xa
	%y1 =l add 1, %y
	%y4 =l add 4, %y
	storew 287454020, %x4
	storew 1432778632, %y
	blit0 %y, %x5
	blit1 1
	%n =w load %x4
	argw %n
	call $px
	storew 287454020, %x4
	storew 1432778632, %y
	blit0 %y, %x5
	blit1 2
	%n =w load %x4
	argw %n
	call $px
	storew 287454020, %x4
	storew 1432778632, %y
	blit0 %y, %x5
	blit1 4
	%n =w load %x4
	argw %n
	call $px
	storew 287454020, %x4
	storew 1432778632, %y
	blit0 %y, %x2
	blit1 4
	%n =w load %x4
	argw %n
	call $px
	storew 287454020, %x4
	storew 0, %y
	storew 1432778632, %y4
	blit0 %y1, %x2
	blit1 7
	%n =w load %x4
	argw %n
	call $px
	ret0
}

> After load elimination:
function $f() {
@start
	%x =l alloc4 12
	%y =l alloc4 12
	%x1 =l add 1, %x
	%x2 =l add 1, %x1
	%x3 =l add 1, %x2
	%x4 =l add 1, %x3
	%x5 =l add 1, %x4
	%x6 =l add 1, %x5
	%x7 =l add 1, %x6
	%x8 =l add 1, %x7
	%x9 =l add 1, %x8
	%xa =l add 1, %x9
	%xb =l add 1, %xa
	%y1 =l add 1, %y
	%y4 =l add 4, %y
	storew 287454020, %x4
	storew 1432778632, %y
	blit0 %y, %x5
	blit1 1
	%ld.6 =w shl 1432778632, 8
	%ld.7 =w and %ld.6, 65280
	%ld.8 =w and 287454020, 4294902015
	%ld.9 =w or %ld.7, %ld.8
	%n.1 =w copy %ld.9
	argw %n.1
	call $px
	storew 287454020, %x4
	storew 1432778632, %y
	blit0 %y, %x5
	blit1 2
	%ld.10 =w shl 1432778632, 8
	%ld.11 =w and %ld.10, 16776960
	%ld.12 =w and 287454020, 4278190335
	%ld.13 =w or %ld.11, %ld.12
	%n.2 =w copy %ld.13
	argw %n.2
	call $px
	storew 287454020, %x4
	storew 1432778632, %y
	blit0 %y, %x5
	blit1 4
	%ld.14 =w shl 1432778632, 8
	%ld.15 =w and 287454020, 255
	%ld.16 =w or %ld.14, %ld.15
	%n.3 =w copy %ld.16
	argw %n.3
	call $px
	storew 287454020, %x4
	storew 1432778632, %y
	blit0 %y, %x2
	blit1 4
	%ld.17 =w shr 1432778632, 16
	%ld.18 =w and %ld.17, 65535
	%ld.19 =w and 287454020, 4294901760
	%ld.20 =w or %ld.18, %ld.19
	%n.4 =w copy %ld.20
	argw %n.4
	call $px
	storew 287454020, %x4
	storew 0, %y
	storew 1432778632, %y4
	blit0 %y1, %x2
	blit1 7
	%ld.21 =w shl 1432778632, 8
	%ld.22 =l shr 0, 24
	%ld.23 =w or %ld.21, %ld.22
	%n.5 =w copy %ld.23
	argw %n.5
	call $px
	ret0
}

> Slot coalescing:
	kill [ %x ]
	fuse ( 12b) [ %y[2,16) ]
	sums 12/0/24 (killed/fused/total)

function $f() {
@start
	nop
	%y =l alloc4 12
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	%y1 =l add 1, %y
	%y4 =l add 4, %y
	nop
	storew 1432778632, %y
	nop
	nop
	%ld.6 =w shl 1432778632, 8
	%ld.7 =w and %ld.6, 65280
	%ld.8 =w and 287454020, 4294902015
	%ld.9 =w or %ld.7, %ld.8
	%n.1 =w copy %ld.9
	argw %n.1
	call $px
	nop
	storew 1432778632, %y
	nop
	nop
	%ld.10 =w shl 1432778632, 8
	%ld.11 =w and %ld.10, 16776960
	%ld.12 =w and 287454020, 4278190335
	%ld.13 =w or %ld.11, %ld.12
	%n.2 =w copy %ld.13
	argw %n.2
	call $px
	nop
	storew 1432778632, %y
	nop
	nop
	%ld.14 =w shl 1432778632, 8
	%ld.15 =w and 287454020, 255
	%ld.16 =w or %ld.14, %ld.15
	%n.3 =w copy %ld.16
	argw %n.3
	call $px
	nop
	storew 1432778632, %y
	nop
	nop
	%ld.17 =w shr 1432778632, 16
	%ld.18 =w and %ld.17, 65535
	%ld.19 =w and 287454020, 4294901760
	%ld.20 =w or %ld.18, %ld.19
	%n.4 =w copy %ld.20
	argw %n.4
	call $px
	nop
	storew 0, %y
	storew 1432778632, %y4
	nop
	nop
	%ld.21 =w shl 1432778632, 8
	%ld.22 =l shr 0, 24
	%ld.23 =w or %ld.21, %ld.22
	%n.5 =w copy %ld.23
	argw %n.5
	call $px
	ret0
}

