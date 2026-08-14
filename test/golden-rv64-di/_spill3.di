**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.3 =w copy 0
	%isel.2 =w copy 0
	%isel.1 =w copy 0
@loop
	%c =w phi @start %isel.1, @loop %f
	%d =w phi @start %isel.2, @loop %g
	%e =w phi @start %isel.3, @loop %h
	%f =w add %c, %d
	%g =w add %c, %e
	%h =w add %d, %e
	jmp @loop
}

