**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%c =w phi @start 0, @loop %f
	%d =w phi @start 0, @loop %g
	%e =w phi @start 0, @loop %h
	%f =w add %c, %d
	%g =w add %c, %e
	%h =w add %d, %e
	jmp @loop
}

