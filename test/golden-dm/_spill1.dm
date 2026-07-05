**** Function test ****
> After slot promotion:
function $test() {
@start
	%f =w copy 0
	%b =w copy 1
	%c =w copy 2
	%a =w sub %b, %c
	%d =w copy %b
	%e =w copy %f
	%g =w copy %a
	ret0
}

> After load elimination:
function $test() {
@start
	%f =w copy 0
	%b =w copy 1
	%c =w copy 2
	%a =w sub %b, %c
	%d =w copy %b
	%e =w copy %f
	%g =w copy %a
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%f =w copy 0
	%b =w copy 1
	%c =w copy 2
	%a =w sub %b, %c
	%d =w copy %b
	%e =w copy %f
	%g =w copy %a
	ret0
}

