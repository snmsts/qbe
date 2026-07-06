**** Function epar ****
> After instruction selection:
function $epar() {
@start
	%e =l copy R1
	%i =l copy R5
	%x =l add %e, %i
	R1 =l copy %x
	ret0 0001
}

**** Function earg ****
> After instruction selection:
function $earg() {
@start
	%b =l copy R4
	%a =l copy R5
	R5 =l copy %b
	R1 =l copy %a
	call $epar, 1011
	%r1 =l copy R1
	R5 =l copy %r1
	R1 =l copy 113
	call $labs, 1011
	%r2 =l copy R1
	R1 =l copy %r2
	ret0 0001
}

