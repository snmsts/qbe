**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.8 =l copy 16
	R32 =l sub R32, %isel.8
	%isel.7 =l copy 0
	%abi.1 =l add R32, %isel.7
	%isel.6 =l copy $"Lfp0"
	%isel.5 =d load %isel.6
	stored %isel.5, %abi.1
	%isel.4 =l copy $fmt
	R1 =l copy %isel.4
	call $printf, 0021
	%x =w copy R1
	%isel.3 =l copy 16
	R32 =l add R32, %isel.3
	%isel.2 =w copy 0
	R1 =w copy %isel.2
	ret0 0001
}

