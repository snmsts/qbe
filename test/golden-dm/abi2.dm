**** Function sum ****
> After slot promotion:
function $sum() {
@start
	%p =l parc :fps
	%f1 =s load %p
	%p8 =l add 8, %p
	%f2 =s load %p8
	%s =s add %f1, %f2
	rets %s
}

> After load elimination:
function $sum() {
@start
	%p =l parc :fps
	%f1 =s load %p
	%p8 =l add 8, %p
	%f2 =s load %p8
	%s =s add %f1, %f2
	rets %s
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $sum() {
@start
	%p =l parc :fps
	%f1 =s load %p
	%p8 =l add 8, %p
	%f2 =s load %p8
	%s =s add %f1, %f2
	rets %s
}

