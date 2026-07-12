**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.5 =l addr S0
	%isel.4 =w copy 4
	storew %isel.4, %isel.5
	%isel.3 =l addr S1
	%isel.2 =w copy 5
	storew %isel.2, %isel.3
	%isel.1 =l addr S0
@loop
	%mem =l phi @start %isel.1, @loop %isel.6
	%w =w load %mem
	acmpw %w, 5
	%isel.6 =l addr S1
	jfieq @exit, @loop
@exit
	%isel.7 =w copy 0
	R1 =w copy %isel.7
	ret0 0001
}

