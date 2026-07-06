**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%n =w phi @start 1, @newm %n9, @oldm %n9
	%cmax =w phi @start 0, @newm %c, @oldm %cmax
	xcmpw 1000, %n
	jfislt @cloop, @end
@cloop
	%n0 =w phi @loop %n, @odd %n2, @even %n3
	%c0 =w phi @loop 0, @odd %c1, @even %c1
	xcmpw 1, %n0
	jfine @iter0, @endcl
@iter0
	xcmpw %n, %n0
	jfislt @getmemo, @iter1
@iter1
	%c1 =w add %c0, 1
	xtestw 1, %n0
	jfine @odd, @even
@odd
	%n1 =w mul %n0, 3
	%n2 =w add %n1, 1
	jmp @cloop
@even
	%n3 =w shr %n0, 1
	jmp @cloop
@getmemo
	%n0l =l extsw %n0
	%cn0 =w loadsw [S0 + 4 * %n0l]
	%c2 =w add %c0, %cn0
@endcl
	%c =w phi @getmemo %c2, @cloop %c0
	%nl =l extsw %n
	storew %c, [S0 + 4 * %nl]
	%n9 =w add %n, 1
	xcmpw %c, %cmax
	jfisle @newm, @oldm
@newm
	jmp @loop
@oldm
	jmp @loop
@end
	storew %cmax, $a
	ret0
}

