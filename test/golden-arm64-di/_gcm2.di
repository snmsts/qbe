**** Function gcm_test ****
> After instruction selection:
function $gcm_test() {
@start
	%a =w copy R1
	%isel.2 =w copy 1
	%b =w add %a, %isel.2
@loop
	%i.1 =w phi @start 0, @loop %i.2
	%i.2 =w add %i.1, %b
	acmpw %i.2, 10
	jfislt @loop, @end
@end
	%isel.3 =w copy 2
	%c.1 =w mul %i.2, %isel.3
	R1 =w copy %c.1
	ret0 0001
}

**** Function gcm_test2 ****
> After instruction selection:
function $gcm_test2() {
@start
	%a =w copy R1
@loop
	%x.6 =w phi @start 0, @if_false %x.8
	%f.7 =w phi @start 1, @if_false %f.9
	%s.1 =w phi @start 0, @if_false %s.2
	acmpw %a, 0
	jfine @if, @end
@if
	acmpw %f.7, 0
	jfine @if_true, @if_false
@if_true
	%isel.12 =w copy 1
	%x.11 =w add %x.6, %isel.12
@if_false
	%x.8 =w phi @if %x.6, @if_true %x.11
	%f.9 =w phi @if %f.7, @if_true 0
	%s.2 =w add %s.1, %x.8
	jmp @loop
@end
	ret0
}

