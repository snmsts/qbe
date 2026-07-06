**** Function f1 ****
> After instruction selection:
function $f1() {
@start
	R1 =w copy 4294967295
	ret0 0001
}

**** Function f2 ****
> After instruction selection:
function $f2() {
@start
	%isel.1 =w copy 8
	R1 =w copy 4294967040
	R3 =w sign R1
	xidivw %isel.1
	copy R3
	%x =w copy R1
	R1 =w copy %x
	ret0 0001
}

**** Function f3 ****
> After instruction selection:
function $f3() {
@start
	%isel.2 =w copy 7
	R1 =w copy 4294967284
	R3 =w sign R1
	xidivw %isel.2
	copy R1
	%x =w copy R3
	R1 =w copy %x
	ret0 0001
}

**** Function f4 ****
> After instruction selection:
function $f4() {
@start
	R1 =w copy 0
	ret0 0001
}

**** Function f5 ****
> After instruction selection:
function $f5() {
@start
	%x =w shr 1, 0
	R1 =w copy %x
	ret0 0001
}

**** Function f6 ****
> After instruction selection:
function $f6() {
@start
	%isel.3 =w copy 7
	R1 =w copy 0
	R3 =w copy 0
	xdivw %isel.3
	copy R1
	%x =w copy R3
	R1 =w copy %x
	ret0 0001
}

