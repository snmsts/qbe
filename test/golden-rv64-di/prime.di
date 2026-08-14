**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =w copy 13
	%isel.1 =w copy 5
@loop
	%n =w phi @start %isel.1, @tloop %n, @yes %n1
	%p =w phi @start %isel.2, @tloop %p1, @yes %p1
	%p1 =w add %p, 2
	%isel.3 =w copy 3
@tloop
	%t =w phi @loop %isel.3, @next %t1
	%r =w rem %p, %t
	jnz %r, @next, @loop
@next
	%t1 =w add %t, 2
	%tsq =w mul %t1, %t1
	%c0 =w csltl %p, %tsq
	jnz %c0, @yes, @tloop
@yes
	%n1 =w add %n, 1
	%isel.5 =w copy 10001
	%isel.4 =w xor %n1, %isel.5
	%c1 =w reqz %isel.4
	jnz %c1, @end, @loop
@end
	storew %p, $a
	ret0
}

