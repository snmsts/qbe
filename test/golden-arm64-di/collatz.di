**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%n =w phi @start 1, @newm %n9, @oldm %n9
	%cmax =w phi @start 0, @newm %c, @oldm %cmax
	acmpw %n, 1000
	jfislt @cloop, @end
@cloop
	%n0 =w phi @loop %n, @odd %n2, @even %n3
	%c0 =w phi @loop 0, @odd %c1, @even %c1
	acmpw %n0, 1
	jfine @iter0, @endcl
@iter0
	acmpw %n0, %n
	jfislt @getmemo, @iter1
@iter1
	%isel.2 =w copy 1
	%c1 =w add %c0, %isel.2
	%isel.1 =w copy 1
	%p =w and %n0, %isel.1
	acmpw %p, 0
	jfine @odd, @even
@odd
	%isel.4 =w copy 3
	%n1 =w mul %n0, %isel.4
	%isel.3 =w copy 1
	%n2 =w add %n1, %isel.3
	jmp @cloop
@even
	%isel.5 =w copy 1
	%n3 =w shr %n0, %isel.5
	jmp @cloop
@getmemo
	%n0l =l extsw %n0
	%isel.7 =l copy 4
	%idx0 =l mul %n0l, %isel.7
	%isel.6 =l addr S0
	%loc0 =l add %isel.6, %idx0
	%cn0 =w loadsw %loc0
	%c2 =w add %c0, %cn0
@endcl
	%c =w phi @getmemo %c2, @cloop %c0
	%nl =l extsw %n
	%isel.10 =l copy 4
	%idx1 =l mul %nl, %isel.10
	%isel.9 =l addr S0
	%loc1 =l add %isel.9, %idx1
	storew %c, %loc1
	%isel.8 =w copy 1
	%n9 =w add %n, %isel.8
	acmpw %cmax, %c
	jfisle @newm, @oldm
@newm
	jmp @loop
@oldm
	jmp @loop
@end
	%isel.11 =l copy $a
	storew %cmax, %isel.11
	ret0
}

