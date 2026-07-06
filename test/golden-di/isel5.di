**** Function main ****
> After instruction selection:
function $main() {
@start
	R17 =d copy [$".Lfp0"]
	%isel.1 =l addr $fmt
	R5 =l copy %isel.1
	R1 =w copy 1
	call $printf, 1111
	%x =w copy R1
	R1 =w copy 0
	ret0 0001
}

