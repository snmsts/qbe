**** Function epar ****
> After instruction selection:
function $epar() {
@start
	%i =l copy R7
	%e =l copy R6
	%x =l add %e, %i
	R7 =l copy %x
	ret0 0001
}

**** Function earg ****
> After instruction selection:
function $earg() {
@start
	%b =l copy R8
	%a =l copy R7
	R7 =l copy %b
	R6 =l copy %a
	call $epar, 1011
	%r1 =l copy R7
	R7 =l copy %r1
	%isel.1 =l copy 113
	R6 =l copy %isel.1
	call $labs, 1011
	%r2 =l copy R7
	R7 =l copy %r2
	ret0 0001
}

