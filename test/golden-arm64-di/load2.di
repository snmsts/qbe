**** Function f ****
> After instruction selection:
function $f() {
@start
	%isel.41 =l copy 4
	%isel.40 =l addr S0
	%y4 =l add %isel.40, %isel.41
	%isel.39 =l addr S0
	%isel.38 =w copy 1432778632
	storew %isel.38, %isel.39
	%isel.37 =w copy 287475780
	R1 =w copy %isel.37
	call $px, 0021
	copy R1
	%isel.36 =l addr S0
	%isel.35 =w copy 1432778632
	storew %isel.35, %isel.36
	%isel.34 =w copy 293046340
	R1 =w copy %isel.34
	call $px, 0021
	copy R1
	%isel.33 =l addr S0
	%isel.32 =w copy 1432778632
	storew %isel.32, %isel.33
	%isel.31 =w copy 1719109700
	R1 =w copy %isel.31
	call $px, 0021
	copy R1
	%isel.30 =l addr S0
	%isel.29 =w copy 1432778632
	storew %isel.29, %isel.30
	%isel.28 =w copy 287462758
	R1 =w copy %isel.28
	call $px, 0021
	copy R1
	%isel.27 =l addr S0
	%isel.26 =w copy 0
	storew %isel.26, %isel.27
	%isel.25 =w copy 1432778632
	storew %isel.25, %y4
	%isel.24 =w copy 1719109632
	R1 =w copy %isel.24
	call $px, 0021
	copy R1
	ret0
}

