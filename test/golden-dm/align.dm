**** Function test ****
> After slot promotion:
function $test() {
@start
	%x =l alloc16 16
	%y =l add %x, 8
	%m =w rem %y, 16
	storew %m, %y
	%n =w loadsw %y
	storew %n, $a
	ret0
}

> After load elimination:
function $test() {
@start
	%x =l alloc16 16
	%y =l add %x, 8
	%m =w rem %y, 16
	storew %m, %y
	%n =w copy %m
	storew %n, $a
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%x =l alloc16 16
	%y =l add %x, 8
	%m =w rem %y, 16
	storew %m, %y
	%n =w copy %m
	storew %n, $a
	ret0
}

