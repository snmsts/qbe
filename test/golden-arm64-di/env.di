**** Function epar ****
> After instruction selection:
function $epar() {
@start
	%i =l copy R1
	%e =l copy R10
	%x =l add %e, %i
	R1 =l copy %x
	ret0 0001
}

**** Function earg ****
> After instruction selection:
function $earg() {
@start
	%b =l copy R2
	%a =l copy R1
	R1 =l copy %b
	R10 =l copy %a
	call $epar, 4021
	%r1 =l copy R1
	R1 =l copy %r1
	%isel.1 =l copy 113
	R10 =l copy %isel.1
	call $labs, 4021
	%r2 =l copy R1
	R1 =l copy %r2
	ret0 0001
}

