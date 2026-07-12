**** Function f1 ****
> After instruction selection:
function $f1() {
@start
	%isel.1 =w copy 4294967295
	R1 =w copy %isel.1
	ret0 0001
}

**** Function f2 ****
> After instruction selection:
function $f2() {
@start
	%isel.3 =w copy 8
	%isel.2 =w copy 4294967040
	%x =w div %isel.2, %isel.3
	R1 =w copy %x
	ret0 0001
}

**** Function f3 ****
> After instruction selection:
function $f3() {
@start
	%isel.5 =w copy 7
	%isel.4 =w copy 4294967284
	%x =w rem %isel.4, %isel.5
	R1 =w copy %x
	ret0 0001
}

**** Function f4 ****
> After instruction selection:
function $f4() {
@start
	%isel.6 =w copy 0
	R1 =w copy %isel.6
	ret0 0001
}

**** Function f5 ****
> After instruction selection:
function $f5() {
@start
	%isel.8 =w copy 0
	%isel.7 =w copy 1
	%x =w shr %isel.7, %isel.8
	R1 =w copy %x
	ret0 0001
}

**** Function f6 ****
> After instruction selection:
function $f6() {
@start
	%isel.10 =w copy 7
	%isel.9 =w copy 0
	%x =w urem %isel.9, %isel.10
	R1 =w copy %x
	ret0 0001
}

