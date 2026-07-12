**** Function main ****
> After instruction selection:
function $main() {
@start
	%argv =l copy R2
	%argc =w copy R1
	%isel.7 =l addr S0
	%isel.6 =l copy 1663398693
	storel %isel.6, %isel.7
	%isel.5 =l copy 8
	%av0 =l add %argv, %isel.5
	%isel.4 =w copy 1
	%ac0 =w sub %argc, %isel.4
@loop
	%av =l phi @start %av0, @loop2 %av1
	%ac =w phi @start %ac0, @loop2 %ac1
	acmpw %ac, 0
	jfieq @end, @loop1
@loop1
	acmpw %ac, 1
	jfieq @last, @nolast
@last
	jmp @loop2
@nolast
@loop2
	%sep =w phi @last 10, @nolast 32
	%arg =l load %av
	%isel.14 =l copy 16
	R32 =l sub R32, %isel.14
	%isel.13 =l copy 8
	%abi.3 =l add R32, %isel.13
	storew %sep, %abi.3
	%isel.12 =l copy 0
	%abi.2 =l add R32, %isel.12
	storel %arg, %abi.2
	%isel.11 =l addr S0
	R1 =l copy %isel.11
	call $printf, 0021
	%r =w copy R1
	%isel.10 =l copy 16
	R32 =l add R32, %isel.10
	%isel.9 =l copy 8
	%av1 =l add %av, %isel.9
	%isel.8 =w copy 1
	%ac1 =w sub %ac, %isel.8
	jmp @loop
@end
	%isel.15 =w copy 0
	R1 =w copy %isel.15
	ret0 0001
}

