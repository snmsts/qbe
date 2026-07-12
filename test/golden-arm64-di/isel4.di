**** Function f0 ****
> After instruction selection:
function $f0() {
@start
	%b =l copy R2
	%a =l copy R1
	%isel.2 =l copy 2
	%c =l add %b, %isel.2
	%isel.1 =l copy 4
	%d =l mul %c, %isel.1
	%e =l add %a, %d
	%q =l loadsw %e
	R1 =w copy %q
	ret0 0001
}

**** Function f1 ****
> After instruction selection:
function $f1() {
@start
	%b =l copy R2
	%a =l copy R1
	%isel.4 =l copy 2
	%f =l add %b, %isel.4
	%isel.3 =l copy 4
	%d =l mul %f, %isel.3
	%e =l add %a, %d
	%q =l loadsw %e
	R1 =w copy %q
	ret0 0001
}

**** Function f2 ****
> After instruction selection:
function $f2() {
@start
	%b =l copy R2
	%a =l copy R1
	%isel.6 =l copy 4
	%l =l mul %b, %isel.6
	%isel.5 =l copy 8
	%d =l add %l, %isel.5
	%e =l add %a, %d
	%q =l loadsw %e
	R1 =w copy %q
	ret0 0001
}

**** Function f3 ****
> After instruction selection:
function $f3() {
@start
	%b =l copy R2
	%a =l copy R1
	%isel.8 =l copy 4
	%l =l mul %b, %isel.8
	%isel.7 =l copy 8
	%f =l add %l, %isel.7
	%e =l add %a, %f
	%q =l loadsw %e
	R1 =w copy %q
	ret0 0001
}

**** Function f4 ****
> After instruction selection:
function $f4() {
@start
	%b =l copy R2
	%a =l copy R1
	%isel.11 =l copy 1
	%c =l add %b, %isel.11
	%isel.10 =l copy 4
	%d =l mul %c, %isel.10
	%isel.9 =l copy 4
	%e =l add %d, %isel.9
	%f =l add %a, %e
	%q =l loadsw %f
	R1 =w copy %q
	ret0 0001
}

