**** Function main ****
> After instruction selection:
function $main() {
@start
@L0
	%v3.4 =w phi @start 12, @L6 %v24
	%v2.5 =w phi @start 11, @L6 %v2.12
	%v1.6 =w phi @start 5, @L6 %v1.13
	acmpw %v1.6, 201
	jfine @L8, @L1
@L8
	%isel.20 =w copy 2
	%v8 =w rem %v3.4, %isel.20
	acmpw %v8, 0
	jfieq @L9, @L5
@L9
@L5
	%v4.8 =w phi @L8 1, @L9 0
@L2
	%v0.10 =w phi @L5 3, @L4 %v18
	acmpw %v0.10, %v3.4
	jfislt @L10, @L3
@L10
	%v15 =w rem %v3.4, %v0.10
	acmpw %v15, 0
	jfieq @L11, @L4
@L11
	jmp @L3
@L4
	%isel.21 =w copy 2
	%v18 =w add %v0.10, %isel.21
	jmp @L2
@L3
	%v4.11 =w phi @L2 %v4.8, @L11 0
	acmpw %v4.11, 0
	jfine @L12, @L6
@L12
	%isel.22 =w copy 1
	%v22 =w add %v1.6, %isel.22
@L6
	%v2.12 =w phi @L3 %v2.5, @L12 %v3.4
	%v1.13 =w phi @L3 %v1.6, @L12 %v22
	%isel.23 =w copy 1
	%v24 =w add %v3.4, %isel.23
	jmp @L0
@L1
	acmpw %v2.5, 1229
	jfine @L13, @L7
@L13
	%isel.24 =w copy 1
	R1 =w copy %isel.24
	ret0 0001
@L7
	%isel.25 =w copy 0
	R1 =w copy %isel.25
	ret0 0001
}

