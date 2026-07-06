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
	%arg =w copy R5
	call $g, 0001
	copy R1
	%isel.2 =l copy 180388626474
	storel %isel.2, [S0]
	%isel.1 =l copy 180388626474
	storel %isel.1, [8 + S0]
	R1 =w copy %arg
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	R5 =w copy 0
	call $f, 0011
	%a =w copy R1
	R5 =w copy 0
	call $f, 0011
	%b =w copy R1
	R1 =w copy %a
	ret0 0001
}

