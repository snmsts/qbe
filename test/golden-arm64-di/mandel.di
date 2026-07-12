**** Function mandel ****
> After instruction selection:
function $mandel() {
@mandel
	%y =d copy R34
	%x =d copy R33
	%isel.7 =l copy $"Lfp1"
	%isel.6 =d load %isel.7
	%cr =d sub %y, %isel.6
	%isel.5 =l copy $"Lfp0"
	%isel.4 =d load %isel.5
	%isel.3 =l copy $"Lfp0"
	%isel.2 =d load %isel.3
@loop
	%i =w phi @mandel 0, @loop1 %i1
	%zr =d phi @mandel %isel.2, @loop1 %zr1
	%zi =d phi @mandel %isel.4, @loop1 %zi1
	%isel.10 =w copy 1
	%i1 =w add %i, %isel.10
	%zr2 =d mul %zr, %zr
	%zi2 =d mul %zi, %zi
	%sum =d add %zr2, %zi2
	%isel.9 =l copy $"Lfp2"
	%isel.8 =d load %isel.9
	afcmpd %sum, %isel.8
	jffgt @reti, @loop1
@loop1
	%zrx =d sub %zr2, %zi2
	%zr1 =d add %cr, %zrx
	%tmp =d mul %zr, %zi
	%zix =d add %tmp, %tmp
	%zi1 =d add %x, %zix
	acmpw %i1, 1000
	jfisgt @ret0, @loop
@reti
	%isel.11 =w copy 1
	%snk.1 =w add %i, %isel.11
	R1 =w copy %snk.1
	ret0 0001
@ret0
	%isel.12 =w copy 0
	R1 =w copy %isel.12
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@main
	%isel.14 =l copy $"Lfp3"
	%isel.13 =d load %isel.14
@loopy
	%y =d phi @main %isel.13, @loopy1 %y1
	%isel.16 =l copy $"Lfp3"
	%isel.15 =d load %isel.16
@loopx
	%x =d phi @loopy %isel.15, @loopx1 %x1
	R34 =d copy %y
	R33 =d copy %x
	call $mandel, 0401
	%i =w copy R1
	acmpw %i, 0
	jfine @out, @in
@in
	%isel.17 =w copy 42
	R1 =w copy %isel.17
	call $putchar, 0021
	%r0 =w copy R1
	jmp @loopx1
@out
	%isel.18 =w copy 32
	R1 =w copy %isel.18
	call $putchar, 0021
	%r1 =w copy R1
@loopx1
	%isel.22 =l copy $"Lfp5"
	%isel.21 =d load %isel.22
	%x1 =d add %x, %isel.21
	%isel.20 =l copy $"Lfp4"
	%isel.19 =d load %isel.20
	afcmpd %x1, %isel.19
	jffgt @loopy1, @loopx
@loopy1
	%isel.27 =w copy 10
	R1 =w copy %isel.27
	call $putchar, 0021
	%r2 =w copy R1
	%isel.26 =l copy $"Lfp5"
	%isel.25 =d load %isel.26
	%y1 =d add %y, %isel.25
	%isel.24 =l copy $"Lfp4"
	%isel.23 =d load %isel.24
	afcmpd %y1, %isel.23
	jffgt @ret, @loopy
@ret
	%isel.28 =w copy 0
	R1 =w copy %isel.28
	ret0 0001
}

