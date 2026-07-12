**** Function fneg ****
> After instruction selection:
function $fneg() {
@fneg
	%f =s copy R33
	%b0 =w cast %f
	%isel.1 =w copy 2147483648
	%b1 =w xor %b0, %isel.1
	%rs =s cast %b1
	R33 =s copy %rs
	ret0 0004
}

**** Function ftrunc ****
> After instruction selection:
function $ftrunc() {
@ftrunc
	%f =d copy R33
	%l0 =w dtosi %f
	%rt =d swtof %l0
	R33 =d copy %rt
	ret0 0004
}

**** Function wtos ****
> After instruction selection:
function $wtos() {
@start
	%w =w copy R1
	%rt =s uwtof %w
	R33 =s copy %rt
	ret0 0004
}

**** Function wtod ****
> After instruction selection:
function $wtod() {
@start
	%w =w copy R1
	%rt =d uwtof %w
	R33 =d copy %rt
	ret0 0004
}

**** Function ltos ****
> After instruction selection:
function $ltos() {
@start
	%l =l copy R1
	%rt =s ultof %l
	R33 =s copy %rt
	ret0 0004
}

**** Function ltod ****
> After instruction selection:
function $ltod() {
@start
	%l =l copy R1
	%rt =d ultof %l
	R33 =d copy %rt
	ret0 0004
}

**** Function stow ****
> After instruction selection:
function $stow() {
@start
	%f =s copy R33
	%rt =w stoui %f
	R1 =w copy %rt
	ret0 0001
}

**** Function dtow ****
> After instruction selection:
function $dtow() {
@start
	%f =d copy R33
	%rt =w dtoui %f
	R1 =w copy %rt
	ret0 0001
}

**** Function stol ****
> After instruction selection:
function $stol() {
@start
	%f =s copy R33
	%rt =l stoui %f
	R1 =l copy %rt
	ret0 0001
}

**** Function dtol ****
> After instruction selection:
function $dtol() {
@start
	%f =d copy R33
	%rt =l dtoui %f
	R1 =l copy %rt
	ret0 0001
}

