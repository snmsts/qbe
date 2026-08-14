**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.4 =d load $".Lfp0"
	%abi.1 =l cast %isel.4
	R8 =l copy %abi.1
	%isel.3 =l copy $fmt
	R7 =l copy %isel.3
	call $printf, 0021
	%x =w copy R7
	%isel.2 =w copy 0
	R7 =w copy %isel.2
	ret0 0001
}

