**** Function f0 ****
> After instruction selection:
function $f0() {
@start
	%o =l copy R5
	%isel.1 =l addr $a
	%char =w loadub [%isel.1 + 1 * %o]
	R1 =w copy %char
	ret0 0001
}

**** Function f1 ****
> After instruction selection:
function $f1() {
@start
	%o =l copy R5
	%char =w loadub [10 + %o]
	R1 =w copy %char
	ret0 0001
}

**** Function f2 ****
> After instruction selection:
function $f2() {
@start
	%o2 =l copy R4
	%o1 =l copy R5
	%o22 =l mul %o2, 2
	%o =l add %o1, %o22
	%isel.2 =l addr $a
	%addr =l add %o, %isel.2
	%char =w loadub %addr
	R1 =w copy %char
	ret0 0001
}

**** Function f3 ****
> After instruction selection:
function $f3() {
@start
	%o =l copy R5
	%isel.3 =l addr $a
	%addr =l add %o, %isel.3
	R1 =l copy %addr
	ret0 0001
}

**** Function f4 ****
> After instruction selection:
function $f4() {
@start
	%isel.4 =l addr $p
	storel %isel.4, $p
	ret0
}

**** Function writeto0 ****
> After instruction selection:
function $writeto0() {
@start
	storel 0, 0
	ret0
}

