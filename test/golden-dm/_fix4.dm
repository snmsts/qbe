**** Function test ****
> After slot promotion:
function $test() {
@start
	%x =w copy 3
	%n =w copy 2
@loop
	%c =w ceqw %n, 10000
	jnz %c, @end, @next
@next
	%t =w copy 3
	%x =w add %x, 2
@tloop
	%s =w mul %t, %t
	%c =w csgtw %s, %x
	jnz %c, @prime, @test
@test
	%r =w rem %x, %t
	jnz %r, @tnext, @loop
@tnext
	%t =w add %t, 2
	jmp @tloop
@prime
	%n =w add %n, 1
	jmp @loop
@end
	storew %x, $a
	ret0
}

> After load elimination:
function $test() {
@start
	%x.3 =w copy 3
	%n.4 =w copy 2
@loop
	%n.5 =w phi @start %n.4, @prime %n.10, @test %n.5
	%x.6 =w phi @start %x.3, @prime %x.8, @test %x.8
	%c.1 =w ceqw %n.5, 10000
	jnz %c.1, @end, @next
@next
	%t.7 =w copy 3
	%x.8 =w add %x.6, 2
@tloop
	%t.9 =w phi @next %t.7, @tnext %t.11
	%s =w mul %t.9, %t.9
	%c.2 =w csgtw %s, %x.8
	jnz %c.2, @prime, @test
@test
	%r =w rem %x.8, %t.9
	jnz %r, @tnext, @loop
@tnext
	%t.11 =w add %t.9, 2
	jmp @tloop
@prime
	%n.10 =w add %n.5, 1
	jmp @loop
@end
	storew %x.6, $a
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%x.3 =w copy 3
	%n.4 =w copy 2
@loop
	%n.5 =w phi @start %n.4, @prime %n.10, @test %n.5
	%x.6 =w phi @start %x.3, @prime %x.8, @test %x.8
	%c.1 =w ceqw %n.5, 10000
	jnz %c.1, @end, @next
@next
	%t.7 =w copy 3
	%x.8 =w add %x.6, 2
@tloop
	%t.9 =w phi @next %t.7, @tnext %t.11
	%s =w mul %t.9, %t.9
	%c.2 =w csgtw %s, %x.8
	jnz %c.2, @prime, @test
@test
	%r =w rem %x.8, %t.9
	jnz %r, @tnext, @loop
@tnext
	%t.11 =w add %t.9, 2
	jmp @tloop
@prime
	%n.10 =w add %n.5, 1
	jmp @loop
@end
	storew %x.6, $a
	ret0
}

