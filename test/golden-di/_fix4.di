**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%n.5 =w phi @start 2, @prime %n.10, @test %n.5
	%x.6 =w phi @start 3, @prime %x.8, @test %x.8
	xcmpw 10000, %n.5
	jfieq @end, @next
@next
	%x.8 =w add %x.6, 2
@tloop
	%t.9 =w phi @next 3, @tnext %t.11
	%s =w mul %t.9, %t.9
	xcmpw %x.8, %s
	jfisgt @prime, @test
@test
	R1 =w copy %x.8
	R3 =w sign R1
	xidivw %t.9
	copy R1
	%r =w copy R3
	xcmpw 0, %r
	jfine @tnext, @loop
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

