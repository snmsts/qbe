**** Function f0 ****
> After instruction selection:
function $f0() {
@start
	%o =l copy R1
	%isel.1 =l copy $a
	%addr =l add %o, %isel.1
	%char =w loadub %addr
	R1 =w copy %char
	ret0 0001
}

**** Function f1 ****
> After instruction selection:
function $f1() {
@start
	%o =l copy R1
	%isel.2 =l copy 10
	%addr =l add %o, %isel.2
	%char =w loadub %addr
	R1 =w copy %char
	ret0 0001
}

**** Function f2 ****
> After instruction selection:
function $f2() {
@start
	%o2 =l copy R2
	%o1 =l copy R1
	%isel.4 =l copy 2
	%o22 =l mul %o2, %isel.4
	%o =l add %o1, %o22
	%isel.3 =l copy $a
	%addr =l add %o, %isel.3
	%char =w loadub %addr
	R1 =w copy %char
	ret0 0001
}

**** Function f3 ****
> After instruction selection:
function $f3() {
@start
	%o =l copy R1
	%isel.5 =l copy $a
	%addr =l add %o, %isel.5
	R1 =l copy %addr
	ret0 0001
}

**** Function f4 ****
> After instruction selection:
function $f4() {
@start
	%isel.7 =l copy $p
	%isel.6 =l copy $p
	storel %isel.6, %isel.7
	ret0
}

**** Function writeto0 ****
> After instruction selection:
function $writeto0() {
@start
	%isel.9 =l copy 0
	%isel.8 =l copy 0
	storel %isel.8, %isel.9
	ret0
}

