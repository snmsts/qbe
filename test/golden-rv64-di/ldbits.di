**** Function tests ****
> After instruction selection:
function $tests() {
@start
	%isel.19 =w copy 1
	storew %isel.19, $a
	%isel.18 =w copy 2
	storew %isel.18, $a
	%isel.17 =w copy 3
	storew %isel.17, $a
	%isel.16 =w copy 0
	storew %isel.16, $a
	ret0
}

