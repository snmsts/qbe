**** Function qbeprint0 ****
> After instruction selection:
function $qbeprint0() {
@start
	%fmt =l copy R1
	%isel.21 =l addr S1
	%isel.20 =w copy 2122789
	storew %isel.20, %isel.21
	%isel.19 =l addr S0
	%isel.18 =w copy 2123557
	storew %isel.18, %isel.19
	%isel.17 =l addr S2
	%isel.16 =w copy 0
	storew %isel.16, %isel.17
	%isel.15 =l copy 1
	%fmt1 =l add %fmt, %isel.15
	%abi.11 =l addr S-1
	%isel.14 =l copy 0
	%abi.12 =l add %abi.11, %isel.14
	%isel.13 =l addr S3
	storel %abi.12, %isel.13
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.4 =w loadsb %p
	acmpw %c.4, 0
	jfine @loop1, @end
@loop1
	%isel.22 =l copy 3
	%p1 =l add %p, %isel.22
	acmpw %c.4, 103
	jfieq @casef, @cased
@casef
	%isel.29 =l addr S3
	%abi.7 =l load %isel.29
	%dbl =d load %abi.7
	%isel.28 =l copy 8
	%abi.6 =l add %abi.7, %isel.28
	%isel.27 =l addr S3
	storel %abi.6, %isel.27
	%isel.26 =l copy 16
	R32 =l sub R32, %isel.26
	%isel.25 =l copy 0
	%abi.5 =l add R32, %isel.25
	stored %dbl, %abi.5
	%isel.24 =l addr S0
	R1 =l copy %isel.24
	call $printf, 0021
	%r.1 =w copy R1
	%isel.23 =l copy 16
	R32 =l add R32, %isel.23
	jmp @loop
@cased
	%isel.36 =l addr S3
	%abi.10 =l load %isel.36
	%int =w load %abi.10
	%isel.35 =l copy 8
	%abi.9 =l add %abi.10, %isel.35
	%isel.34 =l addr S3
	storel %abi.9, %isel.34
	%isel.33 =l copy 16
	R32 =l sub R32, %isel.33
	%isel.32 =l copy 0
	%abi.8 =l add R32, %isel.32
	storew %int, %abi.8
	%isel.31 =l addr S1
	R1 =l copy %isel.31
	call $printf, 0021
	%r.2 =w copy R1
	%isel.30 =l copy 16
	R32 =l add R32, %isel.30
	jmp @loop
@end
	%isel.37 =l addr S2
	R1 =l copy %isel.37
	call $puts, 0021
	%r.3 =w copy R1
	ret0
}

**** Function qbecall0 ****
> After instruction selection:
function $qbecall0() {
@start
	%fmt =l copy R1
	%abi.38 =l addr S-1
	%isel.42 =l copy 0
	%abi.39 =l add %abi.38, %isel.42
	%isel.41 =l addr S0
	storel %abi.39, %isel.41
	%isel.40 =l addr S0
	R2 =l copy %isel.40
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	ret0
}

**** Function qbeprint1 ****
> After instruction selection:
function $qbeprint1() {
@start
	%fmt =l copy R2
	%vw.47 =w copy R1
	%isel.64 =l addr S1
	%isel.63 =w copy 2122789
	storew %isel.63, %isel.64
	%isel.62 =l addr S0
	%isel.61 =w copy 2123557
	storew %isel.61, %isel.62
	%isel.60 =l addr S2
	%isel.59 =w copy 0
	storew %isel.59, %isel.60
	%isel.58 =l copy 1
	%fmt1 =l add %fmt, %isel.58
	%abi.54 =l addr S-1
	%isel.57 =l copy 0
	%abi.55 =l add %abi.54, %isel.57
	%isel.56 =l addr S3
	storel %abi.55, %isel.56
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.46 =w loadsb %p
	acmpw %c.46, 0
	jfine @loop1, @end
@loop1
	%isel.65 =l copy 3
	%p1 =l add %p, %isel.65
	acmpw %c.46, 103
	jfieq @casef, @cased
@casef
	%isel.72 =l addr S3
	%abi.50 =l load %isel.72
	%dbl =d load %abi.50
	%isel.71 =l copy 8
	%abi.49 =l add %abi.50, %isel.71
	%isel.70 =l addr S3
	storel %abi.49, %isel.70
	%isel.69 =l copy 16
	R32 =l sub R32, %isel.69
	%isel.68 =l copy 0
	%abi.48 =l add R32, %isel.68
	stored %dbl, %abi.48
	%isel.67 =l addr S0
	R1 =l copy %isel.67
	call $printf, 0021
	%r.43 =w copy R1
	%isel.66 =l copy 16
	R32 =l add R32, %isel.66
	jmp @loop
@cased
	%isel.79 =l addr S3
	%abi.53 =l load %isel.79
	%int =w load %abi.53
	%isel.78 =l copy 8
	%abi.52 =l add %abi.53, %isel.78
	%isel.77 =l addr S3
	storel %abi.52, %isel.77
	%isel.76 =l copy 16
	R32 =l sub R32, %isel.76
	%isel.75 =l copy 0
	%abi.51 =l add R32, %isel.75
	storew %int, %abi.51
	%isel.74 =l addr S1
	R1 =l copy %isel.74
	call $printf, 0021
	%r.44 =w copy R1
	%isel.73 =l copy 16
	R32 =l add R32, %isel.73
	jmp @loop
@end
	%isel.80 =l addr S2
	R1 =l copy %isel.80
	call $puts, 0021
	%r.45 =w copy R1
	ret0
}

**** Function qbecall1 ****
> After instruction selection:
function $qbecall1() {
@start
	%fmt =l copy R2
	%argw0 =w copy R1
	%abi.81 =l addr S-1
	%isel.85 =l copy 0
	%abi.82 =l add %abi.81, %isel.85
	%isel.84 =l addr S0
	storel %abi.82, %isel.84
	%isel.83 =l addr S0
	R2 =l copy %isel.83
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	ret0
}

**** Function qbeprint2 ****
> After instruction selection:
function $qbeprint2() {
@start
	%fmt =l copy R1
	%argd0 =d copy R33
	%isel.106 =l addr S1
	%isel.105 =w copy 2122789
	storew %isel.105, %isel.106
	%isel.104 =l addr S0
	%isel.103 =w copy 2123557
	storew %isel.103, %isel.104
	%isel.102 =l addr S2
	%isel.101 =w copy 0
	storew %isel.101, %isel.102
	%isel.100 =l copy 1
	%fmt1 =l add %fmt, %isel.100
	%abi.96 =l addr S-1
	%isel.99 =l copy 0
	%abi.97 =l add %abi.96, %isel.99
	%isel.98 =l addr S3
	storel %abi.97, %isel.98
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.89 =w loadsb %p
	acmpw %c.89, 0
	jfine @loop1, @end
@loop1
	%isel.107 =l copy 3
	%p1 =l add %p, %isel.107
	acmpw %c.89, 103
	jfieq @casef, @cased
@casef
	%isel.114 =l addr S3
	%abi.92 =l load %isel.114
	%dbl =d load %abi.92
	%isel.113 =l copy 8
	%abi.91 =l add %abi.92, %isel.113
	%isel.112 =l addr S3
	storel %abi.91, %isel.112
	%isel.111 =l copy 16
	R32 =l sub R32, %isel.111
	%isel.110 =l copy 0
	%abi.90 =l add R32, %isel.110
	stored %dbl, %abi.90
	%isel.109 =l addr S0
	R1 =l copy %isel.109
	call $printf, 0021
	%r.86 =w copy R1
	%isel.108 =l copy 16
	R32 =l add R32, %isel.108
	jmp @loop
@cased
	%isel.121 =l addr S3
	%abi.95 =l load %isel.121
	%int =w load %abi.95
	%isel.120 =l copy 8
	%abi.94 =l add %abi.95, %isel.120
	%isel.119 =l addr S3
	storel %abi.94, %isel.119
	%isel.118 =l copy 16
	R32 =l sub R32, %isel.118
	%isel.117 =l copy 0
	%abi.93 =l add R32, %isel.117
	storew %int, %abi.93
	%isel.116 =l addr S1
	R1 =l copy %isel.116
	call $printf, 0021
	%r.87 =w copy R1
	%isel.115 =l copy 16
	R32 =l add R32, %isel.115
	jmp @loop
@end
	%isel.122 =l addr S2
	R1 =l copy %isel.122
	call $puts, 0021
	%r.88 =w copy R1
	ret0
}

**** Function qbecall2 ****
> After instruction selection:
function $qbecall2() {
@start
	%fmt =l copy R1
	%argd0 =d copy R33
	%abi.123 =l addr S-1
	%isel.127 =l copy 0
	%abi.124 =l add %abi.123, %isel.127
	%isel.126 =l addr S0
	storel %abi.124, %isel.126
	%isel.125 =l addr S0
	R2 =l copy %isel.125
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	ret0
}

**** Function qbeprint3 ****
> After instruction selection:
function $qbeprint3() {
@start
	%fmt =l copy R5
	%vw.135 =w copy R4
	%vw.134 =w copy R3
	%vw.133 =w copy R2
	%vw.132 =w copy R1
	%isel.152 =l addr S1
	%isel.151 =w copy 2122789
	storew %isel.151, %isel.152
	%isel.150 =l addr S0
	%isel.149 =w copy 2123557
	storew %isel.149, %isel.150
	%isel.148 =l addr S2
	%isel.147 =w copy 0
	storew %isel.147, %isel.148
	%isel.146 =l copy 1
	%fmt1 =l add %fmt, %isel.146
	%abi.142 =l addr S-1
	%isel.145 =l copy 0
	%abi.143 =l add %abi.142, %isel.145
	%isel.144 =l addr S3
	storel %abi.143, %isel.144
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.131 =w loadsb %p
	acmpw %c.131, 0
	jfine @loop1, @end
@loop1
	%isel.153 =l copy 3
	%p1 =l add %p, %isel.153
	acmpw %c.131, 103
	jfieq @casef, @cased
@casef
	%isel.160 =l addr S3
	%abi.138 =l load %isel.160
	%dbl =d load %abi.138
	%isel.159 =l copy 8
	%abi.137 =l add %abi.138, %isel.159
	%isel.158 =l addr S3
	storel %abi.137, %isel.158
	%isel.157 =l copy 16
	R32 =l sub R32, %isel.157
	%isel.156 =l copy 0
	%abi.136 =l add R32, %isel.156
	stored %dbl, %abi.136
	%isel.155 =l addr S0
	R1 =l copy %isel.155
	call $printf, 0021
	%r.128 =w copy R1
	%isel.154 =l copy 16
	R32 =l add R32, %isel.154
	jmp @loop
@cased
	%isel.167 =l addr S3
	%abi.141 =l load %isel.167
	%int =w load %abi.141
	%isel.166 =l copy 8
	%abi.140 =l add %abi.141, %isel.166
	%isel.165 =l addr S3
	storel %abi.140, %isel.165
	%isel.164 =l copy 16
	R32 =l sub R32, %isel.164
	%isel.163 =l copy 0
	%abi.139 =l add R32, %isel.163
	storew %int, %abi.139
	%isel.162 =l addr S1
	R1 =l copy %isel.162
	call $printf, 0021
	%r.129 =w copy R1
	%isel.161 =l copy 16
	R32 =l add R32, %isel.161
	jmp @loop
@end
	%isel.168 =l addr S2
	R1 =l copy %isel.168
	call $puts, 0021
	%r.130 =w copy R1
	ret0
}

**** Function qbecall3 ****
> After instruction selection:
function $qbecall3() {
@start
	%fmt =l copy R5
	%argw3 =w copy R4
	%argw2 =w copy R3
	%argw1 =w copy R2
	%argw0 =w copy R1
	%abi.169 =l addr S-1
	%isel.173 =l copy 0
	%abi.170 =l add %abi.169, %isel.173
	%isel.172 =l addr S0
	storel %abi.170, %isel.172
	%isel.171 =l addr S0
	R2 =l copy %isel.171
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	ret0
}

**** Function qbeprint4 ****
> After instruction selection:
function $qbeprint4() {
@start
	%fmt =l copy R1
	%argd5 =d copy R38
	%argd4 =d copy R37
	%argd3 =d copy R36
	%argd2 =d copy R35
	%argd1 =d copy R34
	%argd0 =d copy R33
	%isel.194 =l addr S1
	%isel.193 =w copy 2122789
	storew %isel.193, %isel.194
	%isel.192 =l addr S0
	%isel.191 =w copy 2123557
	storew %isel.191, %isel.192
	%isel.190 =l addr S2
	%isel.189 =w copy 0
	storew %isel.189, %isel.190
	%isel.188 =l copy 1
	%fmt1 =l add %fmt, %isel.188
	%abi.184 =l addr S-1
	%isel.187 =l copy 0
	%abi.185 =l add %abi.184, %isel.187
	%isel.186 =l addr S3
	storel %abi.185, %isel.186
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.177 =w loadsb %p
	acmpw %c.177, 0
	jfine @loop1, @end
@loop1
	%isel.195 =l copy 3
	%p1 =l add %p, %isel.195
	acmpw %c.177, 103
	jfieq @casef, @cased
@casef
	%isel.202 =l addr S3
	%abi.180 =l load %isel.202
	%dbl =d load %abi.180
	%isel.201 =l copy 8
	%abi.179 =l add %abi.180, %isel.201
	%isel.200 =l addr S3
	storel %abi.179, %isel.200
	%isel.199 =l copy 16
	R32 =l sub R32, %isel.199
	%isel.198 =l copy 0
	%abi.178 =l add R32, %isel.198
	stored %dbl, %abi.178
	%isel.197 =l addr S0
	R1 =l copy %isel.197
	call $printf, 0021
	%r.174 =w copy R1
	%isel.196 =l copy 16
	R32 =l add R32, %isel.196
	jmp @loop
@cased
	%isel.209 =l addr S3
	%abi.183 =l load %isel.209
	%int =w load %abi.183
	%isel.208 =l copy 8
	%abi.182 =l add %abi.183, %isel.208
	%isel.207 =l addr S3
	storel %abi.182, %isel.207
	%isel.206 =l copy 16
	R32 =l sub R32, %isel.206
	%isel.205 =l copy 0
	%abi.181 =l add R32, %isel.205
	storew %int, %abi.181
	%isel.204 =l addr S1
	R1 =l copy %isel.204
	call $printf, 0021
	%r.175 =w copy R1
	%isel.203 =l copy 16
	R32 =l add R32, %isel.203
	jmp @loop
@end
	%isel.210 =l addr S2
	R1 =l copy %isel.210
	call $puts, 0021
	%r.176 =w copy R1
	ret0
}

**** Function qbecall4 ****
> After instruction selection:
function $qbecall4() {
@start
	%fmt =l copy R1
	%argd5 =d copy R38
	%argd4 =d copy R37
	%argd3 =d copy R36
	%argd2 =d copy R35
	%argd1 =d copy R34
	%argd0 =d copy R33
	%abi.211 =l addr S-1
	%isel.215 =l copy 0
	%abi.212 =l add %abi.211, %isel.215
	%isel.214 =l addr S0
	storel %abi.212, %isel.214
	%isel.213 =l addr S0
	R2 =l copy %isel.213
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	ret0
}

**** Function qbeprint5 ****
> After instruction selection:
function $qbeprint5() {
@start
	%fmt =l copy R6
	%argd6 =d copy R39
	%argd5 =d copy R38
	%argd4 =d copy R37
	%argd3 =d copy R36
	%argd2 =d copy R35
	%argd1 =d copy R34
	%argd0 =d copy R33
	%vw.224 =w copy R5
	%vw.223 =w copy R4
	%vw.222 =w copy R3
	%vw.221 =w copy R2
	%vw.220 =w copy R1
	%isel.241 =l addr S1
	%isel.240 =w copy 2122789
	storew %isel.240, %isel.241
	%isel.239 =l addr S0
	%isel.238 =w copy 2123557
	storew %isel.238, %isel.239
	%isel.237 =l addr S2
	%isel.236 =w copy 0
	storew %isel.236, %isel.237
	%isel.235 =l copy 1
	%fmt1 =l add %fmt, %isel.235
	%abi.231 =l addr S-1
	%isel.234 =l copy 0
	%abi.232 =l add %abi.231, %isel.234
	%isel.233 =l addr S3
	storel %abi.232, %isel.233
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.219 =w loadsb %p
	acmpw %c.219, 0
	jfine @loop1, @end
@loop1
	%isel.242 =l copy 3
	%p1 =l add %p, %isel.242
	acmpw %c.219, 103
	jfieq @casef, @cased
@casef
	%isel.249 =l addr S3
	%abi.227 =l load %isel.249
	%dbl =d load %abi.227
	%isel.248 =l copy 8
	%abi.226 =l add %abi.227, %isel.248
	%isel.247 =l addr S3
	storel %abi.226, %isel.247
	%isel.246 =l copy 16
	R32 =l sub R32, %isel.246
	%isel.245 =l copy 0
	%abi.225 =l add R32, %isel.245
	stored %dbl, %abi.225
	%isel.244 =l addr S0
	R1 =l copy %isel.244
	call $printf, 0021
	%r.216 =w copy R1
	%isel.243 =l copy 16
	R32 =l add R32, %isel.243
	jmp @loop
@cased
	%isel.256 =l addr S3
	%abi.230 =l load %isel.256
	%int =w load %abi.230
	%isel.255 =l copy 8
	%abi.229 =l add %abi.230, %isel.255
	%isel.254 =l addr S3
	storel %abi.229, %isel.254
	%isel.253 =l copy 16
	R32 =l sub R32, %isel.253
	%isel.252 =l copy 0
	%abi.228 =l add R32, %isel.252
	storew %int, %abi.228
	%isel.251 =l addr S1
	R1 =l copy %isel.251
	call $printf, 0021
	%r.217 =w copy R1
	%isel.250 =l copy 16
	R32 =l add R32, %isel.250
	jmp @loop
@end
	%isel.257 =l addr S2
	R1 =l copy %isel.257
	call $puts, 0021
	%r.218 =w copy R1
	ret0
}

**** Function qbecall5 ****
> After instruction selection:
function $qbecall5() {
@start
	%fmt =l copy R6
	%argd6 =d copy R39
	%argd5 =d copy R38
	%argd4 =d copy R37
	%argd3 =d copy R36
	%argd2 =d copy R35
	%argd1 =d copy R34
	%argd0 =d copy R33
	%argw4 =w copy R5
	%argw3 =w copy R4
	%argw2 =w copy R3
	%argw1 =w copy R2
	%argw0 =w copy R1
	%abi.258 =l addr S-1
	%isel.262 =l copy 0
	%abi.259 =l add %abi.258, %isel.262
	%isel.261 =l addr S0
	storel %abi.259, %isel.261
	%isel.260 =l addr S0
	R2 =l copy %isel.260
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	ret0
}

**** Function qbeprint6 ****
> After instruction selection:
function $qbeprint6() {
@start
	%fmt =l load S-26
	%argd9 =d load S-18
	%argd8 =d load S-10
	%argd7 =d copy R40
	%argd6 =d copy R39
	%argd5 =d copy R38
	%argd4 =d copy R37
	%argd3 =d copy R36
	%argd2 =d copy R35
	%argd1 =d copy R34
	%argd0 =d copy R33
	%vw.276 =w load S-6
	%vw.275 =w load S-2
	%vw.274 =w copy R8
	%vw.273 =w copy R7
	%vw.272 =w copy R6
	%vw.271 =w copy R5
	%vw.270 =w copy R4
	%vw.269 =w copy R3
	%vw.268 =w copy R2
	%vw.267 =w copy R1
	%isel.293 =l addr S1
	%isel.292 =w copy 2122789
	storew %isel.292, %isel.293
	%isel.291 =l addr S0
	%isel.290 =w copy 2123557
	storew %isel.290, %isel.291
	%isel.289 =l addr S2
	%isel.288 =w copy 0
	storew %isel.288, %isel.289
	%isel.287 =l copy 1
	%fmt1 =l add %fmt, %isel.287
	%abi.283 =l addr S-1
	%isel.286 =l copy 32
	%abi.284 =l add %abi.283, %isel.286
	%isel.285 =l addr S3
	storel %abi.284, %isel.285
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.266 =w loadsb %p
	acmpw %c.266, 0
	jfine @loop1, @end
@loop1
	%isel.294 =l copy 3
	%p1 =l add %p, %isel.294
	acmpw %c.266, 103
	jfieq @casef, @cased
@casef
	%isel.301 =l addr S3
	%abi.279 =l load %isel.301
	%dbl =d load %abi.279
	%isel.300 =l copy 8
	%abi.278 =l add %abi.279, %isel.300
	%isel.299 =l addr S3
	storel %abi.278, %isel.299
	%isel.298 =l copy 16
	R32 =l sub R32, %isel.298
	%isel.297 =l copy 0
	%abi.277 =l add R32, %isel.297
	stored %dbl, %abi.277
	%isel.296 =l addr S0
	R1 =l copy %isel.296
	call $printf, 0021
	%r.263 =w copy R1
	%isel.295 =l copy 16
	R32 =l add R32, %isel.295
	jmp @loop
@cased
	%isel.308 =l addr S3
	%abi.282 =l load %isel.308
	%int =w load %abi.282
	%isel.307 =l copy 8
	%abi.281 =l add %abi.282, %isel.307
	%isel.306 =l addr S3
	storel %abi.281, %isel.306
	%isel.305 =l copy 16
	R32 =l sub R32, %isel.305
	%isel.304 =l copy 0
	%abi.280 =l add R32, %isel.304
	storew %int, %abi.280
	%isel.303 =l addr S1
	R1 =l copy %isel.303
	call $printf, 0021
	%r.264 =w copy R1
	%isel.302 =l copy 16
	R32 =l add R32, %isel.302
	jmp @loop
@end
	%isel.309 =l addr S2
	R1 =l copy %isel.309
	call $puts, 0021
	%r.265 =w copy R1
	ret0
}

**** Function qbecall6 ****
> After instruction selection:
function $qbecall6() {
@start
	%fmt =l load S-26
	%argd9 =d load S-18
	%argd8 =d load S-10
	%argd7 =d copy R40
	%argd6 =d copy R39
	%argd5 =d copy R38
	%argd4 =d copy R37
	%argd3 =d copy R36
	%argd2 =d copy R35
	%argd1 =d copy R34
	%argd0 =d copy R33
	%argw9 =w load S-6
	%argw8 =w load S-2
	%argw7 =w copy R8
	%argw6 =w copy R7
	%argw5 =w copy R6
	%argw4 =w copy R5
	%argw3 =w copy R4
	%argw2 =w copy R3
	%argw1 =w copy R2
	%argw0 =w copy R1
	%abi.310 =l addr S-1
	%isel.314 =l copy 32
	%abi.311 =l add %abi.310, %isel.314
	%isel.313 =l addr S0
	storel %abi.311, %isel.313
	%isel.312 =l addr S0
	R2 =l copy %isel.312
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	ret0
}

**** Function qbeprint7 ****
> After instruction selection:
function $qbeprint7() {
@start
	%fmt =l load S-10
	%vw.327 =w load S-2
	%vw.326 =w copy R8
	%vw.325 =w copy R7
	%vw.324 =w copy R6
	%vw.323 =w copy R5
	%vw.322 =w copy R4
	%vw.321 =w copy R3
	%vw.320 =w copy R2
	%vw.319 =w copy R1
	%isel.344 =l addr S1
	%isel.343 =w copy 2122789
	storew %isel.343, %isel.344
	%isel.342 =l addr S0
	%isel.341 =w copy 2123557
	storew %isel.341, %isel.342
	%isel.340 =l addr S2
	%isel.339 =w copy 0
	storew %isel.339, %isel.340
	%isel.338 =l copy 1
	%fmt1 =l add %fmt, %isel.338
	%abi.334 =l addr S-1
	%isel.337 =l copy 16
	%abi.335 =l add %abi.334, %isel.337
	%isel.336 =l addr S3
	storel %abi.335, %isel.336
@loop
	%p =l phi @start %fmt1, @casef %p1, @cased %p1
	%c.318 =w loadsb %p
	acmpw %c.318, 0
	jfine @loop1, @end
@loop1
	%isel.345 =l copy 3
	%p1 =l add %p, %isel.345
	acmpw %c.318, 103
	jfieq @casef, @cased
@casef
	%isel.352 =l addr S3
	%abi.330 =l load %isel.352
	%dbl =d load %abi.330
	%isel.351 =l copy 8
	%abi.329 =l add %abi.330, %isel.351
	%isel.350 =l addr S3
	storel %abi.329, %isel.350
	%isel.349 =l copy 16
	R32 =l sub R32, %isel.349
	%isel.348 =l copy 0
	%abi.328 =l add R32, %isel.348
	stored %dbl, %abi.328
	%isel.347 =l addr S0
	R1 =l copy %isel.347
	call $printf, 0021
	%r.315 =w copy R1
	%isel.346 =l copy 16
	R32 =l add R32, %isel.346
	jmp @loop
@cased
	%isel.359 =l addr S3
	%abi.333 =l load %isel.359
	%int =w load %abi.333
	%isel.358 =l copy 8
	%abi.332 =l add %abi.333, %isel.358
	%isel.357 =l addr S3
	storel %abi.332, %isel.357
	%isel.356 =l copy 16
	R32 =l sub R32, %isel.356
	%isel.355 =l copy 0
	%abi.331 =l add R32, %isel.355
	storew %int, %abi.331
	%isel.354 =l addr S1
	R1 =l copy %isel.354
	call $printf, 0021
	%r.316 =w copy R1
	%isel.353 =l copy 16
	R32 =l add R32, %isel.353
	jmp @loop
@end
	%isel.360 =l addr S2
	R1 =l copy %isel.360
	call $puts, 0021
	%r.317 =w copy R1
	ret0
}

**** Function qbecall7 ****
> After instruction selection:
function $qbecall7() {
@start
	%fmt =l load S-10
	%argw8 =w load S-2
	%argw7 =w copy R8
	%argw6 =w copy R7
	%argw5 =w copy R6
	%argw4 =w copy R5
	%argw3 =w copy R4
	%argw2 =w copy R3
	%argw1 =w copy R2
	%argw0 =w copy R1
	%abi.361 =l addr S-1
	%isel.365 =l copy 16
	%abi.362 =l add %abi.361, %isel.365
	%isel.364 =l addr S0
	storel %abi.362, %isel.364
	%isel.363 =l addr S0
	R2 =l copy %isel.363
	R1 =l copy %fmt
	call $print, 0041
	%r =w copy R1
	ret0
}

