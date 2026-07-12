**** Function tests ****
> After instruction selection:
function $tests() {
@start
	%isel.23 =l copy $a
	%isel.22 =w copy 1
	storew %isel.22, %isel.23
	%isel.21 =l copy $a
	%isel.20 =w copy 2
	storew %isel.20, %isel.21
	%isel.19 =l copy $a
	%isel.18 =w copy 3
	storew %isel.18, %isel.19
	%isel.17 =l copy $a
	%isel.16 =w copy 0
	storew %isel.16, %isel.17
	ret0
}

