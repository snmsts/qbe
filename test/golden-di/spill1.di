**** Function f ****
> After instruction selection:
function $f() {
@start
	%n0 =w copy R5
@loop
	%n1 =w phi @start %n0, @loop %n2
	%p0 =w phi @start 0, @loop %p01
	%p1 =w phi @start 0, @loop %p11
	%p2 =w phi @start 0, @loop %p21
	%p3 =w phi @start 0, @loop %p31
	%p4 =w phi @start 0, @loop %p41
	%p5 =w phi @start 0, @loop %p51
	%p6 =w phi @start 0, @loop %p61
	%p7 =w phi @start 0, @loop %p71
	%p8 =w phi @start 0, @loop %p81
	%p9 =w phi @start 0, @loop %p91
	%pa =w phi @start 0, @loop %pa1
	%pb =w phi @start 0, @loop %pb1
	%pc =w phi @start 0, @loop %pc1
	%pd =w phi @start 0, @loop %pd1
	%pe =w phi @start 0, @loop %pe1
	%pf =w phi @start 0, @loop %pf1
	%p01 =w add %p0, 1
	%p11 =w add %p1, 2
	%p21 =w add %p2, 3
	%p31 =w add %p3, 4
	%p41 =w add %p4, 5
	%p51 =w add %p5, 6
	%p61 =w add %p6, 7
	%p71 =w add %p7, 8
	%p81 =w add %p8, 9
	%p91 =w add %p9, 10
	%pa1 =w add %pa, 11
	%pb1 =w add %pb, 12
	%pc1 =w add %pc, 13
	%pd1 =w add %pd, 14
	%pe1 =w add %pe, 15
	%pf1 =w add %pf, 16
	%n2 =w sub %n1, 1
	jfine @loop, @end
@end
	%a.3 =w add %p01, %p11
	%a.4 =w add %p21, %a.3
	%a.5 =w add %p31, %a.4
	%a.6 =w add %p41, %a.5
	%a.7 =w add %p51, %a.6
	%a.8 =w add %p61, %a.7
	%a.9 =w add %p71, %a.8
	%a.10 =w add %p81, %a.9
	%a.11 =w add %p91, %a.10
	%a.12 =w add %pa1, %a.11
	%a.13 =w add %pb1, %a.12
	%a.14 =w add %pc1, %a.13
	%a.15 =w add %pd1, %a.14
	%a.16 =w add %pe1, %a.15
	%a.17 =w add %pf1, %a.16
	R1 =w copy %a.17
	ret0 0001
}

