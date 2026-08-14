**** Function f ****
> After instruction selection:
function $f() {
@start
	%a =l copy R7
	%isel.3 =l copy 42
@loop
	%b =l phi @start %isel.3, @loop0 %a1, @loop1 %a1
	%a0 =l phi @start %a, @loop0 %a1, @loop1 %a1
	%isel.5 =l copy 1
	%a1 =l sub %a0, %isel.5
	%isel.4 =l extsw %b
	jnz %isel.4, @loop0, @loop1
@loop0
	%isel.7 =l copy 1
	%snk.1 =l sub %a0, %isel.7
	%isel.6 =l extsw %snk.1
	jnz %isel.6, @loop, @end
@loop1
	%isel.9 =l copy 1
	%snk.2 =l sub %a0, %isel.9
	%isel.8 =l extsw %snk.2
	jnz %isel.8, @loop, @end
@end
	R7 =l copy %b
	ret0 0001
}

