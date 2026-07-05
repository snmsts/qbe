**** Function main ****
> After slot promotion:
function $main() {
@start
	%a =l alloc4 4
	%b =l alloc4 4
	storew 4, %a
	storew 5, %b
@loop
	%mem =l phi @start %a, @loop %bcpy
	%w =w load %mem
	%eq5 =w ceqw %w, 5
	%bcpy =l copy %b
	jnz %eq5, @exit, @loop
@exit
	retw 0
}

> After load elimination:
function $main() {
@start
	%a =l alloc4 4
	%b =l alloc4 4
	storew 4, %a
	storew 5, %b
@loop
	%mem =l phi @start %a, @loop %bcpy
	%w =w load %mem
	%eq5 =w ceqw %w, 5
	%bcpy =l copy %b
	jnz %eq5, @exit, @loop
@exit
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start
	%a =l alloc4 4
	%b =l alloc4 4
	storew 4, %a
	storew 5, %b
@loop
	%mem =l phi @start %a, @loop %bcpy
	%w =w load %mem
	%eq5 =w ceqw %w, 5
	%bcpy =l copy %b
	jnz %eq5, @exit, @loop
@exit
	retw 0
}

