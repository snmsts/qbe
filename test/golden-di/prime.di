**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%n =w phi @start 5, @tloop %n, @yes %n1
	%p =w phi @start 13, @tloop %p1, @yes %p1
	%p1 =w add %p, 2
@tloop
	%t =w phi @loop 3, @next %t1
	R1 =w copy %p
	R3 =w sign R1
	xidivw %t
	copy R1
	%r =w copy R3
	xcmpw 0, %r
	jfine @next, @loop
@next
	%t1 =w add %t, 2
	%tsq =w mul %t1, %t1
	xcmpw %p, %tsq
	jfisgt @yes, @tloop
@yes
	%n1 =w add %n, 1
	xcmpw 10001, %n1
	jfieq @end, @loop
@end
	storew %p, $a
	ret0
}

