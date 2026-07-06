**** Function fneg ****
> After instruction selection:
function $fneg() {
@fneg
	%f =s copy R17
	%b0 =w cast %f
	%b1 =w xor %b0, 2147483648
	%rs =s cast %b1
	R17 =s copy %rs
	ret0 0004
}

**** Function ftrunc ****
> After instruction selection:
function $ftrunc() {
@ftrunc
	%f =d copy R17
	%l0 =w dtosi %f
	%rt =d swtof %l0
	R17 =d copy %rt
	ret0 0004
}

**** Function wtos ****
> After instruction selection:
function $wtos() {
@start
	%w =w copy R5
	%utof.1 =l extuw %w
	%rt =s sltof %utof.1
	R17 =s copy %rt
	ret0 0004
}

**** Function wtod ****
> After instruction selection:
function $wtod() {
@start
	%w =w copy R5
	%utof.2 =l extuw %w
	%rt =d sltof %utof.2
	R17 =d copy %rt
	ret0 0004
}

**** Function ltos ****
> After instruction selection:
function $ltos() {
@start
	%l =l copy R5
	%utof.4 =l and %l, 1
	%utof.5 =l shr %l, 63
	R2 =w copy %utof.5
	%utof.6 =l shr %l, R2
	copy R2
	%utof.7 =l or %utof.4, %utof.6
	%utof.3 =s sltof %utof.7
	%utof.8 =w cast %utof.3
	%utof.9 =w shl %utof.5, 23
	%utof.10 =w add %utof.8, %utof.9
	%rt =s cast %utof.10
	R17 =s copy %rt
	ret0 0004
}

**** Function ltod ****
> After instruction selection:
function $ltod() {
@start
	%l =l copy R5
	%utof.12 =l and %l, 1
	%utof.13 =l shr %l, 63
	R2 =w copy %utof.13
	%utof.14 =l shr %l, R2
	copy R2
	%utof.15 =l or %utof.12, %utof.14
	%utof.11 =d sltof %utof.15
	%utof.16 =l cast %utof.11
	%utof.17 =l shl %utof.13, 52
	%utof.18 =l add %utof.16, %utof.17
	%rt =d cast %utof.18
	R17 =d copy %rt
	ret0 0004
}

**** Function stow ****
> After instruction selection:
function $stow() {
@start
	%f =s copy R17
	%ftou.19 =l stosi %f
	%rt =w copy %ftou.19
	R1 =w copy %rt
	ret0 0001
}

**** Function dtow ****
> After instruction selection:
function $dtow() {
@start
	%f =d copy R17
	%ftou.20 =l dtosi %f
	%rt =w copy %ftou.20
	R1 =w copy %rt
	ret0 0001
}

**** Function stol ****
> After instruction selection:
function $stol() {
@start
	%f =s copy R17
	%ftou.22 =l stosi %f
	%ftou.23 =l sar %ftou.22, 63
	%ftou.21 =s add [$".Lfp0"], %f
	%ftou.24 =l stosi %ftou.21
	%ftou.25 =l and %ftou.24, %ftou.23
	%rt =l or %ftou.22, %ftou.25
	R1 =l copy %rt
	ret0 0001
}

**** Function dtol ****
> After instruction selection:
function $dtol() {
@start
	%f =d copy R17
	%ftou.27 =l dtosi %f
	%ftou.28 =l sar %ftou.27, 63
	%ftou.26 =d add [$".Lfp1"], %f
	%ftou.29 =l dtosi %ftou.26
	%ftou.30 =l and %ftou.29, %ftou.28
	%rt =l or %ftou.27, %ftou.30
	R1 =l copy %rt
	ret0 0001
}

