**** Function main ****
> After instruction selection:
function $main() {
@start
@L0
	%v3.4 =w phi @start 12, @L6 %v24
	%v2.5 =w phi @start 11, @L6 %v2.12
	%v1.6 =w phi @start 5, @L6 %v1.13
	xcmpw 201, %v1.6
	jfine @L8, @L1
@L8
	%isel.22 =w copy 2
	R1 =w copy %v3.4
	R3 =w sign R1
	xidivw %isel.22
	copy R1
	%v8 =w copy R3
	xcmpw 0, %v8
	%isel.21 =w copy 1
	%isel.20 =w copy 0
	%v4.8 =w xselieq %isel.20, %isel.21
@L5
@L2
	%v0.10 =w phi @L5 3, @L4 %v18
	xcmpw %v3.4, %v0.10
	jfislt @L10, @L3
@L10
	R1 =w copy %v3.4
	R3 =w sign R1
	xidivw %v0.10
	copy R1
	%v15 =w copy R3
	xcmpw 0, %v15
	jfieq @L11, @L4
@L11
	jmp @L3
@L4
	%v18 =w add %v0.10, 2
	jmp @L2
@L3
	%v4.11 =w phi @L2 %v4.8, @L11 0
	%v22 =w add %v1.6, 1
	xcmpw 0, %v4.11
	%v2.12 =w xseline %v3.4, %v2.5
	%v1.13 =w xseline %v22, %v1.6
@L6
	%v24 =w add %v3.4, 1
	jmp @L0
@L1
	xcmpw 1229, %v2.5
	jfine @L13, @L7
@L13
	R1 =w copy 1
	ret0 0001
@L7
	R1 =w copy 0
	ret0 0001
}

