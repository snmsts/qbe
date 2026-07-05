**** Function gcm_test ****
> After slot promotion:
function $gcm_test() {
@start
	%a =w par
	%i.0 =w copy 0
@loop
	%i.1 =w phi @start %i.0, @loop %i.2
	%b =w add %a, 1
	%i.2 =w add %i.1, %b
	%c =w mul %i.2, 2
	%x =w csltw %i.2, 10
	jnz %x, @loop, @end
@end
	retw %c
}

> After load elimination:
function $gcm_test() {
@start
	%a =w par
	%i.0 =w copy 0
@loop
	%i.1 =w phi @start %i.0, @loop %i.2
	%b =w add %a, 1
	%i.2 =w add %i.1, %b
	%c.1 =w mul %i.2, 2
	%x =w csltw %i.2, 10
	jnz %x, @loop, @end
@end
	retw %c.1
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $gcm_test() {
@start
	%a =w par
	%i.0 =w copy 0
@loop
	%i.1 =w phi @start %i.0, @loop %i.2
	%b =w add %a, 1
	%i.2 =w add %i.1, %b
	%c.1 =w mul %i.2, 2
	%x =w csltw %i.2, 10
	jnz %x, @loop, @end
@end
	retw %c.1
}

**** Function gcm_test2 ****
> After slot promotion:
function $gcm_test2() {
@start
	%a =w par
	%f =w copy 1
	%x =w copy 0
	%s.0 =w copy 0
@loop
	%s.1 =w phi @start %s.0, @if_false %s.2
	jnz %a, @if, @end
@if
	jnz %f, @if_true, @if_false
@if_true
	%f =w copy 0
	%x =w add %x, 1
@if_false
	%s.2 =w add %s.1, %x
	jmp @loop
@end
	ret0
}

> After load elimination:
function $gcm_test2() {
@start
	%a =w par
	%f.2 =w copy 1
	%x.3 =w copy 0
	%s.0 =w copy 0
@loop
	%x.4 =w phi @start %x.3, @if_false %x.6
	%f.5 =w phi @start %f.2, @if_false %f.7
	%s.1 =w phi @start %s.0, @if_false %s.2
	jnz %a, @if, @end
@if
	jnz %f.5, @if_true, @if_false
@if_true
	%f.8 =w copy 0
	%x.9 =w add %x.4, 1
@if_false
	%x.6 =w phi @if %x.4, @if_true %x.9
	%f.7 =w phi @if %f.5, @if_true %f.8
	%s.2 =w add %s.1, %x.6
	jmp @loop
@end
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $gcm_test2() {
@start
	%a =w par
	%f.2 =w copy 1
	%x.3 =w copy 0
	%s.0 =w copy 0
@loop
	%x.4 =w phi @start %x.3, @if_false %x.6
	%f.5 =w phi @start %f.2, @if_false %f.7
	%s.1 =w phi @start %s.0, @if_false %s.2
	jnz %a, @if, @end
@if
	jnz %f.5, @if_true, @if_false
@if_true
	%f.8 =w copy 0
	%x.9 =w add %x.4, 1
@if_false
	%x.6 =w phi @if %x.4, @if_true %x.9
	%f.7 =w phi @if %f.5, @if_true %f.8
	%s.2 =w add %s.1, %x.6
	jmp @loop
@end
	ret0
}

