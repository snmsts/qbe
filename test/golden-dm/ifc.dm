**** Function ifc1 ****
> After slot promotion:
function $ifc1() {
@start
	%v0 =l par
	%v1 =l par
	%c =w par
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifc1() {
@start
	%v0 =l par
	%v1 =l par
	%c =w par
	jnz %c, @true, @false
@true
	%v.3 =l copy %v1
	jmp @end
@false
	%v.2 =l copy %v0
@end
	%v.1 =l phi @false %v.2, @true %v.3
	retl %v.1
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifc1() {
@start
	%v0 =l par
	%v1 =l par
	%c =w par
	jnz %c, @true, @false
@true
	%v.3 =l copy %v1
	jmp @end
@false
	%v.2 =l copy %v0
@end
	%v.1 =l phi @false %v.2, @true %v.3
	retl %v.1
}

**** Function ifc2 ****
> After slot promotion:
function $ifc2() {
@start
	%v0 =l par
	%v1 =l par
	%p =w par
	%c =w cnew %p, 42
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifc2() {
@start
	%v0 =l par
	%v1 =l par
	%p =w par
	%c =w cnew %p, 42
	jnz %c, @true, @false
@true
	%v.6 =l copy %v1
	jmp @end
@false
	%v.5 =l copy %v0
@end
	%v.4 =l phi @false %v.5, @true %v.6
	retl %v.4
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifc2() {
@start
	%v0 =l par
	%v1 =l par
	%p =w par
	%c =w cnew %p, 42
	jnz %c, @true, @false
@true
	%v.6 =l copy %v1
	jmp @end
@false
	%v.5 =l copy %v0
@end
	%v.4 =l phi @false %v.5, @true %v.6
	retl %v.4
}

**** Function ifc3 ****
> After slot promotion:
function $ifc3() {
@start
	%v0 =l par
	%v1 =l par
	%p =w par
	%c =w cugtw %p, 42
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifc3() {
@start
	%v0 =l par
	%v1 =l par
	%p =w par
	%c =w cugtw %p, 42
	jnz %c, @true, @false
@true
	%v.9 =l copy %v1
	jmp @end
@false
	%v.8 =l copy %v0
@end
	%v.7 =l phi @false %v.8, @true %v.9
	retl %v.7
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifc3() {
@start
	%v0 =l par
	%v1 =l par
	%p =w par
	%c =w cugtw %p, 42
	jnz %c, @true, @false
@true
	%v.9 =l copy %v1
	jmp @end
@false
	%v.8 =l copy %v0
@end
	%v.7 =l phi @false %v.8, @true %v.9
	retl %v.7
}

**** Function ifclts ****
> After slot promotion:
function $ifclts() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w clts %s0, %s1
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifclts() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w clts %s0, %s1
	jnz %c, @true, @false
@true
	%v.12 =l copy %v1
	jmp @end
@false
	%v.11 =l copy %v0
@end
	%v.10 =l phi @false %v.11, @true %v.12
	retl %v.10
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifclts() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w clts %s0, %s1
	jnz %c, @true, @false
@true
	%v.12 =l copy %v1
	jmp @end
@false
	%v.11 =l copy %v0
@end
	%v.10 =l phi @false %v.11, @true %v.12
	retl %v.10
}

**** Function ifcles ****
> After slot promotion:
function $ifcles() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cles %s0, %s1
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifcles() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cles %s0, %s1
	jnz %c, @true, @false
@true
	%v.15 =l copy %v1
	jmp @end
@false
	%v.14 =l copy %v0
@end
	%v.13 =l phi @false %v.14, @true %v.15
	retl %v.13
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifcles() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cles %s0, %s1
	jnz %c, @true, @false
@true
	%v.15 =l copy %v1
	jmp @end
@false
	%v.14 =l copy %v0
@end
	%v.13 =l phi @false %v.14, @true %v.15
	retl %v.13
}

**** Function ifcgts ****
> After slot promotion:
function $ifcgts() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cgts %s0, %s1
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifcgts() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cgts %s0, %s1
	jnz %c, @true, @false
@true
	%v.18 =l copy %v1
	jmp @end
@false
	%v.17 =l copy %v0
@end
	%v.16 =l phi @false %v.17, @true %v.18
	retl %v.16
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifcgts() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cgts %s0, %s1
	jnz %c, @true, @false
@true
	%v.18 =l copy %v1
	jmp @end
@false
	%v.17 =l copy %v0
@end
	%v.16 =l phi @false %v.17, @true %v.18
	retl %v.16
}

**** Function ifcges ****
> After slot promotion:
function $ifcges() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cges %s0, %s1
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifcges() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cges %s0, %s1
	jnz %c, @true, @false
@true
	%v.21 =l copy %v1
	jmp @end
@false
	%v.20 =l copy %v0
@end
	%v.19 =l phi @false %v.20, @true %v.21
	retl %v.19
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifcges() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cges %s0, %s1
	jnz %c, @true, @false
@true
	%v.21 =l copy %v1
	jmp @end
@false
	%v.20 =l copy %v0
@end
	%v.19 =l phi @false %v.20, @true %v.21
	retl %v.19
}

**** Function ifceqs ****
> After slot promotion:
function $ifceqs() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w ceqs %s0, %s1
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifceqs() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w ceqs %s0, %s1
	jnz %c, @true, @false
@true
	%v.24 =l copy %v1
	jmp @end
@false
	%v.23 =l copy %v0
@end
	%v.22 =l phi @false %v.23, @true %v.24
	retl %v.22
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifceqs() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w ceqs %s0, %s1
	jnz %c, @true, @false
@true
	%v.24 =l copy %v1
	jmp @end
@false
	%v.23 =l copy %v0
@end
	%v.22 =l phi @false %v.23, @true %v.24
	retl %v.22
}

**** Function ifcnes ****
> After slot promotion:
function $ifcnes() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cnes %s0, %s1
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifcnes() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cnes %s0, %s1
	jnz %c, @true, @false
@true
	%v.29 =l copy %v1
	jmp @end
@false
	%v.28 =l copy %v0
@end
	%v.27 =l phi @false %v.28, @true %v.29
	retl %v.27
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifcnes() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cnes %s0, %s1
	jnz %c, @true, @false
@true
	%v.29 =l copy %v1
	jmp @end
@false
	%v.28 =l copy %v0
@end
	%v.27 =l phi @false %v.28, @true %v.29
	retl %v.27
}

**** Function ifcos ****
> After slot promotion:
function $ifcos() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cos %s0, %s1
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifcos() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cos %s0, %s1
	jnz %c, @true, @false
@true
	%v.34 =l copy %v1
	jmp @end
@false
	%v.33 =l copy %v0
@end
	%v.32 =l phi @false %v.33, @true %v.34
	retl %v.32
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifcos() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cos %s0, %s1
	jnz %c, @true, @false
@true
	%v.34 =l copy %v1
	jmp @end
@false
	%v.33 =l copy %v0
@end
	%v.32 =l phi @false %v.33, @true %v.34
	retl %v.32
}

**** Function ifcuos ****
> After slot promotion:
function $ifcuos() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cuos %s0, %s1
	jnz %c, @true, @false
@true
	%v =l copy %v1
	jmp @end
@false
	%v =l copy %v0
@end
	retl %v
}

> After load elimination:
function $ifcuos() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cuos %s0, %s1
	jnz %c, @true, @false
@true
	%v.37 =l copy %v1
	jmp @end
@false
	%v.36 =l copy %v0
@end
	%v.35 =l phi @false %v.36, @true %v.37
	retl %v.35
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $ifcuos() {
@start
	%s0 =s par
	%s1 =s par
	%v0 =l par
	%v1 =l par
	%c =w cuos %s0, %s1
	jnz %c, @true, @false
@true
	%v.37 =l copy %v1
	jmp @end
@false
	%v.36 =l copy %v0
@end
	%v.35 =l phi @false %v.36, @true %v.37
	retl %v.35
}

