**** Function f ****
> After instruction selection:
function $f() {
@start
	%n0 =w copy R1
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
	%isel.34 =w copy 1
	%p01 =w add %p0, %isel.34
	%isel.33 =w copy 2
	%p11 =w add %p1, %isel.33
	%isel.32 =w copy 3
	%p21 =w add %p2, %isel.32
	%isel.31 =w copy 4
	%p31 =w add %p3, %isel.31
	%isel.30 =w copy 5
	%p41 =w add %p4, %isel.30
	%isel.29 =w copy 6
	%p51 =w add %p5, %isel.29
	%isel.28 =w copy 7
	%p61 =w add %p6, %isel.28
	%isel.27 =w copy 8
	%p71 =w add %p7, %isel.27
	%isel.26 =w copy 9
	%p81 =w add %p8, %isel.26
	%isel.25 =w copy 10
	%p91 =w add %p9, %isel.25
	%isel.24 =w copy 11
	%pa1 =w add %pa, %isel.24
	%isel.23 =w copy 12
	%pb1 =w add %pb, %isel.23
	%isel.22 =w copy 13
	%pc1 =w add %pc, %isel.22
	%isel.21 =w copy 14
	%pd1 =w add %pd, %isel.21
	%isel.20 =w copy 15
	%pe1 =w add %pe, %isel.20
	%isel.19 =w copy 16
	%pf1 =w add %pf, %isel.19
	%isel.18 =w copy 1
	%n2 =w sub %n1, %isel.18
	acmpw %n2, 0
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

