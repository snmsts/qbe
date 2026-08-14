**** Function gcm_test ****
> After instruction selection:
function $gcm_test() {
@start
	%a =w copy R7
	%b =w add %a, 1
	%isel.2 =w copy 0
@loop
	%i.1 =w phi @start %isel.2, @loop %i.2
	%i.2 =w add %i.1, %b
	%x =w csltl %i.2, 10
	jnz %x, @loop, @end
@end
	%isel.3 =w copy 2
	%c.1 =w mul %i.2, %isel.3
	R7 =w copy %c.1
	ret0 0001
}

**** Function gcm_test2 ****
> After instruction selection:
function $gcm_test2() {
@start
	%a =w copy R7
	%isel.14 =w copy 0
	%isel.13 =w copy 1
	%isel.12 =w copy 0
@loop
	%x.6 =w phi @start %isel.12, @if_false %x.8
	%f.7 =w phi @start %isel.13, @if_false %f.9
	%s.1 =w phi @start %isel.14, @if_false %s.2
	jnz %a, @if, @end
@if
	jnz %f.7, @if_true, @if_false
@if_true
	%x.11 =w add %x.6, 1
	%isel.15 =w copy 0
@if_false
	%x.8 =w phi @if %x.6, @if_true %x.11
	%f.9 =w phi @if %f.7, @if_true %isel.15
	%s.2 =w add %s.1, %x.8
	jmp @loop
@end
	ret0
}

