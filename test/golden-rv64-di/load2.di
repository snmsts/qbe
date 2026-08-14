**** Function f ****
> After instruction selection:
function $f() {
@start
	%isel.35 =l addr S0
	%y4 =l add %isel.35, 4
	%isel.34 =w copy 1432778632
	storew %isel.34, S0
	%isel.33 =w copy 287475780
	R7 =w copy %isel.33
	call $px, 0011
	copy R7
	%isel.32 =w copy 1432778632
	storew %isel.32, S0
	%isel.31 =w copy 293046340
	R7 =w copy %isel.31
	call $px, 0011
	copy R7
	%isel.30 =w copy 1432778632
	storew %isel.30, S0
	%isel.29 =w copy 1719109700
	R7 =w copy %isel.29
	call $px, 0011
	copy R7
	%isel.28 =w copy 1432778632
	storew %isel.28, S0
	%isel.27 =w copy 287462758
	R7 =w copy %isel.27
	call $px, 0011
	copy R7
	%isel.26 =w copy 0
	storew %isel.26, S0
	%isel.25 =w copy 1432778632
	storew %isel.25, %y4
	%isel.24 =w copy 1719109632
	R7 =w copy %isel.24
	call $px, 0011
	copy R7
	ret0
}

