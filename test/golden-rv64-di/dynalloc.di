**** Function g ****
> After instruction selection:
function $g() {
@start
	ret0
}

**** Function f ****
> After instruction selection:
function $f() {
@start
	%arg =w copy R7
	call $g, 0001
	copy R7
	%isel.3 =l copy 180388626474
	storel %isel.3, S0
	%isel.2 =l addr S0
	%r8 =l add %isel.2, 8
	%isel.1 =l copy 180388626474
	storel %isel.1, %r8
	R7 =w copy %arg
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.5 =w copy 0
	R7 =w copy %isel.5
	call $f, 0011
	%a =w copy R7
	%isel.4 =w copy 0
	R7 =w copy %isel.4
	call $f, 0011
	%b =w copy R7
	R7 =w copy %a
	ret0 0001
}

