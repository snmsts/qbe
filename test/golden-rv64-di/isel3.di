**** Function slt ****
> After instruction selection:
function $slt() {
@start
	%y =w copy R8
	%x =w copy R7
	%r =w csltl %x, %y
	R7 =w copy %r
	ret0 0001
}

**** Function sle ****
> After instruction selection:
function $sle() {
@start
	%y =w copy R8
	%x =w copy R7
	%isel.1 =w csltl %y, %x
	%r =w xor %isel.1, 1
	R7 =w copy %r
	ret0 0001
}

**** Function sgt ****
> After instruction selection:
function $sgt() {
@start
	%y =w copy R8
	%x =w copy R7
	%r =w csltl %y, %x
	R7 =w copy %r
	ret0 0001
}

**** Function sge ****
> After instruction selection:
function $sge() {
@start
	%y =w copy R8
	%x =w copy R7
	%isel.2 =w csltl %x, %y
	%r =w xor %isel.2, 1
	R7 =w copy %r
	ret0 0001
}

**** Function ult ****
> After instruction selection:
function $ult() {
@start
	%y =w copy R8
	%x =w copy R7
	%r =w cultl %x, %y
	R7 =w copy %r
	ret0 0001
}

**** Function ule ****
> After instruction selection:
function $ule() {
@start
	%y =w copy R8
	%x =w copy R7
	%isel.3 =w cultl %y, %x
	%r =w xor %isel.3, 1
	R7 =w copy %r
	ret0 0001
}

**** Function ugt ****
> After instruction selection:
function $ugt() {
@start
	%y =w copy R8
	%x =w copy R7
	%r =w cultl %y, %x
	R7 =w copy %r
	ret0 0001
}

**** Function uge ****
> After instruction selection:
function $uge() {
@start
	%y =w copy R8
	%x =w copy R7
	%isel.4 =w cultl %x, %y
	%r =w xor %isel.4, 1
	R7 =w copy %r
	ret0 0001
}

**** Function eq ****
> After instruction selection:
function $eq() {
@start
	%y =w copy R8
	%x =w copy R7
	%isel.5 =w xor %x, %y
	%r =w reqz %isel.5
	R7 =w copy %r
	ret0 0001
}

**** Function ne ****
> After instruction selection:
function $ne() {
@start
	%y =w copy R8
	%x =w copy R7
	%isel.6 =w xor %x, %y
	%r =w rnez %isel.6
	R7 =w copy %r
	ret0 0001
}

