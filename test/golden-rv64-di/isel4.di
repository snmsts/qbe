**** Function f0 ****
> After instruction selection:
function $f0() {
@start
	%b =l copy R8
	%a =l copy R7
	%c =l add %b, 2
	%isel.2 =l copy 4
	%d =l mul %c, %isel.2
	%e =l add %a, %d
	%q =l loadsw %e
	%isel.1 =l extsw %q
	R7 =w copy %isel.1
	ret0 0001
}

**** Function f1 ****
> After instruction selection:
function $f1() {
@start
	%b =l copy R8
	%a =l copy R7
	%f =l add %b, 2
	%isel.4 =l copy 4
	%d =l mul %f, %isel.4
	%e =l add %a, %d
	%q =l loadsw %e
	%isel.3 =l extsw %q
	R7 =w copy %isel.3
	ret0 0001
}

**** Function f2 ****
> After instruction selection:
function $f2() {
@start
	%b =l copy R8
	%a =l copy R7
	%isel.6 =l copy 4
	%l =l mul %b, %isel.6
	%d =l add %l, 8
	%e =l add %a, %d
	%q =l loadsw %e
	%isel.5 =l extsw %q
	R7 =w copy %isel.5
	ret0 0001
}

**** Function f3 ****
> After instruction selection:
function $f3() {
@start
	%b =l copy R8
	%a =l copy R7
	%isel.8 =l copy 4
	%l =l mul %b, %isel.8
	%f =l add %l, 8
	%e =l add %a, %f
	%q =l loadsw %e
	%isel.7 =l extsw %q
	R7 =w copy %isel.7
	ret0 0001
}

**** Function f4 ****
> After instruction selection:
function $f4() {
@start
	%b =l copy R8
	%a =l copy R7
	%c =l add %b, 1
	%isel.10 =l copy 4
	%d =l mul %c, %isel.10
	%e =l add %d, 4
	%f =l add %a, %e
	%q =l loadsw %f
	%isel.9 =l extsw %q
	R7 =w copy %isel.9
	ret0 0001
}

