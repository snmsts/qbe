**** Function rand ****
> After slot promotion:
function $rand() {
@start
	retw 0
}

> After load elimination:
function $rand() {
@start
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $rand() {
@start
	retw 0
}

**** Function chk ****
> After slot promotion:
function $chk() {
@start
	%a =w par
	%b =w par
	%ok =w ceqw %a, 1
	%ok1 =w ceqw %b, 0
	%ok2 =w and %ok, %ok1
	%ret =w xor %ok2, 1
	retw %ret
}

> After load elimination:
function $chk() {
@start
	%a =w par
	%b =w par
	%ok =w ceqw %a, 1
	%ok1 =w ceqw %b, 0
	%ok2 =w and %ok, %ok1
	%ret =w xor %ok2, 1
	retw %ret
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $chk() {
@start
	%a =w par
	%b =w par
	%ok =w ceqw %a, 1
	%ok1 =w ceqw %b, 0
	%ok2 =w and %ok, %ok1
	%ret =w xor %ok2, 1
	retw %ret
}

**** Function main ****
> After slot promotion:
function $main() {
@start
	%s0 =l alloc4 8
	%s1 =l alloc4 8
	storew 1, %s0
	%s04 =l add 4, %s0
	storew 0, %s04
	%rnd =w call $rand
	jnz %rnd, @tt, @ff
@tt
	jmp @blit
@ff
@blit
	blit0 %s0, %s1
	blit1 8
	%w0 =w load %s1
	%s14 =l add 4, %s1
	%w1 =w load %s14
	argw %w0
	argw %w1
	%ret =w call $chk
	retw %ret
}

> After load elimination:
function $main() {
@start
	%s0 =l alloc4 8
	%s1 =l alloc4 8
	storew 1, %s0
	%s04 =l add 4, %s0
	storew 0, %s04
	%rnd =w call $rand
	jnz %rnd, @tt, @ff
@tt
	jmp @blit
@ff
@blit
	%ld.2 =w phi @tt 0, @ff 0
	%ld.1 =w phi @tt 1, @ff 1
	blit0 %s0, %s1
	blit1 8
	%w0 =w copy %ld.1
	%s14 =l add 4, %s1
	%w1 =w copy %ld.2
	argw %w0
	argw %w1
	%ret =w call $chk
	retw %ret
}

> Slot coalescing:
	kill [ %s1 ]
	fuse (  8b) [ %s0[1,6) ]
	sums 8/0/16 (killed/fused/total)

function $main() {
@start
	%s0 =l alloc4 8
	nop
	storew 1, %s0
	%s04 =l add 4, %s0
	storew 0, %s04
	%rnd =w call $rand
	jnz %rnd, @tt, @ff
@tt
	jmp @blit
@ff
@blit
	%ld.2 =w phi @tt 0, @ff 0
	%ld.1 =w phi @tt 1, @ff 1
	nop
	nop
	%w0 =w copy %ld.1
	nop
	%w1 =w copy %ld.2
	argw %w0
	argw %w1
	%ret =w call $chk
	retw %ret
}

