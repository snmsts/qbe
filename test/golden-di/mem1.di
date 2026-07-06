**** Function blit ****
> After instruction selection:
function $blit() {
@start
	storew 287454020, [S0]
	storew 1432778632, [4 + S0]
	storew 2578103244, [8 + S0]
	%blt.8 =w loadub [10 + S0]
	storeb %blt.8, [11 + S0]
	%blt.5 =w loaduh [8 + S0]
	storeh %blt.5, [9 + S0]
	%blt.2 =l load [0 + S0]
	storel %blt.2, [1 + S0]
	storeb 221, [S0]
	R1 =l load [S0]
	R3 =l load [8 + S0]
	ret0 0002
}

