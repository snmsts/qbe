**** Function intwrap ****
> After slot promotion:
function $intwrap() {
@s
	%a =l copy -9223372036854775808
	%b =l copy -1
	%c =l copy -1
	%d =l copy 4294967296
	%e =w copy 4294967295
	%f =l copy 9223372036854775807
	ret0
}

> After load elimination:
function $intwrap() {
@s
	%a =l copy -9223372036854775808
	%b =l copy -1
	%c =l copy -1
	%d =l copy 4294967296
	%e =w copy 4294967295
	%f =l copy 9223372036854775807
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $intwrap() {
@s
	%a =l copy -9223372036854775808
	%b =l copy -1
	%c =l copy -1
	%d =l copy 4294967296
	%e =w copy 4294967295
	%f =l copy 9223372036854775807
	ret0
}

