**** Function ifc1 ****
> After instruction selection:
function $ifc1() {
@start
	%c =w copy R3
	%v1 =l copy R2
	%v0 =l copy R1
	acmpw %c, 0
	jfine @true, @false
@true
	jmp @end
@false
@end
	%v.1 =l phi @false %v0, @true %v1
	R1 =l copy %v.1
	ret0 0001
}

**** Function ifc2 ****
> After instruction selection:
function $ifc2() {
@start
	%p =w copy R3
	%v1 =l copy R2
	%v0 =l copy R1
	acmpw %p, 42
	jfine @true, @false
@true
	jmp @end
@false
@end
	%v.4 =l phi @false %v0, @true %v1
	R1 =l copy %v.4
	ret0 0001
}

**** Function ifc3 ****
> After instruction selection:
function $ifc3() {
@start
	%p =w copy R3
	%v1 =l copy R2
	%v0 =l copy R1
	acmpw %p, 42
	jfiugt @true, @false
@true
	jmp @end
@false
@end
	%v.7 =l phi @false %v0, @true %v1
	R1 =l copy %v.7
	ret0 0001
}

**** Function ifclts ****
> After instruction selection:
function $ifclts() {
@start
	%v1 =l copy R2
	%v0 =l copy R1
	%s1 =s copy R34
	%s0 =s copy R33
	afcmps %s0, %s1
	jfflt @true, @false
@true
	jmp @end
@false
@end
	%v.10 =l phi @false %v0, @true %v1
	R1 =l copy %v.10
	ret0 0001
}

**** Function ifcles ****
> After instruction selection:
function $ifcles() {
@start
	%v1 =l copy R2
	%v0 =l copy R1
	%s1 =s copy R34
	%s0 =s copy R33
	afcmps %s0, %s1
	jffle @true, @false
@true
	jmp @end
@false
@end
	%v.13 =l phi @false %v0, @true %v1
	R1 =l copy %v.13
	ret0 0001
}

**** Function ifcgts ****
> After instruction selection:
function $ifcgts() {
@start
	%v1 =l copy R2
	%v0 =l copy R1
	%s1 =s copy R34
	%s0 =s copy R33
	afcmps %s0, %s1
	jffgt @true, @false
@true
	jmp @end
@false
@end
	%v.16 =l phi @false %v0, @true %v1
	R1 =l copy %v.16
	ret0 0001
}

**** Function ifcges ****
> After instruction selection:
function $ifcges() {
@start
	%v1 =l copy R2
	%v0 =l copy R1
	%s1 =s copy R34
	%s0 =s copy R33
	afcmps %s0, %s1
	jffge @true, @false
@true
	jmp @end
@false
@end
	%v.19 =l phi @false %v0, @true %v1
	R1 =l copy %v.19
	ret0 0001
}

**** Function ifceqs ****
> After instruction selection:
function $ifceqs() {
@start
	%v1 =l copy R2
	%v0 =l copy R1
	%s1 =s copy R34
	%s0 =s copy R33
	afcmps %s0, %s1
	jffeq @true, @false
@true
	jmp @end
@false
@end
	%v.22 =l phi @false %v0, @true %v1
	R1 =l copy %v.22
	ret0 0001
}

**** Function ifcnes ****
> After instruction selection:
function $ifcnes() {
@start
	%v1 =l copy R2
	%v0 =l copy R1
	%s1 =s copy R34
	%s0 =s copy R33
	afcmps %s0, %s1
	jffne @true, @false
@true
	jmp @end
@false
@end
	%v.25 =l phi @false %v0, @true %v1
	R1 =l copy %v.25
	ret0 0001
}

**** Function ifcos ****
> After instruction selection:
function $ifcos() {
@start
	%v1 =l copy R2
	%v0 =l copy R1
	%s1 =s copy R34
	%s0 =s copy R33
	afcmps %s0, %s1
	jffo @true, @false
@true
	jmp @end
@false
@end
	%v.28 =l phi @false %v0, @true %v1
	R1 =l copy %v.28
	ret0 0001
}

**** Function ifcuos ****
> After instruction selection:
function $ifcuos() {
@start
	%v1 =l copy R2
	%v0 =l copy R1
	%s1 =s copy R34
	%s0 =s copy R33
	afcmps %s0, %s1
	jffuo @true, @false
@true
	jmp @end
@false
@end
	%v.31 =l phi @false %v0, @true %v1
	R1 =l copy %v.31
	ret0 0001
}

