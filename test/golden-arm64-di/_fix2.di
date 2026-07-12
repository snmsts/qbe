**** Function test ****
> After instruction selection:
function $test() {
@start
@loop
	%x.2 =w phi @start 1, @isz 1
	acmpw %x.2, 0
	jfine @noz, @isz
@noz
	ret0
@isz
	jmp @loop
}

