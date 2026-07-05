**** Function test ****
> After slot promotion:
function $test() {
@start
	%a =w loadsw $a
	%b =w loadsw $a
@loop
	%c =w phi @start 0, @loop %f
	%d =w phi @start 0, @loop %g
	%e =w phi @start 0, @loop %h
	%f =w add %c, %d
	%g =w add %c, %e
	%h =w add %e, %d
	%x =w cslew %a, %b
	jnz %x, @loop, @end
@end
	ret0
}

> After load elimination:
function $test() {
@start
	%a =w loadsw $a
	%b =w copy %a
@loop
	%c =w phi @start 0, @loop %f
	%d =w phi @start 0, @loop %g
	%e =w phi @start 0, @loop %h
	%f =w add %c, %d
	%g =w add %c, %e
	%h =w add %e, %d
	%x =w cslew %a, %b
	jnz %x, @loop, @end
@end
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%a =w loadsw $a
	%b =w copy %a
@loop
	%c =w phi @start 0, @loop %f
	%d =w phi @start 0, @loop %g
	%e =w phi @start 0, @loop %h
	%f =w add %c, %d
	%g =w add %c, %e
	%h =w add %e, %d
	%x =w cslew %a, %b
	jnz %x, @loop, @end
@end
	ret0
}

