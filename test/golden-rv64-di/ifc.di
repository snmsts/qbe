**** Function ifc1 ****
> After instruction selection:
function $ifc1() {
@start
	%c =w copy R9
	%v1 =l copy R8
	%v0 =l copy R7
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.1 =l phi @false %v0, @true %v1
	R7 =l copy %v.1
	ret0 0001
}

**** Function ifc2 ****
> After instruction selection:
function $ifc2() {
@start
	%p =w copy R9
	%v1 =l copy R8
	%v0 =l copy R7
	%isel.7 =w xor %p, 42
	%c =w rnez %isel.7
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.4 =l phi @false %v0, @true %v1
	R7 =l copy %v.4
	ret0 0001
}

**** Function ifc3 ****
> After instruction selection:
function $ifc3() {
@start
	%p =w copy R9
	%v1 =l copy R8
	%v0 =l copy R7
	%isel.11 =w copy 42
	%c =w cultl %isel.11, %p
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.8 =l phi @false %v0, @true %v1
	R7 =l copy %v.8
	ret0 0001
}

**** Function ifclts ****
> After instruction selection:
function $ifclts() {
@start
	%v1 =l copy R8
	%v0 =l copy R7
	%s1 =s copy R43
	%s0 =s copy R42
	%c =w clts %s0, %s1
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.12 =l phi @false %v0, @true %v1
	R7 =l copy %v.12
	ret0 0001
}

**** Function ifcles ****
> After instruction selection:
function $ifcles() {
@start
	%v1 =l copy R8
	%v0 =l copy R7
	%s1 =s copy R43
	%s0 =s copy R42
	%c =w cles %s0, %s1
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.15 =l phi @false %v0, @true %v1
	R7 =l copy %v.15
	ret0 0001
}

**** Function ifcgts ****
> After instruction selection:
function $ifcgts() {
@start
	%v1 =l copy R8
	%v0 =l copy R7
	%s1 =s copy R43
	%s0 =s copy R42
	%c =w cgts %s0, %s1
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.18 =l phi @false %v0, @true %v1
	R7 =l copy %v.18
	ret0 0001
}

**** Function ifcges ****
> After instruction selection:
function $ifcges() {
@start
	%v1 =l copy R8
	%v0 =l copy R7
	%s1 =s copy R43
	%s0 =s copy R42
	%c =w cges %s0, %s1
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.21 =l phi @false %v0, @true %v1
	R7 =l copy %v.21
	ret0 0001
}

**** Function ifceqs ****
> After instruction selection:
function $ifceqs() {
@start
	%v1 =l copy R8
	%v0 =l copy R7
	%s1 =s copy R43
	%s0 =s copy R42
	%c =w ceqs %s0, %s1
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.24 =l phi @false %v0, @true %v1
	R7 =l copy %v.24
	ret0 0001
}

**** Function ifcnes ****
> After instruction selection:
function $ifcnes() {
@start
	%v1 =l copy R8
	%v0 =l copy R7
	%s1 =s copy R43
	%s0 =s copy R42
	%isel.30 =w ceqs %s0, %s1
	%c =w xor %isel.30, 1
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.27 =l phi @false %v0, @true %v1
	R7 =l copy %v.27
	ret0 0001
}

**** Function ifcos ****
> After instruction selection:
function $ifcos() {
@start
	%v1 =l copy R8
	%v0 =l copy R7
	%s1 =s copy R43
	%s0 =s copy R42
	%isel.35 =w ceqs %s1, %s1
	%isel.34 =w ceqs %s0, %s0
	%c =w and %isel.34, %isel.35
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.31 =l phi @false %v0, @true %v1
	R7 =l copy %v.31
	ret0 0001
}

**** Function ifcuos ****
> After instruction selection:
function $ifcuos() {
@start
	%v1 =l copy R8
	%v0 =l copy R7
	%s1 =s copy R43
	%s0 =s copy R42
	%isel.41 =w ceqs %s1, %s1
	%isel.40 =w ceqs %s0, %s0
	%isel.39 =w and %isel.40, %isel.41
	%c =w xor %isel.39, 1
	jnz %c, @true, @false
@true
	jmp @end
@false
@end
	%v.36 =l phi @false %v0, @true %v1
	R7 =l copy %v.36
	ret0 0001
}

