**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.2 =w copy 0
	%isel.1 =w copy 1
@loop
	%n =w phi @start %isel.1, @newm %n9, @oldm %n9
	%cmax =w phi @start %isel.2, @newm %c, @oldm %cmax
	%fin =w csltl %n, 1000
	%isel.3 =w copy 0
	jnz %fin, @cloop, @end
@cloop
	%n0 =w phi @loop %n, @odd %n2, @even %n3
	%c0 =w phi @loop %isel.3, @odd %c1, @even %c1
	%isel.4 =w xor %n0, 1
	%no1 =w rnez %isel.4
	jnz %no1, @iter0, @endcl
@iter0
	%ism =w csltl %n0, %n
	jnz %ism, @getmemo, @iter1
@iter1
	%c1 =w add %c0, 1
	%p =w and %n0, 1
	jnz %p, @odd, @even
@odd
	%isel.5 =w copy 3
	%n1 =w mul %n0, %isel.5
	%n2 =w add %n1, 1
	jmp @cloop
@even
	%n3 =w shr %n0, 1
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
	%n9 =w add %n, 1
	%isel.8 =w csltl %c, %cmax
	%big =w xor %isel.8, 1
	jnz %big, @newm, @oldm
@newm
	jmp @loop
@oldm
	jmp @loop
@end
	storew %cmax, $a
	ret0
}

