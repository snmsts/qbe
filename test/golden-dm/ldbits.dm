**** Function tests ****
> After slot promotion:
function $tests() {
@start
	%p =l alloc8 16
	%p3 =l add %p, 3
	%p4 =l add %p, 4
	%p6 =l add %p, 6
	%p8 =l add %p, 8
@test1
	storew 1, $a
	storel 1311768467139281697, %p
	storeh 255, %p8
	%x1 =w load %p6
	%c1 =w cnew %x1, 16716340
	jnz %c1, @fail, @test2
@test2
	storew 2, $a
	%x2 =w loadub %p3
	%c2 =w cnew %x2, 135
	jnz %c2, @fail, @test3
@test3
	storew 3, $a
	storew 2864434397, %p8
	%x3 =l load %p3
	%c3 =w cnel %x3, -4914310023110821753
	jnz %c3, @fail, @test4
@test4
@ok
	storew 0, $a
@fail
	ret0
}

> After load elimination:
function $tests() {
@start
	%p =l alloc8 16
	%p3 =l add %p, 3
	%p4 =l add %p, 4
	%p6 =l add %p, 6
	%p8 =l add %p, 8
@test1
	storew 1, $a
	storel 1311768467139281697, %p
	storeh 255, %p8
	%ld.1 =w shl 255, 16
	%ld.2 =l shr 1311768467139281697, 48
	%ld.3 =w or %ld.1, %ld.2
	%x1 =w copy %ld.3
	%c1 =w cnew %x1, 16716340
	jnz %c1, @fail, @test2
@test2
	storew 2, $a
	%ld.4 =w shr 1311768467139281697, 24
	%x2 =w extub %ld.4
	%c2 =w cnew %x2, 135
	jnz %c2, @fail, @test3
@test3
	storew 3, $a
	storew 2864434397, %p8
	%ld.5 =l shl 2864434397, 40
	%ld.6 =l extuw %x2
	%ld.7 =l and %ld.6, 255
	%ld.8 =l extuw %x1
	%ld.9 =l shl %ld.8, 24
	%ld.10 =l and %ld.9, 1099494850560
	%ld.11 =l shr 1311768467139281697, 24
	%ld.12 =l and %ld.11, 16776960
	%ld.13 =l or %ld.10, %ld.12
	%ld.14 =l or %ld.7, %ld.13
	%ld.15 =l or %ld.5, %ld.14
	%x3 =l copy %ld.15
	%c3 =w cnel %x3, -4914310023110821753
	jnz %c3, @fail, @test4
@test4
@ok
	storew 0, $a
@fail
	ret0
}

> Slot coalescing:
	kill [ %p ]
	sums 16/0/16 (killed/fused/total)

function $tests() {
@start
	nop
	nop
	nop
	nop
	nop
@test1
	storew 1, $a
	nop
	nop
	%ld.1 =w shl 255, 16
	%ld.2 =l shr 1311768467139281697, 48
	%ld.3 =w or %ld.1, %ld.2
	%x1 =w copy %ld.3
	%c1 =w cnew %x1, 16716340
	jnz %c1, @fail, @test2
@test2
	storew 2, $a
	%ld.4 =w shr 1311768467139281697, 24
	%x2 =w extub %ld.4
	%c2 =w cnew %x2, 135
	jnz %c2, @fail, @test3
@test3
	storew 3, $a
	nop
	%ld.5 =l shl 2864434397, 40
	%ld.6 =l extuw %x2
	%ld.7 =l and %ld.6, 255
	%ld.8 =l extuw %x1
	%ld.9 =l shl %ld.8, 24
	%ld.10 =l and %ld.9, 1099494850560
	%ld.11 =l shr 1311768467139281697, 24
	%ld.12 =l and %ld.11, 16776960
	%ld.13 =l or %ld.10, %ld.12
	%ld.14 =l or %ld.7, %ld.13
	%ld.15 =l or %ld.5, %ld.14
	%x3 =l copy %ld.15
	%c3 =w cnel %x3, -4914310023110821753
	jnz %c3, @fail, @test4
@test4
@ok
	storew 0, $a
@fail
	ret0
}

