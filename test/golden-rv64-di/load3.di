**** Function rand ****
> After instruction selection:
function $rand() {
@start
	%isel.1 =w copy 0
	R7 =w copy %isel.1
	ret0 0001
}

**** Function chk ****
> After instruction selection:
function $chk() {
@start
	%b =w copy R8
	%a =w copy R7
	%isel.3 =w xor %a, 1
	%ok =w reqz %isel.3
	%isel.2 =w xor %b, 0
	%ok1 =w reqz %isel.2
	%ok2 =w and %ok, %ok1
	%ret =w xor %ok2, 1
	R7 =w copy %ret
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.8 =w copy 1
	storew %isel.8, S0
	%isel.7 =l addr S0
	%s04 =l add %isel.7, 4
	%isel.6 =w copy 0
	storew %isel.6, %s04
	call $rand, 0001
	%rnd =w copy R7
@blit
	%isel.10 =w copy 0
	R8 =w copy %isel.10
	%isel.9 =w copy 1
	R7 =w copy %isel.9
	call $chk, 0021
	%ret =w copy R7
	R7 =w copy %ret
	ret0 0001
}

