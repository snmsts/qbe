**** Function mandel ****
> After instruction selection:
function $mandel() {
@mandel
	%y =d copy R18
	%x =d copy R17
	%cr =d sub %y, [$".Lfp1"]
@loop
	%i =w phi @mandel 0, @loop1 %i1
	%zr =d phi @mandel [$".Lfp0"], @loop1 %zr1
	%zi =d phi @mandel [$".Lfp0"], @loop1 %zi1
	%i1 =w add %i, 1
	%zr2 =d mul %zr, %zr
	%zi2 =d mul %zi, %zi
	%sum =d add %zr2, %zi2
	xcmpd [$".Lfp2"], %sum
	jffgt @reti, @loop1
@loop1
	xcmpw 1000, %i1
	%cmp2 =w flagisgt
	%zrx =d sub %zr2, %zi2
	%zr1 =d add %cr, %zrx
	%tmp =d mul %zr, %zi
	%zix =d add %tmp, %tmp
	%zi1 =d add %x, %zix
	xcmpw 0, %cmp2
	jfine @ret0, @loop
@reti
	%snk.1 =w add %i, 1
	R1 =w copy %snk.1
	ret0 0001
@ret0
	R1 =w copy 0
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@main
@loopy
	%y =d phi @main [$".Lfp3"], @loopy1 %y1
@loopx
	%x =d phi @loopy [$".Lfp3"], @loopx1 %x1
	R18 =d copy %y
	R17 =d copy %x
	call $mandel, 0201
	%i =w copy R1
	xcmpw 0, %i
	jfine @out, @in
@in
	R5 =w copy 42
	call $putchar, 0011
	%r0 =w copy R1
	jmp @loopx1
@out
	R5 =w copy 32
	call $putchar, 0011
	%r1 =w copy R1
@loopx1
	%x1 =d add %x, [$".Lfp5"]
	xcmpd [$".Lfp4"], %x1
	jffgt @loopy1, @loopx
@loopy1
	R5 =w copy 10
	call $putchar, 0011
	%r2 =w copy R1
	%y1 =d add %y, [$".Lfp5"]
	xcmpd [$".Lfp4"], %y1
	jffgt @ret, @loopy
@ret
	R1 =w copy 0
	ret0 0001
}

