**** Function rand ****
> After instruction selection:
function $rand() {
@start
	%isel.1 =w copy 0
	R1 =w copy %isel.1
	ret0 0001
}

**** Function chk ****
> After instruction selection:
function $chk() {
@start
	%b =w copy R2
	%a =w copy R1
	acmpw %a, 1
	%ok =w flagieq
	acmpw %b, 0
	%ok1 =w flagieq
	%ok2 =w and %ok, %ok1
	%isel.2 =w copy 1
	%ret =w xor %ok2, %isel.2
	R1 =w copy %ret
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.9 =l addr S0
	%isel.8 =w copy 1
	storew %isel.8, %isel.9
	%isel.7 =l copy 4
	%isel.6 =l addr S0
	%s04 =l add %isel.6, %isel.7
	%isel.5 =w copy 0
	storew %isel.5, %s04
	call $rand, 0001
	%rnd =w copy R1
@blit
	%isel.11 =w copy 0
	R2 =w copy %isel.11
	%isel.10 =w copy 1
	R1 =w copy %isel.10
	call $chk, 0041
	%ret =w copy R1
	R1 =w copy %ret
	ret0 0001
}

