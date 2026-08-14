**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.22 =w copy 5
	%isel.21 =w copy 11
	%isel.20 =w copy 12
@L0
	%v3.4 =w phi @start %isel.20, @L6 %v24
	%v2.5 =w phi @start %isel.21, @L6 %v2.12
	%v1.6 =w phi @start %isel.22, @L6 %v1.13
	%isel.23 =w xor %v1.6, 201
	%v6 =w rnez %isel.23
	jnz %v6, @L8, @L1
@L8
	%isel.26 =w copy 2
	%v8 =w rem %v3.4, %isel.26
	%isel.25 =w xor %v8, 0
	%v9 =w reqz %isel.25
	%isel.24 =w copy 1
	jnz %v9, @L9, @L5
@L9
	%isel.27 =w copy 0
@L5
	%v4.8 =w phi @L8 %isel.24, @L9 %isel.27
	%isel.28 =w copy 3
@L2
	%v0.10 =w phi @L5 %isel.28, @L4 %v18
	%v12 =w csltl %v0.10, %v3.4
	jnz %v12, @L10, @L3
@L10
	%v15 =w rem %v3.4, %v0.10
	%isel.29 =w xor %v15, 0
	%v16 =w reqz %isel.29
	jnz %v16, @L11, @L4
@L11
	%isel.30 =w copy 0
	jmp @L3
@L4
	%v18 =w add %v0.10, 2
	jmp @L2
@L3
	%v4.11 =w phi @L2 %v4.8, @L11 %isel.30
	jnz %v4.11, @L12, @L6
@L12
	%v22 =w add %v1.6, 1
@L6
	%v2.12 =w phi @L3 %v2.5, @L12 %v3.4
	%v1.13 =w phi @L3 %v1.6, @L12 %v22
	%v24 =w add %v3.4, 1
	jmp @L0
@L1
	%isel.31 =w xor %v2.5, 1229
	%v26 =w rnez %isel.31
	jnz %v26, @L13, @L7
@L13
	%isel.32 =w copy 1
	R7 =w copy %isel.32
	ret0 0001
@L7
	%isel.33 =w copy 0
	R7 =w copy %isel.33
	ret0 0001
}

