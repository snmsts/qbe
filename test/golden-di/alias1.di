**** Function main ****
> After instruction selection:
function $main() {
@start
	storew 4, [S0]
	storew 5, [S1]
	%isel.1 =l addr S0
@loop
	%mem =l phi @start %isel.1, @loop %isel.2
	%w =w load [%mem]
	xcmpw 5, %w
	%isel.2 =l addr S1
	jfieq @exit, @loop
@exit
	R1 =w copy 0
	ret0 0001
}

