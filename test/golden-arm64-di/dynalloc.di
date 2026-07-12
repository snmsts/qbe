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
	%arg =w copy R1
	call $g, 0001
	copy R1
	%isel.5 =l addr S0
	%isel.4 =l copy 180388626474
	storel %isel.4, %isel.5
	%isel.3 =l copy 8
	%isel.2 =l addr S0
	%r8 =l add %isel.2, %isel.3
	%isel.1 =l copy 180388626474
	storel %isel.1, %r8
	R1 =w copy %arg
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.7 =w copy 0
	R1 =w copy %isel.7
	call $f, 0021
	%a =w copy R1
	%isel.6 =w copy 0
	R1 =w copy %isel.6
	call $f, 0021
	%b =w copy R1
	R1 =w copy %a
	ret0 0001
}

