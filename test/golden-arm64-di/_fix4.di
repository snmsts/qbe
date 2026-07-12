**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%n.5 =w phi @start 2, @prime %n.10, @test %n.5
	%x.6 =w phi @start 3, @prime %x.8, @test %x.8
	%isel.12 =w copy 10000
	acmpw %n.5, %isel.12
	jfieq @end, @next
@next
	%isel.13 =w copy 2
	%x.8 =w add %x.6, %isel.13
@tloop
	%t.9 =w phi @next 3, @tnext %t.11
	%s =w mul %t.9, %t.9
	acmpw %s, %x.8
	jfisgt @prime, @test
@test
	%r =w rem %x.8, %t.9
	acmpw %r, 0
	jfine @tnext, @loop
@tnext
	%isel.14 =w copy 2
	%t.11 =w add %t.9, %isel.14
	jmp @tloop
@prime
	%isel.15 =w copy 1
	%n.10 =w add %n.5, %isel.15
	jmp @loop
@end
	%isel.16 =l copy $a
	storew %x.6, %isel.16
	ret0
}

