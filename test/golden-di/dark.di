**** Function test ****
> After instruction selection:
function $test() {
@start
	%av =w loadsw $a
	%a1 =w add %av, 1
	storew %a1, $a
	%r1 =l load $ret
	%r2 =l load [-8 + S-4]
	storel %r2, $ret
	xcmpl %r2, %r1
	jfieq @fin, @cal
@cal
	call $test, 0001
	%i =w copy R1
@fin
	ret0
}

