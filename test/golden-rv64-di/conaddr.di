**** Function f0 ****
> After instruction selection:
function $f0() {
@start
	%o =l copy R7
	%isel.1 =l copy $a
	%addr =l add %o, %isel.1
	%char =w loadub %addr
	R7 =w copy %char
	ret0 0001
}

**** Function f1 ****
> After instruction selection:
function $f1() {
@start
	%o =l copy R7
	%addr =l add %o, 10
	%char =w loadub %addr
	R7 =w copy %char
	ret0 0001
}

**** Function f2 ****
> After instruction selection:
function $f2() {
@start
	%o2 =l copy R8
	%o1 =l copy R7
	%isel.3 =l copy 2
	%o22 =l mul %o2, %isel.3
	%o =l add %o1, %o22
	%isel.2 =l copy $a
	%addr =l add %o, %isel.2
	%char =w loadub %addr
	R7 =w copy %char
	ret0 0001
}

**** Function f3 ****
> After instruction selection:
function $f3() {
@start
	%o =l copy R7
	%isel.4 =l copy $a
	%addr =l add %o, %isel.4
	R7 =l copy %addr
	ret0 0001
}

**** Function f4 ****
> After instruction selection:
function $f4() {
@start
	%isel.5 =l copy $p
	storel %isel.5, $p
	ret0
}

**** Function writeto0 ****
> After instruction selection:
function $writeto0() {
@start
	%isel.7 =l copy 0
	%isel.6 =l copy 0
	storel %isel.6, %isel.7
	ret0
}

