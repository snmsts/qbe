**** Function test ****
> After slot promotion:
function $test() {
@start
	jmp @foo
@baz
	jnz 1, @end, @foo
@bar
	jmp @end
@foo
	jnz 0, @bar, @baz
@end
	ret0
}

> After load elimination:
function $test() {
@start
	jmp @foo
@baz
	jnz 1, @end, @foo
@bar
	jmp @end
@foo
	jnz 0, @bar, @baz
@end
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $test() {
@start
	jmp @foo
@baz
	jnz 1, @end, @foo
@bar
	jmp @end
@foo
	jnz 0, @bar, @baz
@end
	ret0
}

