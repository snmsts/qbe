**** Function ifc1 ****
> After instruction selection:
function $ifc1() {
@start
	%c =w copy R3
	%v1 =l copy R4
	%v0 =l copy R5
	xcmpw 0, %c
	%v.1 =l xseline %v1, %v0
@end
	R1 =l copy %v.1
	ret0 0001
}

**** Function ifc2 ****
> After instruction selection:
function $ifc2() {
@start
	%p =w copy R3
	%v1 =l copy R4
	%v0 =l copy R5
	xcmpw 42, %p
	%v.4 =l xseline %v1, %v0
@end
	R1 =l copy %v.4
	ret0 0001
}

**** Function ifc3 ****
> After instruction selection:
function $ifc3() {
@start
	%p =w copy R3
	%v1 =l copy R4
	%v0 =l copy R5
	xcmpw 42, %p
	%v.7 =l xseliugt %v1, %v0
@end
	R1 =l copy %v.7
	ret0 0001
}

**** Function ifclts ****
> After instruction selection:
function $ifclts() {
@start
	%v1 =l copy R4
	%v0 =l copy R5
	%s1 =s copy R18
	%s0 =s copy R17
	xcmps %s0, %s1
	%v.10 =l xselfgt %v1, %v0
@end
	R1 =l copy %v.10
	ret0 0001
}

**** Function ifcles ****
> After instruction selection:
function $ifcles() {
@start
	%v1 =l copy R4
	%v0 =l copy R5
	%s1 =s copy R18
	%s0 =s copy R17
	xcmps %s0, %s1
	%v.13 =l xselfge %v1, %v0
@end
	R1 =l copy %v.13
	ret0 0001
}

**** Function ifcgts ****
> After instruction selection:
function $ifcgts() {
@start
	%v1 =l copy R4
	%v0 =l copy R5
	%s1 =s copy R18
	%s0 =s copy R17
	xcmps %s1, %s0
	%v.16 =l xselfgt %v1, %v0
@end
	R1 =l copy %v.16
	ret0 0001
}

**** Function ifcges ****
> After instruction selection:
function $ifcges() {
@start
	%v1 =l copy R4
	%v0 =l copy R5
	%s1 =s copy R18
	%s0 =s copy R17
	xcmps %s1, %s0
	%v.19 =l xselfge %v1, %v0
@end
	R1 =l copy %v.19
	ret0 0001
}

**** Function ifceqs ****
> After instruction selection:
function $ifceqs() {
@start
	%v1 =l copy R4
	%v0 =l copy R5
	%s1 =s copy R18
	%s0 =s copy R17
	xcmps %s1, %s0
	%isel.25 =w flagfeq
	%isel.26 =w flagfo
	%c =w and %isel.25, %isel.26
	copy %c
	%v.22 =l xseline %v1, %v0
@end
	R1 =l copy %v.22
	ret0 0001
}

**** Function ifcnes ****
> After instruction selection:
function $ifcnes() {
@start
	%v1 =l copy R4
	%v0 =l copy R5
	%s1 =s copy R18
	%s0 =s copy R17
	xcmps %s1, %s0
	%isel.30 =w flagfne
	%isel.31 =w flagfuo
	%c =w or %isel.30, %isel.31
	copy %c
	%v.27 =l xseline %v1, %v0
@end
	R1 =l copy %v.27
	ret0 0001
}

**** Function ifcos ****
> After instruction selection:
function $ifcos() {
@start
	%v1 =l copy R4
	%v0 =l copy R5
	%s1 =s copy R18
	%s0 =s copy R17
	xcmps %s1, %s0
	%v.32 =l xselfo %v1, %v0
@end
	R1 =l copy %v.32
	ret0 0001
}

**** Function ifcuos ****
> After instruction selection:
function $ifcuos() {
@start
	%v1 =l copy R4
	%v0 =l copy R5
	%s1 =s copy R18
	%s0 =s copy R17
	xcmps %s1, %s0
	%v.35 =l xselfuo %v1, %v0
@end
	R1 =l copy %v.35
	ret0 0001
}

