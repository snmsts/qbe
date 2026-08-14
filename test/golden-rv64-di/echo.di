**** Function main ****
> After instruction selection:
function $main() {
@start
	%argv =l copy R8
	%argc =w copy R7
	%isel.3 =l copy 1663398693
	storel %isel.3, S0
	%av0 =l add %argv, 8
	%isel.2 =w copy 1
	%ac0 =w sub %argc, %isel.2
@loop
	%av =l phi @start %av0, @loop2 %av1
	%ac =w phi @start %ac0, @loop2 %ac1
	%isel.4 =w xor %ac, 0
	%c0 =w reqz %isel.4
	jnz %c0, @end, @loop1
@loop1
	%isel.5 =w xor %ac, 1
	%c1 =w reqz %isel.5
	jnz %c1, @last, @nolast
@last
	%isel.6 =w copy 10
	jmp @loop2
@nolast
	%isel.7 =w copy 32
@loop2
	%sep =w phi @last %isel.6, @nolast %isel.7
	%arg =l load %av
	R9 =w copy %sep
	R8 =l copy %arg
	%isel.9 =l addr S0
	R7 =l copy %isel.9
	call $printf, 0031
	%r =w copy R7
	%av1 =l add %av, 8
	%isel.8 =w copy 1
	%ac1 =w sub %ac, %isel.8
	jmp @loop
@end
	%isel.10 =w copy 0
	R7 =w copy %isel.10
	ret0 0001
}

