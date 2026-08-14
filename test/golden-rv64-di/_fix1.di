**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.5 =w copy 1
@loop
	%x.2 =w phi @start %isel.5, @isz %isel.6
	jnz %x.2, @noz, @isz
@noz
	ret0
@isz
	%isel.6 =w copy 1
	jmp @loop
}

