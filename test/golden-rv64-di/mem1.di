**** Function blit ****
> After instruction selection:
function $blit() {
@start
	%isel.23 =w copy 287454020
	storew %isel.23, S0
	%isel.22 =l addr S0
	%l04 =l add %isel.22, 4
	%isel.21 =w copy 1432778632
	storew %isel.21, %l04
	%isel.20 =l addr S0
	%l08 =l add %isel.20, 8
	%isel.19 =w copy 2578103244
	storew %isel.19, %l08
	%isel.18 =l addr S0
	%l11 =l add %isel.18, 1
	%isel.17 =l addr S0
	%blt.11 =l add %isel.17, 10
	%blt.9 =w loadub %blt.11
	%blt.10 =l add %l11, 10
	storeb %blt.9, %blt.10
	%isel.16 =l addr S0
	%blt.8 =l add %isel.16, 8
	%blt.6 =w loaduh %blt.8
	%blt.7 =l add %l11, 8
	storeh %blt.6, %blt.7
	%isel.15 =l addr S0
	%blt.5 =l add %isel.15, 0
	%blt.3 =l load %blt.5
	%blt.4 =l add %l11, 0
	storel %blt.3, %blt.4
	%isel.14 =w copy 221
	storeb %isel.14, S0
	%isel.13 =l addr S0
	%abi.2 =l add %isel.13, 8
	R8 =l load %abi.2
	%isel.12 =l addr S0
	%abi.1 =l add %isel.12, 0
	R7 =l load %abi.1
	ret0 0002
}

