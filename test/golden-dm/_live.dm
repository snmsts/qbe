**** Function test ****
> After slot promotion:
function $test() {
@start
	%b =w copy 0
	%x =w copy 10
	jnz 0, @loop, @left
@left
	jmp @inloop
@loop
	%x1 =w add %x, 1
@inloop
	%b1 =w add %b, 1
@endloop
	jmp @loop
}

> After load elimination:
function $test() {
@start
	%b =w copy 0
	%x =w copy 10
	jnz 0, @loop, @left
@left
	jmp @inloop
@loop
	%x1 =w add %x, 1
@inloop
	%b1 =w add %b, 1
@endloop
	jmp @loop
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%b =w copy 0
	%x =w copy 10
	jnz 0, @loop, @left
@left
	jmp @inloop
@loop
	%x1 =w add %x, 1
@inloop
	%b1 =w add %b, 1
@endloop
	jmp @loop
}

