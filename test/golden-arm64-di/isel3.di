**** Function slt ****
> After instruction selection:
function $slt() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagislt
	R1 =w copy %r
	ret0 0001
}

**** Function sle ****
> After instruction selection:
function $sle() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagisle
	R1 =w copy %r
	ret0 0001
}

**** Function sgt ****
> After instruction selection:
function $sgt() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagisgt
	R1 =w copy %r
	ret0 0001
}

**** Function sge ****
> After instruction selection:
function $sge() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagisge
	R1 =w copy %r
	ret0 0001
}

**** Function ult ****
> After instruction selection:
function $ult() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagiult
	R1 =w copy %r
	ret0 0001
}

**** Function ule ****
> After instruction selection:
function $ule() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagiule
	R1 =w copy %r
	ret0 0001
}

**** Function ugt ****
> After instruction selection:
function $ugt() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagiugt
	R1 =w copy %r
	ret0 0001
}

**** Function uge ****
> After instruction selection:
function $uge() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagiuge
	R1 =w copy %r
	ret0 0001
}

**** Function eq ****
> After instruction selection:
function $eq() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagieq
	R1 =w copy %r
	ret0 0001
}

**** Function ne ****
> After instruction selection:
function $ne() {
@start
	%y =w copy R2
	%x =w copy R1
	acmpw %x, %y
	%r =w flagine
	R1 =w copy %r
	ret0 0001
}

