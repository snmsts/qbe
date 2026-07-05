**** Function test ****
> After slot promotion:
function $test() {
@start
	%x =w copy 1
@loop
	jnz %x, @noz, @isz
@noz
	%x =w copy 0
	jnz %x, @loop, @end
@isz
	%x =w copy 1
	jmp @loop
@end
	%z =w add 10, %x
	ret0
}

> After load elimination:
function $test() {
@start
	%x.1 =w copy 1
@loop
	%x.2 =w phi @start %x.1, @isz %x.3, @noz %x.4
	jnz %x.2, @noz, @isz
@noz
	%x.4 =w copy 0
	jnz %x.4, @loop, @end
@isz
	%x.3 =w copy 1
	jmp @loop
@end
	%z =w add 10, %x.4
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	%x.1 =w copy 1
@loop
	%x.2 =w phi @start %x.1, @isz %x.3, @noz %x.4
	jnz %x.2, @noz, @isz
@noz
	%x.4 =w copy 0
	jnz %x.4, @loop, @end
@isz
	%x.3 =w copy 1
	jmp @loop
@end
	%z =w add 10, %x.4
	ret0
}

