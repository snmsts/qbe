**** Function test ****
> After slot promotion:
function $test() {
@start
	%p =l parc :magic
	%av =w loadsw $a
	%a1 =w add 1, %av
	storew %a1, $a
	%r1 =l load $ret
	%p1 =l add %p, -8
	%r2 =l load %p1
	storel %r2, $ret
	%c =w ceql %r1, %r2
	jnz %c, @fin, @cal
@cal
	%i =w call $test
@fin
	ret0
}

> After load elimination:
function $test() {
@start
	%p =l parc :magic
	%av =w loadsw $a
	%a1 =w add 1, %av
	storew %a1, $a
	%r1 =l load $ret
	%p1 =l add %p, -8
	%r2 =l load %p1
	storel %r2, $ret
	%c =w ceql %r1, %r2
	jnz %c, @fin, @cal
@cal
	%i =w call $test
@fin
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%p =l parc :magic
	%av =w loadsw $a
	%a1 =w add 1, %av
	storew %a1, $a
	%r1 =l load $ret
	%p1 =l add %p, -8
	%r2 =l load %p1
	storel %r2, $ret
	%c =w ceql %r1, %r2
	jnz %c, @fin, @cal
@cal
	%i =w call $test
@fin
	ret0
}

