**** Function f ****
> After instruction selection:
function $f() {
@start
	%a =l copy R1
@loop
	%b =l phi @start 42, @loop0 %a1, @loop1 %a1
	%a0 =l phi @start %a, @loop0 %a1, @loop1 %a1
	%isel.3 =l copy 1
	%a1 =l sub %a0, %isel.3
	acmpw %b, 0
	jfine @loop0, @loop1
@loop0
	%isel.4 =l copy 1
	%snk.1 =l sub %a0, %isel.4
	acmpw %snk.1, 0
	jfine @loop, @end
@loop1
	%isel.5 =l copy 1
	%snk.2 =l sub %a0, %isel.5
	acmpw %snk.2, 0
	jfine @loop, @end
@end
	R1 =l copy %b
	ret0 0001
}

