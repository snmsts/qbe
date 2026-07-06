**** Function qbeprint0 ****
> After instruction selection:
function $qbeprint0() {
@start
	%fmt =l copy R5
	storew 2122789, [S1]
	storew 2123557, [S0]
	storew 0, [S2]
	%fmt1 =l add %fmt, 1
	storew 8, [S3]
	storew 48, [4 + S3]
	%abi.32 =l add R15, 16
	storel %abi.32, [8 + S3]
	%abi.30 =l add R15, -176
	storel %abi.30, [16 + S3]
@loop
	%p =l phi @start %fmt1, @casef.1 %p1, @cased.1 %p1
	%c.4 =w loadsb [%p]
	xcmpw 0, %c.4
	jfine @loop1, @end
@loop1
	xcmpw 103, %c.4
	%isg =w flagieq
	%p1 =l add %p, 3
	xcmpw 0, %isg
	jfine @casef, @cased
@casef
	%abi.7 =l loadsw [4 + S3]
	xcmpw 176, %abi.7
	jfiult @casef.2, @casef.3
@casef.3
	%abi.12 =l load [8 + S3]
	%abi.14 =l add %abi.12, 8
	storel %abi.14, [8 + S3]
	jmp @casef.1
@casef.2
	%abi.11 =l load [16 + S3]
	%abi.6 =l add %abi.11, %abi.7
	%abi.8 =w add %abi.7, 16
	storew %abi.8, [4 + S3]
@casef.1
	%abi.5 =l phi @casef.3 %abi.12, @casef.2 %abi.6
	%dbl =d load [%abi.5]
	R17 =d copy %dbl
	%isel.34 =l addr S0
	R5 =l copy %isel.34
	R1 =w copy 1
	call $printf, 1111
	%r.1 =w copy R1
	jmp @loop
@cased
	%abi.19 =l loadsw [0 + S3]
	xcmpw 48, %abi.19
	jfiult @cased.2, @cased.3
@cased.3
	%abi.24 =l load [8 + S3]
	%abi.26 =l add %abi.24, 8
	storel %abi.26, [8 + S3]
	jmp @cased.1
@cased.2
	%abi.23 =l load [16 + S3]
	%abi.18 =l add %abi.23, %abi.19
	%abi.20 =w add %abi.19, 8
	storew %abi.20, [0 + S3]
@cased.1
	%abi.17 =l phi @cased.3 %abi.24, @cased.2 %abi.18
	%int =w load [%abi.17]
	R4 =w copy %int
	%isel.35 =l addr S1
	R5 =l copy %isel.35
	R1 =w copy 0
	call $printf, 1021
	%r.2 =w copy R1
	jmp @loop
@end
	%isel.36 =l addr S2
	R5 =l copy %isel.36
	call $puts, 0011
	%r.3 =w copy R1
	ret0
}

**** Function qbecall0 ****
> After instruction selection:
function $qbecall0() {
@start
	%fmt =l copy R5
	storew 8, [S0]
	storew 48, [4 + S0]
	%abi.40 =l add R15, 16
	storel %abi.40, [8 + S0]
	%abi.38 =l add R15, -176
	storel %abi.38, [16 + S0]
	%isel.42 =l addr S0
	R4 =l copy %isel.42
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	ret0
}

**** Function qbeprint1 ****
> After instruction selection:
function $qbeprint1() {
@start
	%fmt =l copy R4
	%vw.47 =w copy R5
	storew 2122789, [S1]
	storew 2123557, [S0]
	storew 0, [S2]
	%fmt1 =l add %fmt, 1
	storew 16, [S3]
	storew 48, [4 + S3]
	%abi.75 =l add R15, 16
	storel %abi.75, [8 + S3]
	%abi.73 =l add R15, -176
	storel %abi.73, [16 + S3]
@loop
	%p =l phi @start %fmt1, @casef.1 %p1, @cased.1 %p1
	%c.46 =w loadsb [%p]
	xcmpw 0, %c.46
	jfine @loop1, @end
@loop1
	xcmpw 103, %c.46
	%isg =w flagieq
	%p1 =l add %p, 3
	xcmpw 0, %isg
	jfine @casef, @cased
@casef
	%abi.50 =l loadsw [4 + S3]
	xcmpw 176, %abi.50
	jfiult @casef.2, @casef.3
@casef.3
	%abi.55 =l load [8 + S3]
	%abi.57 =l add %abi.55, 8
	storel %abi.57, [8 + S3]
	jmp @casef.1
@casef.2
	%abi.54 =l load [16 + S3]
	%abi.49 =l add %abi.54, %abi.50
	%abi.51 =w add %abi.50, 16
	storew %abi.51, [4 + S3]
@casef.1
	%abi.48 =l phi @casef.3 %abi.55, @casef.2 %abi.49
	%dbl =d load [%abi.48]
	R17 =d copy %dbl
	%isel.77 =l addr S0
	R5 =l copy %isel.77
	R1 =w copy 1
	call $printf, 1111
	%r.43 =w copy R1
	jmp @loop
@cased
	%abi.62 =l loadsw [0 + S3]
	xcmpw 48, %abi.62
	jfiult @cased.2, @cased.3
@cased.3
	%abi.67 =l load [8 + S3]
	%abi.69 =l add %abi.67, 8
	storel %abi.69, [8 + S3]
	jmp @cased.1
@cased.2
	%abi.66 =l load [16 + S3]
	%abi.61 =l add %abi.66, %abi.62
	%abi.63 =w add %abi.62, 8
	storew %abi.63, [0 + S3]
@cased.1
	%abi.60 =l phi @cased.3 %abi.67, @cased.2 %abi.61
	%int =w load [%abi.60]
	R4 =w copy %int
	%isel.78 =l addr S1
	R5 =l copy %isel.78
	R1 =w copy 0
	call $printf, 1021
	%r.44 =w copy R1
	jmp @loop
@end
	%isel.79 =l addr S2
	R5 =l copy %isel.79
	call $puts, 0011
	%r.45 =w copy R1
	ret0
}

**** Function qbecall1 ****
> After instruction selection:
function $qbecall1() {
@start
	%fmt =l copy R4
	%argw0 =w copy R5
	storew 16, [S0]
	storew 48, [4 + S0]
	%abi.83 =l add R15, 16
	storel %abi.83, [8 + S0]
	%abi.81 =l add R15, -176
	storel %abi.81, [16 + S0]
	%isel.85 =l addr S0
	R4 =l copy %isel.85
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	ret0
}

**** Function qbeprint2 ****
> After instruction selection:
function $qbeprint2() {
@start
	%fmt =l copy R5
	%argd0 =d copy R17
	storew 2122789, [S1]
	storew 2123557, [S0]
	storew 0, [S2]
	%fmt1 =l add %fmt, 1
	storew 8, [S3]
	storew 64, [4 + S3]
	%abi.117 =l add R15, 16
	storel %abi.117, [8 + S3]
	%abi.115 =l add R15, -176
	storel %abi.115, [16 + S3]
@loop
	%p =l phi @start %fmt1, @casef.1 %p1, @cased.1 %p1
	%c.89 =w loadsb [%p]
	xcmpw 0, %c.89
	jfine @loop1, @end
@loop1
	xcmpw 103, %c.89
	%isg =w flagieq
	%p1 =l add %p, 3
	xcmpw 0, %isg
	jfine @casef, @cased
@casef
	%abi.92 =l loadsw [4 + S3]
	xcmpw 176, %abi.92
	jfiult @casef.2, @casef.3
@casef.3
	%abi.97 =l load [8 + S3]
	%abi.99 =l add %abi.97, 8
	storel %abi.99, [8 + S3]
	jmp @casef.1
@casef.2
	%abi.96 =l load [16 + S3]
	%abi.91 =l add %abi.96, %abi.92
	%abi.93 =w add %abi.92, 16
	storew %abi.93, [4 + S3]
@casef.1
	%abi.90 =l phi @casef.3 %abi.97, @casef.2 %abi.91
	%dbl =d load [%abi.90]
	R17 =d copy %dbl
	%isel.119 =l addr S0
	R5 =l copy %isel.119
	R1 =w copy 1
	call $printf, 1111
	%r.86 =w copy R1
	jmp @loop
@cased
	%abi.104 =l loadsw [0 + S3]
	xcmpw 48, %abi.104
	jfiult @cased.2, @cased.3
@cased.3
	%abi.109 =l load [8 + S3]
	%abi.111 =l add %abi.109, 8
	storel %abi.111, [8 + S3]
	jmp @cased.1
@cased.2
	%abi.108 =l load [16 + S3]
	%abi.103 =l add %abi.108, %abi.104
	%abi.105 =w add %abi.104, 8
	storew %abi.105, [0 + S3]
@cased.1
	%abi.102 =l phi @cased.3 %abi.109, @cased.2 %abi.103
	%int =w load [%abi.102]
	R4 =w copy %int
	%isel.120 =l addr S1
	R5 =l copy %isel.120
	R1 =w copy 0
	call $printf, 1021
	%r.87 =w copy R1
	jmp @loop
@end
	%isel.121 =l addr S2
	R5 =l copy %isel.121
	call $puts, 0011
	%r.88 =w copy R1
	ret0
}

**** Function qbecall2 ****
> After instruction selection:
function $qbecall2() {
@start
	%fmt =l copy R5
	%argd0 =d copy R17
	storew 8, [S0]
	storew 64, [4 + S0]
	%abi.125 =l add R15, 16
	storel %abi.125, [8 + S0]
	%abi.123 =l add R15, -176
	storel %abi.123, [16 + S0]
	%isel.127 =l addr S0
	R4 =l copy %isel.127
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	ret0
}

**** Function qbeprint3 ****
> After instruction selection:
function $qbeprint3() {
@start
	%fmt =l copy R6
	%vw.135 =w copy R2
	%vw.134 =w copy R3
	%vw.133 =w copy R4
	%vw.132 =w copy R5
	storew 2122789, [S1]
	storew 2123557, [S0]
	storew 0, [S2]
	%fmt1 =l add %fmt, 1
	storew 40, [S3]
	storew 48, [4 + S3]
	%abi.163 =l add R15, 16
	storel %abi.163, [8 + S3]
	%abi.161 =l add R15, -176
	storel %abi.161, [16 + S3]
@loop
	%p =l phi @start %fmt1, @casef.1 %p1, @cased.1 %p1
	%c.131 =w loadsb [%p]
	xcmpw 0, %c.131
	jfine @loop1, @end
@loop1
	xcmpw 103, %c.131
	%isg =w flagieq
	%p1 =l add %p, 3
	xcmpw 0, %isg
	jfine @casef, @cased
@casef
	%abi.138 =l loadsw [4 + S3]
	xcmpw 176, %abi.138
	jfiult @casef.2, @casef.3
@casef.3
	%abi.143 =l load [8 + S3]
	%abi.145 =l add %abi.143, 8
	storel %abi.145, [8 + S3]
	jmp @casef.1
@casef.2
	%abi.142 =l load [16 + S3]
	%abi.137 =l add %abi.142, %abi.138
	%abi.139 =w add %abi.138, 16
	storew %abi.139, [4 + S3]
@casef.1
	%abi.136 =l phi @casef.3 %abi.143, @casef.2 %abi.137
	%dbl =d load [%abi.136]
	R17 =d copy %dbl
	%isel.165 =l addr S0
	R5 =l copy %isel.165
	R1 =w copy 1
	call $printf, 1111
	%r.128 =w copy R1
	jmp @loop
@cased
	%abi.150 =l loadsw [0 + S3]
	xcmpw 48, %abi.150
	jfiult @cased.2, @cased.3
@cased.3
	%abi.155 =l load [8 + S3]
	%abi.157 =l add %abi.155, 8
	storel %abi.157, [8 + S3]
	jmp @cased.1
@cased.2
	%abi.154 =l load [16 + S3]
	%abi.149 =l add %abi.154, %abi.150
	%abi.151 =w add %abi.150, 8
	storew %abi.151, [0 + S3]
@cased.1
	%abi.148 =l phi @cased.3 %abi.155, @cased.2 %abi.149
	%int =w load [%abi.148]
	R4 =w copy %int
	%isel.166 =l addr S1
	R5 =l copy %isel.166
	R1 =w copy 0
	call $printf, 1021
	%r.129 =w copy R1
	jmp @loop
@end
	%isel.167 =l addr S2
	R5 =l copy %isel.167
	call $puts, 0011
	%r.130 =w copy R1
	ret0
}

**** Function qbecall3 ****
> After instruction selection:
function $qbecall3() {
@start
	%fmt =l copy R6
	%argw3 =w copy R2
	%argw2 =w copy R3
	%argw1 =w copy R4
	%argw0 =w copy R5
	storew 40, [S0]
	storew 48, [4 + S0]
	%abi.171 =l add R15, 16
	storel %abi.171, [8 + S0]
	%abi.169 =l add R15, -176
	storel %abi.169, [16 + S0]
	%isel.173 =l addr S0
	R4 =l copy %isel.173
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	ret0
}

**** Function qbeprint4 ****
> After instruction selection:
function $qbeprint4() {
@start
	%fmt =l copy R5
	%argd5 =d copy R22
	%argd4 =d copy R21
	%argd3 =d copy R20
	%argd2 =d copy R19
	%argd1 =d copy R18
	%argd0 =d copy R17
	storew 2122789, [S1]
	storew 2123557, [S0]
	storew 0, [S2]
	%fmt1 =l add %fmt, 1
	storew 8, [S3]
	storew 144, [4 + S3]
	%abi.205 =l add R15, 16
	storel %abi.205, [8 + S3]
	%abi.203 =l add R15, -176
	storel %abi.203, [16 + S3]
@loop
	%p =l phi @start %fmt1, @casef.1 %p1, @cased.1 %p1
	%c.177 =w loadsb [%p]
	xcmpw 0, %c.177
	jfine @loop1, @end
@loop1
	xcmpw 103, %c.177
	%isg =w flagieq
	%p1 =l add %p, 3
	xcmpw 0, %isg
	jfine @casef, @cased
@casef
	%abi.180 =l loadsw [4 + S3]
	xcmpw 176, %abi.180
	jfiult @casef.2, @casef.3
@casef.3
	%abi.185 =l load [8 + S3]
	%abi.187 =l add %abi.185, 8
	storel %abi.187, [8 + S3]
	jmp @casef.1
@casef.2
	%abi.184 =l load [16 + S3]
	%abi.179 =l add %abi.184, %abi.180
	%abi.181 =w add %abi.180, 16
	storew %abi.181, [4 + S3]
@casef.1
	%abi.178 =l phi @casef.3 %abi.185, @casef.2 %abi.179
	%dbl =d load [%abi.178]
	R17 =d copy %dbl
	%isel.207 =l addr S0
	R5 =l copy %isel.207
	R1 =w copy 1
	call $printf, 1111
	%r.174 =w copy R1
	jmp @loop
@cased
	%abi.192 =l loadsw [0 + S3]
	xcmpw 48, %abi.192
	jfiult @cased.2, @cased.3
@cased.3
	%abi.197 =l load [8 + S3]
	%abi.199 =l add %abi.197, 8
	storel %abi.199, [8 + S3]
	jmp @cased.1
@cased.2
	%abi.196 =l load [16 + S3]
	%abi.191 =l add %abi.196, %abi.192
	%abi.193 =w add %abi.192, 8
	storew %abi.193, [0 + S3]
@cased.1
	%abi.190 =l phi @cased.3 %abi.197, @cased.2 %abi.191
	%int =w load [%abi.190]
	R4 =w copy %int
	%isel.208 =l addr S1
	R5 =l copy %isel.208
	R1 =w copy 0
	call $printf, 1021
	%r.175 =w copy R1
	jmp @loop
@end
	%isel.209 =l addr S2
	R5 =l copy %isel.209
	call $puts, 0011
	%r.176 =w copy R1
	ret0
}

**** Function qbecall4 ****
> After instruction selection:
function $qbecall4() {
@start
	%fmt =l copy R5
	%argd5 =d copy R22
	%argd4 =d copy R21
	%argd3 =d copy R20
	%argd2 =d copy R19
	%argd1 =d copy R18
	%argd0 =d copy R17
	storew 8, [S0]
	storew 144, [4 + S0]
	%abi.213 =l add R15, 16
	storel %abi.213, [8 + S0]
	%abi.211 =l add R15, -176
	storel %abi.211, [16 + S0]
	%isel.215 =l addr S0
	R4 =l copy %isel.215
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	ret0
}

**** Function qbeprint5 ****
> After instruction selection:
function $qbeprint5() {
@start
	%fmt =l copy R7
	%argd6 =d copy R23
	%argd5 =d copy R22
	%argd4 =d copy R21
	%argd3 =d copy R20
	%argd2 =d copy R19
	%argd1 =d copy R18
	%argd0 =d copy R17
	%vw.224 =w copy R6
	%vw.223 =w copy R2
	%vw.222 =w copy R3
	%vw.221 =w copy R4
	%vw.220 =w copy R5
	storew 2122789, [S1]
	storew 2123557, [S0]
	storew 0, [S2]
	%fmt1 =l add %fmt, 1
	storew 48, [S3]
	storew 160, [4 + S3]
	%abi.252 =l add R15, 16
	storel %abi.252, [8 + S3]
	%abi.250 =l add R15, -176
	storel %abi.250, [16 + S3]
@loop
	%p =l phi @start %fmt1, @casef.1 %p1, @cased.1 %p1
	%c.219 =w loadsb [%p]
	xcmpw 0, %c.219
	jfine @loop1, @end
@loop1
	xcmpw 103, %c.219
	%isg =w flagieq
	%p1 =l add %p, 3
	xcmpw 0, %isg
	jfine @casef, @cased
@casef
	%abi.227 =l loadsw [4 + S3]
	xcmpw 176, %abi.227
	jfiult @casef.2, @casef.3
@casef.3
	%abi.232 =l load [8 + S3]
	%abi.234 =l add %abi.232, 8
	storel %abi.234, [8 + S3]
	jmp @casef.1
@casef.2
	%abi.231 =l load [16 + S3]
	%abi.226 =l add %abi.231, %abi.227
	%abi.228 =w add %abi.227, 16
	storew %abi.228, [4 + S3]
@casef.1
	%abi.225 =l phi @casef.3 %abi.232, @casef.2 %abi.226
	%dbl =d load [%abi.225]
	R17 =d copy %dbl
	%isel.254 =l addr S0
	R5 =l copy %isel.254
	R1 =w copy 1
	call $printf, 1111
	%r.216 =w copy R1
	jmp @loop
@cased
	%abi.239 =l loadsw [0 + S3]
	xcmpw 48, %abi.239
	jfiult @cased.2, @cased.3
@cased.3
	%abi.244 =l load [8 + S3]
	%abi.246 =l add %abi.244, 8
	storel %abi.246, [8 + S3]
	jmp @cased.1
@cased.2
	%abi.243 =l load [16 + S3]
	%abi.238 =l add %abi.243, %abi.239
	%abi.240 =w add %abi.239, 8
	storew %abi.240, [0 + S3]
@cased.1
	%abi.237 =l phi @cased.3 %abi.244, @cased.2 %abi.238
	%int =w load [%abi.237]
	R4 =w copy %int
	%isel.255 =l addr S1
	R5 =l copy %isel.255
	R1 =w copy 0
	call $printf, 1021
	%r.217 =w copy R1
	jmp @loop
@end
	%isel.256 =l addr S2
	R5 =l copy %isel.256
	call $puts, 0011
	%r.218 =w copy R1
	ret0
}

**** Function qbecall5 ****
> After instruction selection:
function $qbecall5() {
@start
	%fmt =l copy R7
	%argd6 =d copy R23
	%argd5 =d copy R22
	%argd4 =d copy R21
	%argd3 =d copy R20
	%argd2 =d copy R19
	%argd1 =d copy R18
	%argd0 =d copy R17
	%argw4 =w copy R6
	%argw3 =w copy R2
	%argw2 =w copy R3
	%argw1 =w copy R4
	%argw0 =w copy R5
	storew 48, [S0]
	storew 160, [4 + S0]
	%abi.260 =l add R15, 16
	storel %abi.260, [8 + S0]
	%abi.258 =l add R15, -176
	storel %abi.258, [16 + S0]
	%isel.262 =l addr S0
	R4 =l copy %isel.262
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	ret0
}

**** Function qbeprint6 ****
> After instruction selection:
function $qbeprint6() {
@start
	%fmt =l load S-16
	%argd7 =d copy R24
	%argd6 =d copy R23
	%argd5 =d copy R22
	%argd4 =d copy R21
	%argd3 =d copy R20
	%argd2 =d copy R19
	%argd1 =d copy R18
	%argd0 =d copy R17
	%vw.272 =w copy R7
	%vw.271 =w copy R6
	%vw.270 =w copy R2
	%vw.269 =w copy R3
	%vw.268 =w copy R4
	%vw.267 =w copy R5
	storew 2122789, [S1]
	storew 2123557, [S0]
	storew 0, [S2]
	%fmt1 =l add %fmt, 1
	storew 48, [S3]
	storew 176, [4 + S3]
	%abi.304 =l add R15, 72
	storel %abi.304, [8 + S3]
	%abi.302 =l add R15, -176
	storel %abi.302, [16 + S3]
@loop
	%p =l phi @start %fmt1, @casef.1 %p1, @cased.1 %p1
	%c.266 =w loadsb [%p]
	xcmpw 0, %c.266
	jfine @loop1, @end
@loop1
	xcmpw 103, %c.266
	%isg =w flagieq
	%p1 =l add %p, 3
	xcmpw 0, %isg
	jfine @casef, @cased
@casef
	%abi.279 =l loadsw [4 + S3]
	xcmpw 176, %abi.279
	jfiult @casef.2, @casef.3
@casef.3
	%abi.284 =l load [8 + S3]
	%abi.286 =l add %abi.284, 8
	storel %abi.286, [8 + S3]
	jmp @casef.1
@casef.2
	%abi.283 =l load [16 + S3]
	%abi.278 =l add %abi.283, %abi.279
	%abi.280 =w add %abi.279, 16
	storew %abi.280, [4 + S3]
@casef.1
	%abi.277 =l phi @casef.3 %abi.284, @casef.2 %abi.278
	%dbl =d load [%abi.277]
	R17 =d copy %dbl
	%isel.306 =l addr S0
	R5 =l copy %isel.306
	R1 =w copy 1
	call $printf, 1111
	%r.263 =w copy R1
	jmp @loop
@cased
	%abi.291 =l loadsw [0 + S3]
	xcmpw 48, %abi.291
	jfiult @cased.2, @cased.3
@cased.3
	%abi.296 =l load [8 + S3]
	%abi.298 =l add %abi.296, 8
	storel %abi.298, [8 + S3]
	jmp @cased.1
@cased.2
	%abi.295 =l load [16 + S3]
	%abi.290 =l add %abi.295, %abi.291
	%abi.292 =w add %abi.291, 8
	storew %abi.292, [0 + S3]
@cased.1
	%abi.289 =l phi @cased.3 %abi.296, @cased.2 %abi.290
	%int =w load [%abi.289]
	R4 =w copy %int
	%isel.307 =l addr S1
	R5 =l copy %isel.307
	R1 =w copy 0
	call $printf, 1021
	%r.264 =w copy R1
	jmp @loop
@end
	%isel.308 =l addr S2
	R5 =l copy %isel.308
	call $puts, 0011
	%r.265 =w copy R1
	ret0
}

**** Function qbecall6 ****
> After instruction selection:
function $qbecall6() {
@start
	%fmt =l load S-16
	%argd7 =d copy R24
	%argd6 =d copy R23
	%argd5 =d copy R22
	%argd4 =d copy R21
	%argd3 =d copy R20
	%argd2 =d copy R19
	%argd1 =d copy R18
	%argd0 =d copy R17
	%argw5 =w copy R7
	%argw4 =w copy R6
	%argw3 =w copy R2
	%argw2 =w copy R3
	%argw1 =w copy R4
	%argw0 =w copy R5
	storew 48, [S0]
	storew 176, [4 + S0]
	%abi.312 =l add R15, 72
	storel %abi.312, [8 + S0]
	%abi.310 =l add R15, -176
	storel %abi.310, [16 + S0]
	%isel.314 =l addr S0
	R4 =l copy %isel.314
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	ret0
}

**** Function qbeprint7 ****
> After instruction selection:
function $qbeprint7() {
@start
	%fmt =l load S-10
	%vw.324 =w copy R7
	%vw.323 =w copy R6
	%vw.322 =w copy R2
	%vw.321 =w copy R3
	%vw.320 =w copy R4
	%vw.319 =w copy R5
	storew 2122789, [S1]
	storew 2123557, [S0]
	storew 0, [S2]
	%fmt1 =l add %fmt, 1
	storew 48, [S3]
	storew 48, [4 + S3]
	%abi.355 =l add R15, 48
	storel %abi.355, [8 + S3]
	%abi.353 =l add R15, -176
	storel %abi.353, [16 + S3]
@loop
	%p =l phi @start %fmt1, @casef.1 %p1, @cased.1 %p1
	%c.318 =w loadsb [%p]
	xcmpw 0, %c.318
	jfine @loop1, @end
@loop1
	xcmpw 103, %c.318
	%isg =w flagieq
	%p1 =l add %p, 3
	xcmpw 0, %isg
	jfine @casef, @cased
@casef
	%abi.330 =l loadsw [4 + S3]
	xcmpw 176, %abi.330
	jfiult @casef.2, @casef.3
@casef.3
	%abi.335 =l load [8 + S3]
	%abi.337 =l add %abi.335, 8
	storel %abi.337, [8 + S3]
	jmp @casef.1
@casef.2
	%abi.334 =l load [16 + S3]
	%abi.329 =l add %abi.334, %abi.330
	%abi.331 =w add %abi.330, 16
	storew %abi.331, [4 + S3]
@casef.1
	%abi.328 =l phi @casef.3 %abi.335, @casef.2 %abi.329
	%dbl =d load [%abi.328]
	R17 =d copy %dbl
	%isel.357 =l addr S0
	R5 =l copy %isel.357
	R1 =w copy 1
	call $printf, 1111
	%r.315 =w copy R1
	jmp @loop
@cased
	%abi.342 =l loadsw [0 + S3]
	xcmpw 48, %abi.342
	jfiult @cased.2, @cased.3
@cased.3
	%abi.347 =l load [8 + S3]
	%abi.349 =l add %abi.347, 8
	storel %abi.349, [8 + S3]
	jmp @cased.1
@cased.2
	%abi.346 =l load [16 + S3]
	%abi.341 =l add %abi.346, %abi.342
	%abi.343 =w add %abi.342, 8
	storew %abi.343, [0 + S3]
@cased.1
	%abi.340 =l phi @cased.3 %abi.347, @cased.2 %abi.341
	%int =w load [%abi.340]
	R4 =w copy %int
	%isel.358 =l addr S1
	R5 =l copy %isel.358
	R1 =w copy 0
	call $printf, 1021
	%r.316 =w copy R1
	jmp @loop
@end
	%isel.359 =l addr S2
	R5 =l copy %isel.359
	call $puts, 0011
	%r.317 =w copy R1
	ret0
}

**** Function qbecall7 ****
> After instruction selection:
function $qbecall7() {
@start
	%fmt =l load S-10
	%argw5 =w copy R7
	%argw4 =w copy R6
	%argw3 =w copy R2
	%argw2 =w copy R3
	%argw1 =w copy R4
	%argw0 =w copy R5
	storew 48, [S0]
	storew 48, [4 + S0]
	%abi.363 =l add R15, 48
	storel %abi.363, [8 + S0]
	%abi.361 =l add R15, -176
	storel %abi.361, [16 + S0]
	%isel.365 =l addr S0
	R4 =l copy %isel.365
	R5 =l copy %fmt
	call $print, 0021
	%r =w copy R1
	ret0
}

