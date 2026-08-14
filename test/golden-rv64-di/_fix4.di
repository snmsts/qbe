**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.13 =w copy 3
	%isel.12 =w copy 2
@loop
	%n.5 =w phi @start %isel.12, @prime %n.10, @test %n.5
	%x.6 =w phi @start %isel.13, @prime %x.8, @test %x.8
	%isel.15 =w copy 10000
	%isel.14 =w xor %n.5, %isel.15
	%c.1 =w reqz %isel.14
	jnz %c.1, @end, @next
@next
	%x.8 =w add %x.6, 2
	%isel.16 =w copy 3
@tloop
	%t.9 =w phi @next %isel.16, @tnext %t.11
	%s =w mul %t.9, %t.9
	%c.2 =w csltl %x.8, %s
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

