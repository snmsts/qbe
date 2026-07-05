**** Function main ****
> After slot promotion:
function $main() {
@start
	nop
	nop
	nop
	nop
	nop
	%v1 =w copy 5
	%v2 =w copy 11
	%v3 =w copy 12
@L0
	%v5 =w copy %v1
	%v6 =w cnew %v5, 201
	jnz %v6, @L8, @L1
@L8
	%v4 =w copy 1
	%v7 =w copy %v3
	%v8 =w rem %v7, 2
	%v9 =w ceqw %v8, 0
	jnz %v9, @L9, @L5
@L9
	%v4 =w copy 0
@L5
	%v0 =w copy 3
@L2
	%v10 =w copy %v0
	%v11 =w copy %v3
	%v12 =w csltw %v10, %v11
	jnz %v12, @L10, @L3
@L10
	%v13 =w copy %v3
	%v14 =w copy %v0
	%v15 =w rem %v13, %v14
	%v16 =w ceqw %v15, 0
	jnz %v16, @L11, @L4
@L11
	%v4 =w copy 0
	jmp @L3
@L4
	%v17 =w copy %v0
	%v18 =w add %v17, 2
	%v0 =w copy %v18
	jmp @L2
@L3
	%v19 =w copy %v4
	jnz %v19, @L12, @L6
@L12
	%v20 =w copy %v3
	%v2 =w copy %v20
	%v21 =w copy %v1
	%v22 =w add %v21, 1
	%v1 =w copy %v22
@L6
	%v23 =w copy %v3
	%v24 =w add %v23, 1
	%v3 =w copy %v24
	jmp @L0
@L1
	%v25 =w copy %v2
	%v26 =w cnew %v25, 1229
	jnz %v26, @L13, @L7
@L13
	retw 1
@L7
	retw 0
}

> After load elimination:
function $main() {
@start
	nop
	nop
	nop
	nop
	nop
	%v1.1 =w copy 5
	%v2.2 =w copy 11
	%v3.3 =w copy 12
@L0
	%v3.4 =w phi @start %v3.3, @L6 %v3.14
	%v2.5 =w phi @start %v2.2, @L6 %v2.12
	%v1.6 =w phi @start %v1.1, @L6 %v1.13
	%v5 =w copy %v1.6
	%v6 =w cnew %v5, 201
	jnz %v6, @L8, @L1
@L8
	%v4.7 =w copy 1
	%v7 =w copy %v3.4
	%v8 =w rem %v7, 2
	%v9 =w ceqw %v8, 0
	jnz %v9, @L9, @L5
@L9
	%v4.19 =w copy 0
@L5
	%v4.8 =w phi @L8 %v4.7, @L9 %v4.19
	%v0.9 =w copy 3
@L2
	%v0.10 =w phi @L5 %v0.9, @L4 %v0.17
	%v10 =w copy %v0.10
	%v11 =w copy %v3.4
	%v12 =w csltw %v10, %v11
	jnz %v12, @L10, @L3
@L10
	%v13 =w copy %v3.4
	%v14 =w copy %v0.10
	%v15 =w rem %v13, %v14
	%v16 =w ceqw %v15, 0
	jnz %v16, @L11, @L4
@L11
	%v4.18 =w copy 0
	jmp @L3
@L4
	%v17 =w copy %v0.10
	%v18 =w add %v17, 2
	%v0.17 =w copy %v18
	jmp @L2
@L3
	%v4.11 =w phi @L2 %v4.8, @L11 %v4.18
	%v19 =w copy %v4.11
	jnz %v19, @L12, @L6
@L12
	%v20 =w copy %v3.4
	%v2.15 =w copy %v20
	%v21 =w copy %v1.6
	%v22 =w add %v21, 1
	%v1.16 =w copy %v22
@L6
	%v2.12 =w phi @L3 %v2.5, @L12 %v2.15
	%v1.13 =w phi @L3 %v1.6, @L12 %v1.16
	%v23 =w copy %v3.4
	%v24 =w add %v23, 1
	%v3.14 =w copy %v24
	jmp @L0
@L1
	%v25 =w copy %v2.5
	%v26 =w cnew %v25, 1229
	jnz %v26, @L13, @L7
@L13
	retw 1
@L7
	retw 0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $main() {
@start
	nop
	nop
	nop
	nop
	nop
	%v1.1 =w copy 5
	%v2.2 =w copy 11
	%v3.3 =w copy 12
@L0
	%v3.4 =w phi @start %v3.3, @L6 %v3.14
	%v2.5 =w phi @start %v2.2, @L6 %v2.12
	%v1.6 =w phi @start %v1.1, @L6 %v1.13
	%v5 =w copy %v1.6
	%v6 =w cnew %v5, 201
	jnz %v6, @L8, @L1
@L8
	%v4.7 =w copy 1
	%v7 =w copy %v3.4
	%v8 =w rem %v7, 2
	%v9 =w ceqw %v8, 0
	jnz %v9, @L9, @L5
@L9
	%v4.19 =w copy 0
@L5
	%v4.8 =w phi @L8 %v4.7, @L9 %v4.19
	%v0.9 =w copy 3
@L2
	%v0.10 =w phi @L5 %v0.9, @L4 %v0.17
	%v10 =w copy %v0.10
	%v11 =w copy %v3.4
	%v12 =w csltw %v10, %v11
	jnz %v12, @L10, @L3
@L10
	%v13 =w copy %v3.4
	%v14 =w copy %v0.10
	%v15 =w rem %v13, %v14
	%v16 =w ceqw %v15, 0
	jnz %v16, @L11, @L4
@L11
	%v4.18 =w copy 0
	jmp @L3
@L4
	%v17 =w copy %v0.10
	%v18 =w add %v17, 2
	%v0.17 =w copy %v18
	jmp @L2
@L3
	%v4.11 =w phi @L2 %v4.8, @L11 %v4.18
	%v19 =w copy %v4.11
	jnz %v19, @L12, @L6
@L12
	%v20 =w copy %v3.4
	%v2.15 =w copy %v20
	%v21 =w copy %v1.6
	%v22 =w add %v21, 1
	%v1.16 =w copy %v22
@L6
	%v2.12 =w phi @L3 %v2.5, @L12 %v2.15
	%v1.13 =w phi @L3 %v1.6, @L12 %v1.16
	%v23 =w copy %v3.4
	%v24 =w add %v23, 1
	%v3.14 =w copy %v24
	jmp @L0
@L1
	%v25 =w copy %v2.5
	%v26 =w cnew %v25, 1229
	jnz %v26, @L13, @L7
@L13
	retw 1
@L7
	retw 0
}

