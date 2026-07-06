**** Function f ****
> After instruction selection:
function $f() {
@start
	%a =l copy R5
@loop
	%b =l phi @start 42, @loop0 %a1, @loop1 %a1
	%a0 =l phi @start %a, @loop0 %a1, @loop1 %a1
	%a1 =l sub %a0, 1
	xcmpw 0, %b
	jfine @loop0, @loop1
@loop0
	%snk.1 =l sub %a0, 1
	copy %snk.1
	jfine @loop, @end
@loop1
	%snk.2 =l sub %a0, 1
	copy %snk.2
	jfine @loop, @end
@end
	R1 =l copy %b
	ret0 0001
}

