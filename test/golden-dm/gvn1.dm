**** Function test ****
> After slot promotion:
function $test() {
@start
	%p1 =w par
	%p2 =w par
@entry
	%t1 =w copy 1
	jnz %t1, @live, @dead1
@live
	%t2 =w add %p1, %p2
	retw %t2
@dead1
	%t2 =w add %p1, %p2
@dead2
	jnz %t1, @live, @dead1
}

> After load elimination:
function $test() {
@start
	%p1 =w par
	%p2 =w par
@entry
	%t1.3 =w copy 1
	jnz %t1.3, @live, @dead1
@live
	%t2.1 =w add %p1, %p2
	retw %t2.1
@dead1
	%t2.2 =w add %p1, %p2
@dead2
	jnz %t1.3, @live, @dead1
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%p1 =w par
	%p2 =w par
@entry
	%t1.3 =w copy 1
	jnz %t1.3, @live, @dead1
@live
	%t2.1 =w add %p1, %p2
	retw %t2.1
@dead1
	%t2.2 =w add %p1, %p2
@dead2
	jnz %t1.3, @live, @dead1
}

