**** Function f ****
> After slot promotion:
function $f() {
@start
	%a =l par
@loop
	%b =l phi @start 42, @loop0 %a1, @loop1 %a1
	%a0 =l phi @start %a, @loop0 %a1, @loop1 %a1
	%a1 =l sub %a0, 1
	jnz %b, @loop0, @loop1
@loop0
	jnz %a1, @loop, @end
@loop1
	jnz %a1, @loop, @end
@end
	retl %b
}

> After load elimination:
function $f() {
@start
	%a =l par
@loop
	%b =l phi @start 42, @loop0 %a1, @loop1 %a1
	%a0 =l phi @start %a, @loop0 %a1, @loop1 %a1
	%a1 =l sub %a0, 1
	jnz %b, @loop0, @loop1
@loop0
	jnz %a1, @loop, @end
@loop1
	jnz %a1, @loop, @end
@end
	retl %b
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%a =l par
@loop
	%b =l phi @start 42, @loop0 %a1, @loop1 %a1
	%a0 =l phi @start %a, @loop0 %a1, @loop1 %a1
	%a1 =l sub %a0, 1
	jnz %b, @loop0, @loop1
@loop0
	jnz %a1, @loop, @end
@loop1
	jnz %a1, @loop, @end
@end
	retl %b
}

