**** Function f ****
> After slot promotion:
function $f() {
@start
	%h1 =l parc :hfa3
	%h2 =l parc :hfa3
	%d1 =d par
	%h3 =l parc :hfa3
	%d2 =d par
	argc :hfa3, %h1
	call $phfa3
	argc :hfa3, %h2
	call $phfa3
	argc :hfa3, %h3
	call $phfa3
	argl $dfmt
	argv
	argd %d1
	call $printf
	argl $dfmt
	argv
	argd %d2
	call $printf
	ret0
}

> After load elimination:
function $f() {
@start
	%h1 =l parc :hfa3
	%h2 =l parc :hfa3
	%d1 =d par
	%h3 =l parc :hfa3
	%d2 =d par
	argc :hfa3, %h1
	call $phfa3
	argc :hfa3, %h2
	call $phfa3
	argc :hfa3, %h3
	call $phfa3
	argl $dfmt
	argv
	argd %d1
	call $printf
	argl $dfmt
	argv
	argd %d2
	call $printf
	ret0
}

> Slot coalescing:
	sums 0/0/0 (killed/fused/total)

function $f() {
@start
	%h1 =l parc :hfa3
	%h2 =l parc :hfa3
	%d1 =d par
	%h3 =l parc :hfa3
	%d2 =d par
	argc :hfa3, %h1
	call $phfa3
	argc :hfa3, %h2
	call $phfa3
	argc :hfa3, %h3
	call $phfa3
	argl $dfmt
	argv
	argd %d1
	call $printf
	argl $dfmt
	argv
	argd %d2
	call $printf
	ret0
}

