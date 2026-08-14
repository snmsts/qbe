**** Function qbeprint0 ****
> After instruction selection:
function $qbeprint0() {
@start
	%fmt =l copy R7
	%isel.13 =w copy 2122789
	storew %isel.13, S1
	%isel.12 =w copy 2123557
	storew %isel.12, S0
	%isel.11 =w copy 0
	storew %isel.11, S2
	%fmt1 =l add %fmt, 1
	%abi.10 =l addr S-3
	storel %abi.10, S3
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.4 =w loadsb %p
	jnz %c.4, @loop1, @end
@loop1
	%isel.14 =w xor %c.4, 103
	%isg =w reqz %isel.14
	%p1 =l add %p, 3
	jnz %isg, @casef, @cased
@casef
	%abi.6 =l load S3
	%dbl =d load %abi.6
	%abi.7 =l add %abi.6, 8
	storel %abi.7, S3
	%abi.5 =l cast %dbl
	R8 =l copy %abi.5
	%isel.15 =l addr S0
	R7 =l copy %isel.15
	call $printf, 0021
	%r.1 =w copy R7
	jmp @loop
@cased
	%abi.8 =l load S3
	%int =w load %abi.8
	%abi.9 =l add %abi.8, 8
	storel %abi.9, S3
	R8 =w copy %int
	%isel.16 =l addr S1
	R7 =l copy %isel.16
	call $printf, 0021
	%r.2 =w copy R7
	jmp @loop
@end
	%isel.17 =l addr S2
	R7 =l copy %isel.17
	call $puts, 0011
	%r.3 =w copy R7
	ret0
}

**** Function qbecall0 ****
> After instruction selection:
function $qbecall0() {
@start
	%fmt =l copy R7
	%abi.18 =l addr S-3
	storel %abi.18, S0
	%isel.19 =l addr S0
	R8 =l copy %isel.19
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	ret0
}

**** Function qbeprint1 ****
> After instruction selection:
function $qbeprint1() {
@start
	%fmt =l copy R8
	%vw.24 =w copy R7
	%isel.33 =w copy 2122789
	storew %isel.33, S1
	%isel.32 =w copy 2123557
	storew %isel.32, S0
	%isel.31 =w copy 0
	storew %isel.31, S2
	%fmt1 =l add %fmt, 1
	%abi.30 =l addr S-4
	storel %abi.30, S3
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.23 =w loadsb %p
	jnz %c.23, @loop1, @end
@loop1
	%isel.34 =w xor %c.23, 103
	%isg =w reqz %isel.34
	%p1 =l add %p, 3
	jnz %isg, @casef, @cased
@casef
	%abi.26 =l load S3
	%dbl =d load %abi.26
	%abi.27 =l add %abi.26, 8
	storel %abi.27, S3
	%abi.25 =l cast %dbl
	R8 =l copy %abi.25
	%isel.35 =l addr S0
	R7 =l copy %isel.35
	call $printf, 0021
	%r.20 =w copy R7
	jmp @loop
@cased
	%abi.28 =l load S3
	%int =w load %abi.28
	%abi.29 =l add %abi.28, 8
	storel %abi.29, S3
	R8 =w copy %int
	%isel.36 =l addr S1
	R7 =l copy %isel.36
	call $printf, 0021
	%r.21 =w copy R7
	jmp @loop
@end
	%isel.37 =l addr S2
	R7 =l copy %isel.37
	call $puts, 0011
	%r.22 =w copy R7
	ret0
}

**** Function qbecall1 ****
> After instruction selection:
function $qbecall1() {
@start
	%fmt =l copy R8
	%argw0 =w copy R7
	%abi.38 =l addr S-4
	storel %abi.38, S0
	%isel.39 =l addr S0
	R8 =l copy %isel.39
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	ret0
}

**** Function qbeprint2 ****
> After instruction selection:
function $qbeprint2() {
@start
	%fmt =l copy R7
	%argd0 =d copy R42
	%isel.52 =w copy 2122789
	storew %isel.52, S1
	%isel.51 =w copy 2123557
	storew %isel.51, S0
	%isel.50 =w copy 0
	storew %isel.50, S2
	%fmt1 =l add %fmt, 1
	%abi.49 =l addr S-3
	storel %abi.49, S3
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.43 =w loadsb %p
	jnz %c.43, @loop1, @end
@loop1
	%isel.53 =w xor %c.43, 103
	%isg =w reqz %isel.53
	%p1 =l add %p, 3
	jnz %isg, @casef, @cased
@casef
	%abi.45 =l load S3
	%dbl =d load %abi.45
	%abi.46 =l add %abi.45, 8
	storel %abi.46, S3
	%abi.44 =l cast %dbl
	R8 =l copy %abi.44
	%isel.54 =l addr S0
	R7 =l copy %isel.54
	call $printf, 0021
	%r.40 =w copy R7
	jmp @loop
@cased
	%abi.47 =l load S3
	%int =w load %abi.47
	%abi.48 =l add %abi.47, 8
	storel %abi.48, S3
	R8 =w copy %int
	%isel.55 =l addr S1
	R7 =l copy %isel.55
	call $printf, 0021
	%r.41 =w copy R7
	jmp @loop
@end
	%isel.56 =l addr S2
	R7 =l copy %isel.56
	call $puts, 0011
	%r.42 =w copy R7
	ret0
}

**** Function qbecall2 ****
> After instruction selection:
function $qbecall2() {
@start
	%fmt =l copy R7
	%argd0 =d copy R42
	%abi.57 =l addr S-3
	storel %abi.57, S0
	%isel.58 =l addr S0
	R8 =l copy %isel.58
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	ret0
}

**** Function qbeprint3 ****
> After instruction selection:
function $qbeprint3() {
@start
	%fmt =l copy R11
	%vw.66 =w copy R10
	%vw.65 =w copy R9
	%vw.64 =w copy R8
	%vw.63 =w copy R7
	%isel.75 =w copy 2122789
	storew %isel.75, S1
	%isel.74 =w copy 2123557
	storew %isel.74, S0
	%isel.73 =w copy 0
	storew %isel.73, S2
	%fmt1 =l add %fmt, 1
	%abi.72 =l addr S-7
	storel %abi.72, S3
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.62 =w loadsb %p
	jnz %c.62, @loop1, @end
@loop1
	%isel.76 =w xor %c.62, 103
	%isg =w reqz %isel.76
	%p1 =l add %p, 3
	jnz %isg, @casef, @cased
@casef
	%abi.68 =l load S3
	%dbl =d load %abi.68
	%abi.69 =l add %abi.68, 8
	storel %abi.69, S3
	%abi.67 =l cast %dbl
	R8 =l copy %abi.67
	%isel.77 =l addr S0
	R7 =l copy %isel.77
	call $printf, 0021
	%r.59 =w copy R7
	jmp @loop
@cased
	%abi.70 =l load S3
	%int =w load %abi.70
	%abi.71 =l add %abi.70, 8
	storel %abi.71, S3
	R8 =w copy %int
	%isel.78 =l addr S1
	R7 =l copy %isel.78
	call $printf, 0021
	%r.60 =w copy R7
	jmp @loop
@end
	%isel.79 =l addr S2
	R7 =l copy %isel.79
	call $puts, 0011
	%r.61 =w copy R7
	ret0
}

**** Function qbecall3 ****
> After instruction selection:
function $qbecall3() {
@start
	%fmt =l copy R11
	%argw3 =w copy R10
	%argw2 =w copy R9
	%argw1 =w copy R8
	%argw0 =w copy R7
	%abi.80 =l addr S-7
	storel %abi.80, S0
	%isel.81 =l addr S0
	R8 =l copy %isel.81
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	ret0
}

**** Function qbeprint4 ****
> After instruction selection:
function $qbeprint4() {
@start
	%fmt =l copy R7
	%argd5 =d copy R47
	%argd4 =d copy R46
	%argd3 =d copy R45
	%argd2 =d copy R44
	%argd1 =d copy R43
	%argd0 =d copy R42
	%isel.94 =w copy 2122789
	storew %isel.94, S1
	%isel.93 =w copy 2123557
	storew %isel.93, S0
	%isel.92 =w copy 0
	storew %isel.92, S2
	%fmt1 =l add %fmt, 1
	%abi.91 =l addr S-3
	storel %abi.91, S3
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.85 =w loadsb %p
	jnz %c.85, @loop1, @end
@loop1
	%isel.95 =w xor %c.85, 103
	%isg =w reqz %isel.95
	%p1 =l add %p, 3
	jnz %isg, @casef, @cased
@casef
	%abi.87 =l load S3
	%dbl =d load %abi.87
	%abi.88 =l add %abi.87, 8
	storel %abi.88, S3
	%abi.86 =l cast %dbl
	R8 =l copy %abi.86
	%isel.96 =l addr S0
	R7 =l copy %isel.96
	call $printf, 0021
	%r.82 =w copy R7
	jmp @loop
@cased
	%abi.89 =l load S3
	%int =w load %abi.89
	%abi.90 =l add %abi.89, 8
	storel %abi.90, S3
	R8 =w copy %int
	%isel.97 =l addr S1
	R7 =l copy %isel.97
	call $printf, 0021
	%r.83 =w copy R7
	jmp @loop
@end
	%isel.98 =l addr S2
	R7 =l copy %isel.98
	call $puts, 0011
	%r.84 =w copy R7
	ret0
}

**** Function qbecall4 ****
> After instruction selection:
function $qbecall4() {
@start
	%fmt =l copy R7
	%argd5 =d copy R47
	%argd4 =d copy R46
	%argd3 =d copy R45
	%argd2 =d copy R44
	%argd1 =d copy R43
	%argd0 =d copy R42
	%abi.99 =l addr S-3
	storel %abi.99, S0
	%isel.100 =l addr S0
	R8 =l copy %isel.100
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	ret0
}

**** Function qbeprint5 ****
> After instruction selection:
function $qbeprint5() {
@start
	%fmt =l copy R12
	%argd6 =d copy R48
	%argd5 =d copy R47
	%argd4 =d copy R46
	%argd3 =d copy R45
	%argd2 =d copy R44
	%argd1 =d copy R43
	%argd0 =d copy R42
	%vw.109 =w copy R11
	%vw.108 =w copy R10
	%vw.107 =w copy R9
	%vw.106 =w copy R8
	%vw.105 =w copy R7
	%isel.118 =w copy 2122789
	storew %isel.118, S1
	%isel.117 =w copy 2123557
	storew %isel.117, S0
	%isel.116 =w copy 0
	storew %isel.116, S2
	%fmt1 =l add %fmt, 1
	%abi.115 =l addr S-8
	storel %abi.115, S3
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.104 =w loadsb %p
	jnz %c.104, @loop1, @end
@loop1
	%isel.119 =w xor %c.104, 103
	%isg =w reqz %isel.119
	%p1 =l add %p, 3
	jnz %isg, @casef, @cased
@casef
	%abi.111 =l load S3
	%dbl =d load %abi.111
	%abi.112 =l add %abi.111, 8
	storel %abi.112, S3
	%abi.110 =l cast %dbl
	R8 =l copy %abi.110
	%isel.120 =l addr S0
	R7 =l copy %isel.120
	call $printf, 0021
	%r.101 =w copy R7
	jmp @loop
@cased
	%abi.113 =l load S3
	%int =w load %abi.113
	%abi.114 =l add %abi.113, 8
	storel %abi.114, S3
	R8 =w copy %int
	%isel.121 =l addr S1
	R7 =l copy %isel.121
	call $printf, 0021
	%r.102 =w copy R7
	jmp @loop
@end
	%isel.122 =l addr S2
	R7 =l copy %isel.122
	call $puts, 0011
	%r.103 =w copy R7
	ret0
}

**** Function qbecall5 ****
> After instruction selection:
function $qbecall5() {
@start
	%fmt =l copy R12
	%argd6 =d copy R48
	%argd5 =d copy R47
	%argd4 =d copy R46
	%argd3 =d copy R45
	%argd2 =d copy R44
	%argd1 =d copy R43
	%argd0 =d copy R42
	%argw4 =w copy R11
	%argw3 =w copy R10
	%argw2 =w copy R9
	%argw1 =w copy R8
	%argw0 =w copy R7
	%abi.123 =l addr S-8
	storel %abi.123, S0
	%isel.124 =l addr S0
	R8 =l copy %isel.124
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	ret0
}

**** Function qbeprint6 ****
> After instruction selection:
function $qbeprint6() {
@start
	%fmt =l load S-14
	%argd9 =d load S-13
	%argd8 =d load S-12
	%argd7 =d copy R49
	%argd6 =d copy R48
	%argd5 =d copy R47
	%argd4 =d copy R46
	%argd3 =d copy R45
	%argd2 =d copy R44
	%argd1 =d copy R43
	%argd0 =d copy R42
	%vw.138 =w load S-11
	%vw.137 =w load S-10
	%vw.136 =w copy R14
	%vw.135 =w copy R13
	%vw.134 =w copy R12
	%vw.133 =w copy R11
	%vw.132 =w copy R10
	%vw.131 =w copy R9
	%vw.130 =w copy R8
	%vw.129 =w copy R7
	%isel.147 =w copy 2122789
	storew %isel.147, S1
	%isel.146 =w copy 2123557
	storew %isel.146, S0
	%isel.145 =w copy 0
	storew %isel.145, S2
	%fmt1 =l add %fmt, 1
	%abi.144 =l addr S-15
	storel %abi.144, S3
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.128 =w loadsb %p
	jnz %c.128, @loop1, @end
@loop1
	%isel.148 =w xor %c.128, 103
	%isg =w reqz %isel.148
	%p1 =l add %p, 3
	jnz %isg, @casef, @cased
@casef
	%abi.140 =l load S3
	%dbl =d load %abi.140
	%abi.141 =l add %abi.140, 8
	storel %abi.141, S3
	%abi.139 =l cast %dbl
	R8 =l copy %abi.139
	%isel.149 =l addr S0
	R7 =l copy %isel.149
	call $printf, 0021
	%r.125 =w copy R7
	jmp @loop
@cased
	%abi.142 =l load S3
	%int =w load %abi.142
	%abi.143 =l add %abi.142, 8
	storel %abi.143, S3
	R8 =w copy %int
	%isel.150 =l addr S1
	R7 =l copy %isel.150
	call $printf, 0021
	%r.126 =w copy R7
	jmp @loop
@end
	%isel.151 =l addr S2
	R7 =l copy %isel.151
	call $puts, 0011
	%r.127 =w copy R7
	ret0
}

**** Function qbecall6 ****
> After instruction selection:
function $qbecall6() {
@start
	%fmt =l load S-14
	%argd9 =d load S-13
	%argd8 =d load S-12
	%argd7 =d copy R49
	%argd6 =d copy R48
	%argd5 =d copy R47
	%argd4 =d copy R46
	%argd3 =d copy R45
	%argd2 =d copy R44
	%argd1 =d copy R43
	%argd0 =d copy R42
	%argw9 =w load S-11
	%argw8 =w load S-10
	%argw7 =w copy R14
	%argw6 =w copy R13
	%argw5 =w copy R12
	%argw4 =w copy R11
	%argw3 =w copy R10
	%argw2 =w copy R9
	%argw1 =w copy R8
	%argw0 =w copy R7
	%abi.152 =l addr S-15
	storel %abi.152, S0
	%isel.153 =l addr S0
	R8 =l copy %isel.153
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	ret0
}

**** Function qbeprint7 ****
> After instruction selection:
function $qbeprint7() {
@start
	%fmt =l load S-11
	%vw.166 =w load S-10
	%vw.165 =w copy R14
	%vw.164 =w copy R13
	%vw.163 =w copy R12
	%vw.162 =w copy R11
	%vw.161 =w copy R10
	%vw.160 =w copy R9
	%vw.159 =w copy R8
	%vw.158 =w copy R7
	%isel.175 =w copy 2122789
	storew %isel.175, S1
	%isel.174 =w copy 2123557
	storew %isel.174, S0
	%isel.173 =w copy 0
	storew %isel.173, S2
	%fmt1 =l add %fmt, 1
	%abi.172 =l addr S-12
	storel %abi.172, S3
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.157 =w loadsb %p
	jnz %c.157, @loop1, @end
@loop1
	%isel.176 =w xor %c.157, 103
	%isg =w reqz %isel.176
	%p1 =l add %p, 3
	jnz %isg, @casef, @cased
@casef
	%abi.168 =l load S3
	%dbl =d load %abi.168
	%abi.169 =l add %abi.168, 8
	storel %abi.169, S3
	%abi.167 =l cast %dbl
	R8 =l copy %abi.167
	%isel.177 =l addr S0
	R7 =l copy %isel.177
	call $printf, 0021
	%r.154 =w copy R7
	jmp @loop
@cased
	%abi.170 =l load S3
	%int =w load %abi.170
	%abi.171 =l add %abi.170, 8
	storel %abi.171, S3
	R8 =w copy %int
	%isel.178 =l addr S1
	R7 =l copy %isel.178
	call $printf, 0021
	%r.155 =w copy R7
	jmp @loop
@end
	%isel.179 =l addr S2
	R7 =l copy %isel.179
	call $puts, 0011
	%r.156 =w copy R7
	ret0
}

**** Function qbecall7 ****
> After instruction selection:
function $qbecall7() {
@start
	%fmt =l load S-11
	%argw8 =w load S-10
	%argw7 =w copy R14
	%argw6 =w copy R13
	%argw5 =w copy R12
	%argw4 =w copy R11
	%argw3 =w copy R10
	%argw2 =w copy R9
	%argw1 =w copy R8
	%argw0 =w copy R7
	%abi.180 =l addr S-12
	storel %abi.180, S0
	%isel.181 =l addr S0
	R8 =l copy %isel.181
	R7 =l copy %fmt
	call $print, 0021
	%r =w copy R7
	ret0
}

