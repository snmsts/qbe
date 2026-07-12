**** Function qfn0 ****
> After instruction selection:
function $qfn0() {
@start
	%p8 =s load S-2
	%p7 =s copy R40
	%p6 =s copy R39
	%p5 =s copy R38
	%p4 =s copy R37
	%p3 =s copy R36
	%p2 =s copy R35
	%p1 =s copy R34
	%p0 =s copy R33
	%isel.7 =l copy 16
	R32 =l sub R32, %isel.7
	%isel.6 =l copy 0
	%abi.1 =l add R32, %isel.6
	%isel.5 =w copy 0
	storew %isel.5, %abi.1
	%isel.4 =l copy $ctoqbestr
	R1 =l copy %isel.4
	call $printf, 0021
	%r0 =w copy R1
	%isel.3 =l copy 16
	R32 =l add R32, %isel.3
	R33 =s copy %p8
	call $ps, 0201
	copy R1
	%isel.2 =l copy $emptystr
	R1 =l copy %isel.2
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn1 ****
> After instruction selection:
function $qfn1() {
@start
	%abi.8 =l copy R2
	%p1 =s copy R33
	%p0 =w copy R1
	%isel.19 =l copy 0
	%isel.18 =l addr S0
	%abi.9 =l add %isel.18, %isel.19
	storel %abi.8, %abi.9
	%isel.17 =l copy 16
	R32 =l sub R32, %isel.17
	%isel.16 =l copy 0
	%abi.10 =l add R32, %isel.16
	%isel.15 =w copy 1
	storew %isel.15, %abi.10
	%isel.14 =l copy $ctoqbestr
	R1 =l copy %isel.14
	call $printf, 0021
	%r0 =w copy R1
	%isel.13 =l copy 16
	R32 =l add R32, %isel.13
	R1 =w copy %p0
	call $pw, 0021
	copy R1
	R33 =s copy %p1
	call $ps, 0201
	copy R1
	%isel.12 =l addr S0
	R1 =l copy %isel.12
	call $pfi1, 0021
	copy R1
	%isel.11 =l copy $emptystr
	R1 =l copy %isel.11
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn2 ****
> After instruction selection:
function $qfn2() {
@start
	%p2 =s copy R33
	%abi.20 =l copy R2
	%p0 =w copy R1
	%isel.31 =l copy 0
	%isel.30 =l addr S0
	%abi.21 =l add %isel.30, %isel.31
	storel %abi.20, %abi.21
	%isel.29 =l copy 16
	R32 =l sub R32, %isel.29
	%isel.28 =l copy 0
	%abi.22 =l add R32, %isel.28
	%isel.27 =w copy 2
	storew %isel.27, %abi.22
	%isel.26 =l copy $ctoqbestr
	R1 =l copy %isel.26
	call $printf, 0021
	%r0 =w copy R1
	%isel.25 =l copy 16
	R32 =l add R32, %isel.25
	R1 =w copy %p0
	call $pw, 0021
	copy R1
	%isel.24 =l addr S0
	R1 =l copy %isel.24
	call $pfi2, 0021
	copy R1
	R33 =s copy %p2
	call $ps, 0201
	copy R1
	%isel.23 =l copy $emptystr
	R1 =l copy %isel.23
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn3 ****
> After instruction selection:
function $qfn3() {
@start
	%abi.32 =l copy R2
	%p1 =s copy R33
	%p0 =w copy R1
	%isel.43 =l copy 0
	%isel.42 =l addr S0
	%abi.33 =l add %isel.42, %isel.43
	storel %abi.32, %abi.33
	%isel.41 =l copy 16
	R32 =l sub R32, %isel.41
	%isel.40 =l copy 0
	%abi.34 =l add R32, %isel.40
	%isel.39 =w copy 3
	storew %isel.39, %abi.34
	%isel.38 =l copy $ctoqbestr
	R1 =l copy %isel.38
	call $printf, 0021
	%r0 =w copy R1
	%isel.37 =l copy 16
	R32 =l add R32, %isel.37
	R1 =w copy %p0
	call $pw, 0021
	copy R1
	R33 =s copy %p1
	call $ps, 0201
	copy R1
	%isel.36 =l addr S0
	R1 =l copy %isel.36
	call $pfi3, 0021
	copy R1
	%isel.35 =l copy $emptystr
	R1 =l copy %isel.35
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn4 ****
> After instruction selection:
function $qfn4() {
@start
	%abi.46 =s copy R34
	%abi.44 =s copy R33
	%isel.59 =l copy 4
	%isel.58 =l addr S0
	%abi.47 =l add %isel.58, %isel.59
	stores %abi.46, %abi.47
	%isel.57 =l copy 0
	%isel.56 =l addr S0
	%abi.45 =l add %isel.56, %isel.57
	stores %abi.44, %abi.45
	%isel.55 =l copy 16
	R32 =l sub R32, %isel.55
	%isel.54 =l copy 0
	%abi.48 =l add R32, %isel.54
	%isel.53 =w copy 4
	storew %isel.53, %abi.48
	%isel.52 =l copy $ctoqbestr
	R1 =l copy %isel.52
	call $printf, 0021
	%r0 =w copy R1
	%isel.51 =l copy 16
	R32 =l add R32, %isel.51
	%isel.50 =l addr S0
	R1 =l copy %isel.50
	call $pss, 0021
	copy R1
	%isel.49 =l copy $emptystr
	R1 =l copy %isel.49
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn5 ****
> After instruction selection:
function $qfn5() {
@start
	%p9 =l copy R1
	%p8 =s load S-10
	%p6 =d copy R39
	%p5 =d copy R38
	%p4 =d copy R37
	%p3 =d copy R36
	%p2 =d copy R35
	%p1 =d copy R34
	%p0 =d copy R33
	%isel.67 =l copy 16
	R32 =l sub R32, %isel.67
	%isel.66 =l copy 0
	%abi.60 =l add R32, %isel.66
	%isel.65 =w copy 5
	storew %isel.65, %abi.60
	%isel.64 =l copy $ctoqbestr
	R1 =l copy %isel.64
	call $printf, 0021
	%r0 =w copy R1
	%isel.63 =l copy 16
	R32 =l add R32, %isel.63
	%isel.62 =l addr S-2
	R1 =l copy %isel.62
	call $pss, 0021
	copy R1
	R33 =s copy %p8
	call $ps, 0201
	copy R1
	R1 =l copy %p9
	call $pl, 0021
	copy R1
	%isel.61 =l copy $emptystr
	R1 =l copy %isel.61
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn6 ****
> After instruction selection:
function $qfn6() {
@start
	%abi.70 =l copy R2
	%abi.68 =l copy R1
	%isel.83 =l copy 8
	%isel.82 =l addr S0
	%abi.71 =l add %isel.82, %isel.83
	storel %abi.70, %abi.71
	%isel.81 =l copy 0
	%isel.80 =l addr S0
	%abi.69 =l add %isel.80, %isel.81
	storel %abi.68, %abi.69
	%isel.79 =l copy 16
	R32 =l sub R32, %isel.79
	%isel.78 =l copy 0
	%abi.72 =l add R32, %isel.78
	%isel.77 =w copy 6
	storew %isel.77, %abi.72
	%isel.76 =l copy $ctoqbestr
	R1 =l copy %isel.76
	call $printf, 0021
	%r0 =w copy R1
	%isel.75 =l copy 16
	R32 =l add R32, %isel.75
	%isel.74 =l addr S0
	R1 =l copy %isel.74
	call $plb, 0021
	copy R1
	%isel.73 =l copy $emptystr
	R1 =l copy %isel.73
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn7 ****
> After instruction selection:
function $qfn7() {
@start
	%p6 =w copy R7
	%p5 =w copy R6
	%p4 =w copy R5
	%p3 =w copy R4
	%p2 =w copy R3
	%p1 =w copy R2
	%p0 =w copy R1
	%isel.91 =l copy 16
	R32 =l sub R32, %isel.91
	%isel.90 =l copy 0
	%abi.84 =l add R32, %isel.90
	%isel.89 =w copy 7
	storew %isel.89, %abi.84
	%isel.88 =l copy $ctoqbestr
	R1 =l copy %isel.88
	call $printf, 0021
	%r0 =w copy R1
	%isel.87 =l copy 16
	R32 =l add R32, %isel.87
	%isel.86 =l addr S-2
	R1 =l copy %isel.86
	call $plb, 0021
	copy R1
	%isel.85 =l copy $emptystr
	R1 =l copy %isel.85
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn8 ****
> After instruction selection:
function $qfn8() {
@start
	%p7 =w copy R8
	%p6 =w copy R7
	%p5 =w copy R6
	%p4 =w copy R5
	%p3 =w copy R4
	%p2 =w copy R3
	%p1 =w copy R2
	%p0 =w copy R1
	%isel.99 =l copy 16
	R32 =l sub R32, %isel.99
	%isel.98 =l copy 0
	%abi.92 =l add R32, %isel.98
	%isel.97 =w copy 8
	storew %isel.97, %abi.92
	%isel.96 =l copy $ctoqbestr
	R1 =l copy %isel.96
	call $printf, 0021
	%r0 =w copy R1
	%isel.95 =l copy 16
	R32 =l add R32, %isel.95
	%isel.94 =l addr S-2
	R1 =l copy %isel.94
	call $plb, 0021
	copy R1
	%isel.93 =l copy $emptystr
	R1 =l copy %isel.93
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn9 ****
> After instruction selection:
function $qfn9() {
@start
	%p0 =l copy R1
	%isel.106 =l copy 16
	R32 =l sub R32, %isel.106
	%isel.105 =l copy 0
	%abi.100 =l add R32, %isel.105
	%isel.104 =w copy 9
	storew %isel.104, %abi.100
	%isel.103 =l copy $ctoqbestr
	R1 =l copy %isel.103
	call $printf, 0021
	%r0 =w copy R1
	%isel.102 =l copy 16
	R32 =l add R32, %isel.102
	R1 =l copy %p0
	call $pbig, 0021
	copy R1
	%isel.101 =l copy $emptystr
	R1 =l copy %isel.101
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn10 ****
> After instruction selection:
function $qfn10() {
@start
	%p10 =l load S-10
	%p9 =s copy R33
	%p8 =l load S-2
	%p7 =w copy R8
	%p6 =w copy R7
	%p5 =w copy R6
	%p4 =w copy R5
	%p3 =w copy R4
	%p2 =w copy R3
	%p1 =w copy R2
	%p0 =w copy R1
	%isel.113 =l copy 16
	R32 =l sub R32, %isel.113
	%isel.112 =l copy 0
	%abi.107 =l add R32, %isel.112
	%isel.111 =w copy 10
	storew %isel.111, %abi.107
	%isel.110 =l copy $ctoqbestr
	R1 =l copy %isel.110
	call $printf, 0021
	%r0 =w copy R1
	%isel.109 =l copy 16
	R32 =l add R32, %isel.109
	R1 =l copy %p8
	call $pbig, 0021
	copy R1
	R33 =s copy %p9
	call $ps, 0201
	copy R1
	R1 =l copy %p10
	call $pl, 0021
	copy R1
	%isel.108 =l copy $emptystr
	R1 =l copy %isel.108
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function qfn11 ****
> After instruction selection:
function $qfn11() {
@start
	%abi.118 =d copy R35
	%abi.116 =d copy R34
	%abi.114 =d copy R33
	%isel.133 =l copy 16
	%isel.132 =l addr S0
	%abi.119 =l add %isel.132, %isel.133
	stored %abi.118, %abi.119
	%isel.131 =l copy 8
	%isel.130 =l addr S0
	%abi.117 =l add %isel.130, %isel.131
	stored %abi.116, %abi.117
	%isel.129 =l copy 0
	%isel.128 =l addr S0
	%abi.115 =l add %isel.128, %isel.129
	stored %abi.114, %abi.115
	%isel.127 =l copy 16
	R32 =l sub R32, %isel.127
	%isel.126 =l copy 0
	%abi.120 =l add R32, %isel.126
	%isel.125 =w copy 11
	storew %isel.125, %abi.120
	%isel.124 =l copy $ctoqbestr
	R1 =l copy %isel.124
	call $printf, 0021
	%r0 =w copy R1
	%isel.123 =l copy 16
	R32 =l add R32, %isel.123
	%isel.122 =l addr S0
	R1 =l copy %isel.122
	call $pddd, 0021
	copy R1
	%isel.121 =l copy $emptystr
	R1 =l copy %isel.121
	call $puts, 0021
	%r1 =w copy R1
	ret0
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.334 =l copy 16
	R32 =l sub R32, %isel.334
	%isel.333 =l copy 0
	%abi.152 =l add R32, %isel.333
	%isel.332 =l copy $"Lfp2"
	%isel.331 =s load %isel.332
	stores %isel.331, %abi.152
	%isel.330 =l copy $"Lfp1"
	%isel.329 =s load %isel.330
	R40 =s copy %isel.329
	%isel.328 =l copy $"Lfp1"
	%isel.327 =s load %isel.328
	R39 =s copy %isel.327
	%isel.326 =l copy $"Lfp1"
	%isel.325 =s load %isel.326
	R38 =s copy %isel.325
	%isel.324 =l copy $"Lfp1"
	%isel.323 =s load %isel.324
	R37 =s copy %isel.323
	%isel.322 =l copy $"Lfp1"
	%isel.321 =s load %isel.322
	R36 =s copy %isel.321
	%isel.320 =l copy $"Lfp1"
	%isel.319 =s load %isel.320
	R35 =s copy %isel.319
	%isel.318 =l copy $"Lfp1"
	%isel.317 =s load %isel.318
	R34 =s copy %isel.317
	%isel.316 =l copy $"Lfp1"
	%isel.315 =s load %isel.316
	R33 =s copy %isel.315
	call $cfn0, 1001
	copy R1
	%isel.314 =l copy 16
	R32 =l add R32, %isel.314
	%isel.313 =l copy 0
	%isel.312 =l copy $fi1
	%abi.151 =l add %isel.312, %isel.313
	R2 =l load %abi.151
	%isel.311 =l copy $"Lfp3"
	%isel.310 =s load %isel.311
	R33 =s copy %isel.310
	%isel.309 =w copy 1
	R1 =w copy %isel.309
	call $cfn1, 0241
	copy R1
	%isel.308 =l copy $"Lfp4"
	%isel.307 =s load %isel.308
	R33 =s copy %isel.307
	%isel.306 =l copy 0
	%isel.305 =l copy $fi2
	%abi.150 =l add %isel.305, %isel.306
	R2 =l load %abi.150
	%isel.304 =w copy 1
	R1 =w copy %isel.304
	call $cfn2, 0241
	copy R1
	%isel.303 =l copy 0
	%isel.302 =l copy $fi3
	%abi.149 =l add %isel.302, %isel.303
	R2 =l load %abi.149
	%isel.301 =l copy $"Lfp3"
	%isel.300 =s load %isel.301
	R33 =s copy %isel.300
	%isel.299 =w copy 1
	R1 =w copy %isel.299
	call $cfn3, 0241
	copy R1
	%isel.298 =l copy 4
	%isel.297 =l copy $ss
	%abi.148 =l add %isel.297, %isel.298
	R34 =s load %abi.148
	%isel.296 =l copy 0
	%isel.295 =l copy $ss
	%abi.147 =l add %isel.295, %isel.296
	R33 =s load %abi.147
	call $cfn4, 0401
	copy R1
	%isel.294 =l copy 16
	R32 =l sub R32, %isel.294
	%isel.293 =l copy 8
	%abi.146 =l add R32, %isel.293
	%isel.292 =l copy $"Lfp2"
	%isel.291 =s load %isel.292
	stores %isel.291, %abi.146
	%isel.290 =l copy 0
	%abi.145 =l add R32, %isel.290
	%isel.289 =l copy 0
	%isel.288 =l copy $ss
	%blt.185 =l add %isel.288, %isel.289
	%blt.183 =l load %blt.185
	%isel.287 =l copy 0
	%blt.184 =l add %abi.145, %isel.287
	storel %blt.183, %blt.184
	%isel.286 =l copy 10
	R1 =l copy %isel.286
	%isel.285 =l copy $"Lfp1"
	%isel.284 =d load %isel.285
	R39 =d copy %isel.284
	%isel.283 =l copy $"Lfp1"
	%isel.282 =d load %isel.283
	R38 =d copy %isel.282
	%isel.281 =l copy $"Lfp1"
	%isel.280 =d load %isel.281
	R37 =d copy %isel.280
	%isel.279 =l copy $"Lfp1"
	%isel.278 =d load %isel.279
	R36 =d copy %isel.278
	%isel.277 =l copy $"Lfp1"
	%isel.276 =d load %isel.277
	R35 =d copy %isel.276
	%isel.275 =l copy $"Lfp1"
	%isel.274 =d load %isel.275
	R34 =d copy %isel.274
	%isel.273 =l copy $"Lfp1"
	%isel.272 =d load %isel.273
	R33 =d copy %isel.272
	call $cfn5, 0e21
	copy R1
	%isel.271 =l copy 16
	R32 =l add R32, %isel.271
	%isel.270 =l copy 8
	%isel.269 =l copy $lb
	%abi.144 =l add %isel.269, %isel.270
	R2 =l load %abi.144
	%isel.268 =l copy 0
	%isel.267 =l copy $lb
	%abi.143 =l add %isel.267, %isel.268
	R1 =l load %abi.143
	call $cfn6, 0041
	copy R1
	%isel.266 =l copy 16
	R32 =l sub R32, %isel.266
	%isel.265 =l copy 0
	%abi.142 =l add R32, %isel.265
	%isel.264 =l copy 0
	%isel.263 =l copy $lb
	%blt.182 =l add %isel.263, %isel.264
	%blt.180 =l load %blt.182
	%isel.262 =l copy 0
	%blt.181 =l add %abi.142, %isel.262
	storel %blt.180, %blt.181
	%isel.261 =l copy 8
	%isel.260 =l copy $lb
	%blt.179 =l add %isel.260, %isel.261
	%blt.177 =l load %blt.179
	%isel.259 =l copy 8
	%blt.178 =l add %abi.142, %isel.259
	storel %blt.177, %blt.178
	%isel.258 =w copy 0
	R7 =w copy %isel.258
	%isel.257 =w copy 0
	R6 =w copy %isel.257
	%isel.256 =w copy 0
	R5 =w copy %isel.256
	%isel.255 =w copy 0
	R4 =w copy %isel.255
	%isel.254 =w copy 0
	R3 =w copy %isel.254
	%isel.253 =w copy 0
	R2 =w copy %isel.253
	%isel.252 =w copy 0
	R1 =w copy %isel.252
	call $cfn7, 00e1
	copy R1
	%isel.251 =l copy 16
	R32 =l add R32, %isel.251
	%isel.250 =l copy 16
	R32 =l sub R32, %isel.250
	%isel.249 =l copy 0
	%abi.141 =l add R32, %isel.249
	%isel.248 =l copy 0
	%isel.247 =l copy $lb
	%blt.176 =l add %isel.247, %isel.248
	%blt.174 =l load %blt.176
	%isel.246 =l copy 0
	%blt.175 =l add %abi.141, %isel.246
	storel %blt.174, %blt.175
	%isel.245 =l copy 8
	%isel.244 =l copy $lb
	%blt.173 =l add %isel.244, %isel.245
	%blt.171 =l load %blt.173
	%isel.243 =l copy 8
	%blt.172 =l add %abi.141, %isel.243
	storel %blt.171, %blt.172
	%isel.242 =w copy 0
	R8 =w copy %isel.242
	%isel.241 =w copy 0
	R7 =w copy %isel.241
	%isel.240 =w copy 0
	R6 =w copy %isel.240
	%isel.239 =w copy 0
	R5 =w copy %isel.239
	%isel.238 =w copy 0
	R4 =w copy %isel.238
	%isel.237 =w copy 0
	R3 =w copy %isel.237
	%isel.236 =w copy 0
	R2 =w copy %isel.236
	%isel.235 =w copy 0
	R1 =w copy %isel.235
	call $cfn8, 0101
	copy R1
	%isel.234 =l copy 16
	R32 =l add R32, %isel.234
	%isel.233 =l copy 0
	%isel.232 =l copy $big
	%blt.170 =l add %isel.232, %isel.233
	%blt.168 =w loadub %blt.170
	%isel.231 =l copy 0
	%isel.230 =l addr S5
	%blt.169 =l add %isel.230, %isel.231
	storeb %blt.168, %blt.169
	%isel.229 =l copy 1
	%isel.228 =l copy $big
	%blt.167 =l add %isel.228, %isel.229
	%blt.165 =l load %blt.167
	%isel.227 =l copy 1
	%isel.226 =l addr S5
	%blt.166 =l add %isel.226, %isel.227
	storel %blt.165, %blt.166
	%isel.225 =l copy 9
	%isel.224 =l copy $big
	%blt.164 =l add %isel.224, %isel.225
	%blt.162 =l load %blt.164
	%isel.223 =l copy 9
	%isel.222 =l addr S5
	%blt.163 =l add %isel.222, %isel.223
	storel %blt.162, %blt.163
	%isel.221 =l addr S5
	R1 =l copy %isel.221
	call $cfn9, 0021
	copy R1
	%isel.220 =l copy 0
	%isel.219 =l copy $big
	%blt.161 =l add %isel.219, %isel.220
	%blt.159 =w loadub %blt.161
	%isel.218 =l copy 0
	%isel.217 =l addr S0
	%blt.160 =l add %isel.217, %isel.218
	storeb %blt.159, %blt.160
	%isel.216 =l copy 1
	%isel.215 =l copy $big
	%blt.158 =l add %isel.215, %isel.216
	%blt.156 =l load %blt.158
	%isel.214 =l copy 1
	%isel.213 =l addr S0
	%blt.157 =l add %isel.213, %isel.214
	storel %blt.156, %blt.157
	%isel.212 =l copy 9
	%isel.211 =l copy $big
	%blt.155 =l add %isel.211, %isel.212
	%blt.153 =l load %blt.155
	%isel.210 =l copy 9
	%isel.209 =l addr S0
	%blt.154 =l add %isel.209, %isel.210
	storel %blt.153, %blt.154
	%isel.208 =l copy 16
	R32 =l sub R32, %isel.208
	%isel.207 =l copy 8
	%abi.139 =l add R32, %isel.207
	%isel.206 =l copy 11
	storel %isel.206, %abi.139
	%isel.205 =l copy 0
	%abi.138 =l add R32, %isel.205
	%isel.204 =l addr S0
	storel %isel.204, %abi.138
	%isel.203 =l copy $"Lfp0"
	%isel.202 =s load %isel.203
	R33 =s copy %isel.202
	%isel.201 =w copy 0
	R8 =w copy %isel.201
	%isel.200 =w copy 0
	R7 =w copy %isel.200
	%isel.199 =w copy 0
	R6 =w copy %isel.199
	%isel.198 =w copy 0
	R5 =w copy %isel.198
	%isel.197 =w copy 0
	R4 =w copy %isel.197
	%isel.196 =w copy 0
	R3 =w copy %isel.196
	%isel.195 =w copy 0
	R2 =w copy %isel.195
	%isel.194 =w copy 0
	R1 =w copy %isel.194
	call $cfn10, 0301
	copy R1
	%isel.193 =l copy 16
	R32 =l add R32, %isel.193
	%isel.192 =l copy 16
	%isel.191 =l copy $ddd
	%abi.136 =l add %isel.191, %isel.192
	R35 =d load %abi.136
	%isel.190 =l copy 8
	%isel.189 =l copy $ddd
	%abi.135 =l add %isel.189, %isel.190
	R34 =d load %abi.135
	%isel.188 =l copy 0
	%isel.187 =l copy $ddd
	%abi.134 =l add %isel.187, %isel.188
	R33 =d load %abi.134
	call $cfn11, 0601
	copy R1
	%isel.186 =w copy 0
	R1 =w copy %isel.186
	ret0 0001
}

