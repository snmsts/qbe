**** Function fneg ****
> After instruction selection:
function $fneg() {
@fneg
	%f =s copy R42
	%b0 =w cast %f
	%isel.1 =w copy 2147483648
	%b1 =w xor %b0, %isel.1
	%rs =s cast %b1
	R42 =s copy %rs
	ret0 0004
}

**** Function ftrunc ****
> After instruction selection:
function $ftrunc() {
@ftrunc
	%f =d copy R42
	%l0 =w dtosi %f
	%rt =d swtof %l0
	R42 =d copy %rt
	ret0 0004
}

**** Function wtos ****
> After instruction selection:
function $wtos() {
@start
	%w =w copy R7
	%rt =s uwtof %w
	R42 =s copy %rt
	ret0 0004
}

**** Function wtod ****
> After instruction selection:
function $wtod() {
@start
	%w =w copy R7
	%rt =d uwtof %w
	R42 =d copy %rt
	ret0 0004
}

**** Function ltos ****
> After instruction selection:
function $ltos() {
@start
	%l =l copy R7
	%rt =s ultof %l
	R42 =s copy %rt
	ret0 0004
}

**** Function ltod ****
> After instruction selection:
function $ltod() {
@start
	%l =l copy R7
	%rt =d ultof %l
	R42 =d copy %rt
	ret0 0004
}

**** Function stow ****
> After instruction selection:
function $stow() {
@start
	%f =s copy R42
	%rt =w stoui %f
	R7 =w copy %rt
	ret0 0001
}

**** Function dtow ****
> After instruction selection:
function $dtow() {
@start
	%f =d copy R42
	%rt =w dtoui %f
	R7 =w copy %rt
	ret0 0001
}

**** Function stol ****
> After instruction selection:
function $stol() {
@start
	%f =s copy R42
	%rt =l stoui %f
	R7 =l copy %rt
	ret0 0001
}

**** Function dtol ****
> After instruction selection:
function $dtol() {
@start
	%f =d copy R42
	%rt =l dtoui %f
	R7 =l copy %rt
	ret0 0001
}

