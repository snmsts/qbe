**** Function rand ****
> After instruction selection:
function $rand() {
@start
	R1 =w copy 0
	ret0 0001
}

**** Function chk ****
> After instruction selection:
function $chk() {
@start
	%b =w copy R4
	%a =w copy R5
	xcmpw 1, %a
	%ok =w flagieq
	xcmpw 0, %b
	%ok1 =w flagieq
	%ok2 =w and %ok, %ok1
	%ret =w xor %ok2, 1
	R1 =w copy %ret
	ret0 0001
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	storew 1, [S0]
	storew 0, [4 + S0]
	call $rand, 0001
	%rnd =w copy R1
@blit
	R4 =w copy 0
	R5 =w copy 1
	call $chk, 0021
	%ret =w copy R1
	R1 =w copy %ret
	ret0 0001
}

