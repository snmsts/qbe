**** Function test ****
> After slot promotion:
function $test() {
@start
	%c =w par
	jnz %c, @yes, @no
@yes
	%c0 =w cnew %c, 0
	jnz %c0, @yesyes, @yesno
@yesyes
	%rc =w copy 1
	jmp @end
@yesno
	%rc =w copy 111
	jmp @end
@no
	%c1 =w cnew %c, 0
	jnz %c1, @noyes, @nono
@noyes
	%rc =w copy 222
	jmp @end
@nono
	%rc =w copy 0
@end
	retw %rc
}

> After load elimination:
function $test() {
@start
	%c =w par
	jnz %c, @yes, @no
@yes
	%c0 =w cnew %c, 0
	jnz %c0, @yesyes, @yesno
@yesyes
	%rc.5 =w copy 1
	jmp @end
@yesno
	%rc.4 =w copy 111
	jmp @end
@no
	%c1 =w cnew %c, 0
	jnz %c1, @noyes, @nono
@noyes
	%rc.3 =w copy 222
	jmp @end
@nono
	%rc.2 =w copy 0
@end
	%rc.1 =w phi @nono %rc.2, @noyes %rc.3, @yesno %rc.4, @yesyes %rc.5
	retw %rc.1
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%c =w par
	jnz %c, @yes, @no
@yes
	%c0 =w cnew %c, 0
	jnz %c0, @yesyes, @yesno
@yesyes
	%rc.5 =w copy 1
	jmp @end
@yesno
	%rc.4 =w copy 111
	jmp @end
@no
	%c1 =w cnew %c, 0
	jnz %c1, @noyes, @nono
@noyes
	%rc.3 =w copy 222
	jmp @end
@nono
	%rc.2 =w copy 0
@end
	%rc.1 =w phi @nono %rc.2, @noyes %rc.3, @yesno %rc.4, @yesyes %rc.5
	retw %rc.1
}

