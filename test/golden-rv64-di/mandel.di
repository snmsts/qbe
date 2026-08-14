**** Function mandel ****
> After instruction selection:
function $mandel() {
@mandel
	%y =d copy R43
	%x =d copy R42
	%isel.5 =d load $".Lfp1"
	%cr =d sub %y, %isel.5
	%isel.4 =d load $".Lfp0"
	%isel.3 =d load $".Lfp0"
	%isel.2 =w copy 0
@loop
	%i =w phi @mandel %isel.2, @loop1 %i1
	%zr =d phi @mandel %isel.3, @loop1 %zr1
	%zi =d phi @mandel %isel.4, @loop1 %zi1
	%i1 =w add %i, 1
	%zr2 =d mul %zr, %zr
	%zi2 =d mul %zi, %zi
	%sum =d add %zr2, %zi2
	%isel.6 =d load $".Lfp2"
	%cmp1 =w cgtd %sum, %isel.6
	jnz %cmp1, @reti, @loop1
@loop1
	%isel.7 =w copy 1000
	%cmp2 =w csltl %isel.7, %i1
	%zrx =d sub %zr2, %zi2
	%zr1 =d add %cr, %zrx
	%tmp =d mul %zr, %zi
	%zix =d add %tmp, %tmp
	%zi1 =d add %x, %zix
	jnz %cmp2, @ret0, @loop
@reti
	%snk.1 =w add %i, 1
	R7 =w copy %snk.1
	ret0 0001
@ret0
	%isel.8 =w copy 0
	R7 =w copy %isel.8
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@main
	%isel.9 =d load $".Lfp3"
@loopy
	%y =d phi @main %isel.9, @loopy1 %y1
	%isel.10 =d load $".Lfp3"
@loopx
	%x =d phi @loopy %isel.10, @loopx1 %x1
	R43 =d copy %y
	R42 =d copy %x
	call $mandel, 0201
	%i =w copy R7
	jnz %i, @out, @in
@in
	%isel.11 =w copy 42
	R7 =w copy %isel.11
	call $putchar, 0011
	%r0 =w copy R7
	jmp @loopx1
@out
	%isel.12 =w copy 32
	R7 =w copy %isel.12
	call $putchar, 0011
	%r1 =w copy R7
@loopx1
	%isel.14 =d load $".Lfp5"
	%x1 =d add %x, %isel.14
	%isel.13 =d load $".Lfp4"
	%cmp1 =w cgtd %x1, %isel.13
	jnz %cmp1, @loopy1, @loopx
@loopy1
	%isel.17 =w copy 10
	R7 =w copy %isel.17
	call $putchar, 0011
	%r2 =w copy R7
	%isel.16 =d load $".Lfp5"
	%y1 =d add %y, %isel.16
	%isel.15 =d load $".Lfp4"
	%cmp2 =w cgtd %y1, %isel.15
	jnz %cmp2, @ret, @loopy
@ret
	%isel.18 =w copy 0
	R7 =w copy %isel.18
	ret0 0001
}

