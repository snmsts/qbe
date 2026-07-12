**** Function test ****
> After instruction selection:
function $test() {
@start
	%p =l copy R1
	%isel.6 =l copy $a
	%av =w loadsw %isel.6
	%isel.5 =w copy 1
	%a1 =w add %av, %isel.5
	%isel.4 =l copy $a
	storew %a1, %isel.4
	%isel.3 =l copy $ret
	%r1 =l load %isel.3
	%isel.2 =l copy -8
	%p1 =l add %p, %isel.2
	%r2 =l load %p1
	%isel.1 =l copy $ret
	storel %r2, %isel.1
	acmpl %r1, %r2
	jfieq @fin, @cal
@cal
	call $test, 0001
	%i =w copy R1
@fin
	ret0
}

