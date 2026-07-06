**** Function gcm_test ****
> After instruction selection:
function $gcm_test() {
@start
	%a =w copy R5
	%b =w add %a, 1
@loop
	%i.1 =w phi @start 0, @loop %i.2
	%i.2 =w add %i.1, %b
	xcmpw 10, %i.2
	jfislt @loop, @end
@end
	%c.1 =w mul %i.2, 2
	R1 =w copy %c.1
	ret0 0001
}

**** Function gcm_test2 ****
> After instruction selection:
function $gcm_test2() {
@start
	%a =w copy R5
@loop
	%x.4 =w phi @start 0, @if_false %x.6
	%f.5 =w phi @start 1, @if_false %f.7
	%s.1 =w phi @start 0, @if_false %s.2
	xcmpw 0, %a
	jfine @if, @end
@if
	%x.9 =w add %x.4, 1
	xcmpw 0, %f.5
	%x.6 =w xseline %x.9, %x.4
	%isel.10 =w copy 0
	%f.7 =w xseline %isel.10, %f.5
@if_false
	%s.2 =w add %s.1, %x.6
	jmp @loop
@end
	ret0
}

