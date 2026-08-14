**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.3 =w copy 4
	storew %isel.3, S0
	%isel.2 =w copy 5
	storew %isel.2, S1
	%isel.1 =l addr S0
@loop
	%mem =l phi @start %isel.1, @loop %isel.4
	%w =w load %mem
	%isel.5 =w xor %w, 5
	%eq5 =w reqz %isel.5
	%isel.4 =l addr S1
	jnz %eq5, @exit, @loop
@exit
	%isel.6 =w copy 0
	R7 =w copy %isel.6
	ret0 0001
}

