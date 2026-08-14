**** Function f ****
> After instruction selection:
function $f() {
@start
	%n0 =w copy R7
	%isel.33 =w copy 0
	%isel.32 =w copy 0
	%isel.31 =w copy 0
	%isel.30 =w copy 0
	%isel.29 =w copy 0
	%isel.28 =w copy 0
	%isel.27 =w copy 0
	%isel.26 =w copy 0
	%isel.25 =w copy 0
	%isel.24 =w copy 0
	%isel.23 =w copy 0
	%isel.22 =w copy 0
	%isel.21 =w copy 0
	%isel.20 =w copy 0
	%isel.19 =w copy 0
	%isel.18 =w copy 0
@loop
	%n1 =w phi @start %n0, @loop %n2
	%p0 =w phi @start %isel.18, @loop %p01
	%p1 =w phi @start %isel.19, @loop %p11
	%p2 =w phi @start %isel.20, @loop %p21
	%p3 =w phi @start %isel.21, @loop %p31
	%p4 =w phi @start %isel.22, @loop %p41
	%p5 =w phi @start %isel.23, @loop %p51
	%p6 =w phi @start %isel.24, @loop %p61
	%p7 =w phi @start %isel.25, @loop %p71
	%p8 =w phi @start %isel.26, @loop %p81
	%p9 =w phi @start %isel.27, @loop %p91
	%pa =w phi @start %isel.28, @loop %pa1
	%pb =w phi @start %isel.29, @loop %pb1
	%pc =w phi @start %isel.30, @loop %pc1
	%pd =w phi @start %isel.31, @loop %pd1
	%pe =w phi @start %isel.32, @loop %pe1
	%pf =w phi @start %isel.33, @loop %pf1
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
	%isel.34 =w copy 1
	%n2 =w sub %n1, %isel.34
	jnz %n2, @loop, @end
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
	R7 =w copy %a.17
	ret0 0001
}

