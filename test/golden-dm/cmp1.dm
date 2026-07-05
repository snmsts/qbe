**** Function test ****
> After slot promotion:
function $test() {
@start
	%c =w par
	%cmp =w cultw 1, %c
	jnz %cmp, @yes, @no
@yes
	%cmp =w copy 1
@no
	retw %cmp
}

> After load elimination:
function $test() {
@start
	%c =w par
	%cmp.1 =w cultw 1, %c
	jnz %cmp.1, @yes, @no
@yes
	%cmp.3 =w copy 1
@no
	%cmp.2 =w phi @start %cmp.1, @yes %cmp.3
	retw %cmp.2
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%c =w par
	%cmp.1 =w cultw 1, %c
	jnz %cmp.1, @yes, @no
@yes
	%cmp.3 =w copy 1
@no
	%cmp.2 =w phi @start %cmp.1, @yes %cmp.3
	retw %cmp.2
}

