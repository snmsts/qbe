**** Function test ****
> After instruction selection:
function $test() {
@start
	%p =l copy R7
	%av =w loadsw $a
	%a1 =w add %av, 1
	storew %a1, $a
	%r1 =l load $ret
	%p1 =l add %p, -8
	%r2 =l load %p1
	storel %r2, $ret
	%isel.1 =l xor %r1, %r2
	%c =w reqz %isel.1
	jnz %c, @fin, @cal
@cal
	call $test, 0001
	%i =w copy R7
@fin
	ret0
}

