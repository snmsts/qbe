**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%n =w phi @start 5, @tloop %n, @yes %n1
	%p =w phi @start 13, @tloop %p1, @yes %p1
	%isel.1 =w copy 2
	%p1 =w add %p, %isel.1
@tloop
	%t =w phi @loop 3, @next %t1
	%r =w rem %p, %t
	acmpw %r, 0
	jfine @next, @loop
@next
	%isel.2 =w copy 2
	%t1 =w add %t, %isel.2
	%tsq =w mul %t1, %t1
	acmpw %tsq, %p
	jfisgt @yes, @tloop
@yes
	%isel.4 =w copy 1
	%n1 =w add %n, %isel.4
	%isel.3 =w copy 10001
	acmpw %n1, %isel.3
	jfieq @end, @loop
@end
	%isel.5 =l copy $a
	storew %p, %isel.5
	ret0
}

