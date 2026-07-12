**** Function blit ****
> After instruction selection:
function $blit() {
@start
	%isel.36 =l addr S0
	%isel.35 =w copy 287454020
	storew %isel.35, %isel.36
	%isel.34 =l copy 4
	%isel.33 =l addr S0
	%l04 =l add %isel.33, %isel.34
	%isel.32 =w copy 1432778632
	storew %isel.32, %l04
	%isel.31 =l copy 8
	%isel.30 =l addr S0
	%l08 =l add %isel.30, %isel.31
	%isel.29 =w copy 2578103244
	storew %isel.29, %l08
	%isel.28 =l copy 1
	%isel.27 =l addr S0
	%l11 =l add %isel.27, %isel.28
	%isel.26 =l copy 10
	%isel.25 =l addr S0
	%blt.11 =l add %isel.25, %isel.26
	%blt.9 =w loadub %blt.11
	%isel.24 =l copy 10
	%blt.10 =l add %l11, %isel.24
	storeb %blt.9, %blt.10
	%isel.23 =l copy 8
	%isel.22 =l addr S0
	%blt.8 =l add %isel.22, %isel.23
	%blt.6 =w loaduh %blt.8
	%isel.21 =l copy 8
	%blt.7 =l add %l11, %isel.21
	storeh %blt.6, %blt.7
	%isel.20 =l copy 0
	%isel.19 =l addr S0
	%blt.5 =l add %isel.19, %isel.20
	%blt.3 =l load %blt.5
	%isel.18 =l copy 0
	%blt.4 =l add %l11, %isel.18
	storel %blt.3, %blt.4
	%isel.17 =l addr S0
	%isel.16 =w copy 221
	storeb %isel.16, %isel.17
	%isel.15 =l copy 8
	%isel.14 =l addr S0
	%abi.2 =l add %isel.14, %isel.15
	R2 =l load %abi.2
	%isel.13 =l copy 0
	%isel.12 =l addr S0
	%abi.1 =l add %isel.12, %isel.13
	R1 =l load %abi.1
	ret0 0002
}

