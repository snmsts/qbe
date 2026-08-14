**** Function qfn0 ****
> After instruction selection:
function $qfn0() {
@start
	%abi.1 =w copy R7
	%p7 =s copy R49
	%p6 =s copy R48
	%p5 =s copy R47
	%p4 =s copy R46
	%p3 =s copy R45
	%p2 =s copy R44
	%p1 =s copy R43
	%p0 =s copy R42
	%p8 =s cast %abi.1
	%isel.4 =w copy 0
	R8 =w copy %isel.4
	%isel.3 =l copy $ctoqbestr
	R7 =l copy %isel.3
	call $printf, 0021
	%r0 =w copy R7
	R42 =s copy %p8
	call $ps, 0101
	copy R7
	%isel.2 =l copy $emptystr
	R7 =l copy %isel.2
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn1 ****
> After instruction selection:
function $qfn1() {
@start
	%abi.7 =s copy R43
	%abi.5 =w copy R8
	%p1 =s copy R42
	%p0 =w copy R7
	%isel.14 =l addr S0
	%abi.8 =l add %isel.14, 4
	stores %abi.7, %abi.8
	%isel.13 =l addr S0
	%abi.6 =l add %isel.13, 0
	storew %abi.5, %abi.6
	%isel.12 =w copy 1
	R8 =w copy %isel.12
	%isel.11 =l copy $ctoqbestr
	R7 =l copy %isel.11
	call $printf, 0021
	%r0 =w copy R7
	R7 =w copy %p0
	call $pw, 0011
	copy R7
	R42 =s copy %p1
	call $ps, 0101
	copy R7
	%isel.10 =l addr S0
	R7 =l copy %isel.10
	call $pfi1, 0011
	copy R7
	%isel.9 =l copy $emptystr
	R7 =l copy %isel.9
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn2 ****
> After instruction selection:
function $qfn2() {
@start
	%p2 =s copy R43
	%abi.17 =w copy R8
	%abi.15 =s copy R42
	%p0 =w copy R7
	%isel.24 =l addr S0
	%abi.18 =l add %isel.24, 4
	storew %abi.17, %abi.18
	%isel.23 =l addr S0
	%abi.16 =l add %isel.23, 0
	stores %abi.15, %abi.16
	%isel.22 =w copy 2
	R8 =w copy %isel.22
	%isel.21 =l copy $ctoqbestr
	R7 =l copy %isel.21
	call $printf, 0021
	%r0 =w copy R7
	R7 =w copy %p0
	call $pw, 0011
	copy R7
	%isel.20 =l addr S0
	R7 =l copy %isel.20
	call $pfi2, 0011
	copy R7
	R42 =s copy %p2
	call $ps, 0101
	copy R7
	%isel.19 =l copy $emptystr
	R7 =l copy %isel.19
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn3 ****
> After instruction selection:
function $qfn3() {
@start
	%abi.25 =l copy R8
	%p1 =s copy R42
	%p0 =w copy R7
	%isel.31 =l addr S0
	%abi.26 =l add %isel.31, 0
	storel %abi.25, %abi.26
	%isel.30 =w copy 3
	R8 =w copy %isel.30
	%isel.29 =l copy $ctoqbestr
	R7 =l copy %isel.29
	call $printf, 0021
	%r0 =w copy R7
	R7 =w copy %p0
	call $pw, 0011
	copy R7
	R42 =s copy %p1
	call $ps, 0101
	copy R7
	%isel.28 =l addr S0
	R7 =l copy %isel.28
	call $pfi3, 0011
	copy R7
	%isel.27 =l copy $emptystr
	R7 =l copy %isel.27
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn4 ****
> After instruction selection:
function $qfn4() {
@start
	%abi.34 =s copy R43
	%abi.32 =s copy R42
	%isel.41 =l addr S0
	%abi.35 =l add %isel.41, 4
	stores %abi.34, %abi.35
	%isel.40 =l addr S0
	%abi.33 =l add %isel.40, 0
	stores %abi.32, %abi.33
	%isel.39 =w copy 4
	R8 =w copy %isel.39
	%isel.38 =l copy $ctoqbestr
	R7 =l copy %isel.38
	call $printf, 0021
	%r0 =w copy R7
	%isel.37 =l addr S0
	R7 =l copy %isel.37
	call $pss, 0011
	copy R7
	%isel.36 =l copy $emptystr
	R7 =l copy %isel.36
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn5 ****
> After instruction selection:
function $qfn5() {
@start
	%p9 =l copy R8
	%p8 =s copy R49
	%abi.42 =l copy R7
	%p6 =d copy R48
	%p5 =d copy R47
	%p4 =d copy R46
	%p3 =d copy R45
	%p2 =d copy R44
	%p1 =d copy R43
	%p0 =d copy R42
	%isel.48 =l addr S0
	%abi.43 =l add %isel.48, 0
	storel %abi.42, %abi.43
	%isel.47 =w copy 5
	R8 =w copy %isel.47
	%isel.46 =l copy $ctoqbestr
	R7 =l copy %isel.46
	call $printf, 0021
	%r0 =w copy R7
	%isel.45 =l addr S0
	R7 =l copy %isel.45
	call $pss, 0011
	copy R7
	R42 =s copy %p8
	call $ps, 0101
	copy R7
	R7 =l copy %p9
	call $pl, 0011
	copy R7
	%isel.44 =l copy $emptystr
	R7 =l copy %isel.44
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn6 ****
> After instruction selection:
function $qfn6() {
@start
	%abi.51 =l copy R8
	%abi.49 =l copy R7
	%isel.58 =l addr S0
	%abi.52 =l add %isel.58, 8
	storel %abi.51, %abi.52
	%isel.57 =l addr S0
	%abi.50 =l add %isel.57, 0
	storel %abi.49, %abi.50
	%isel.56 =w copy 6
	R8 =w copy %isel.56
	%isel.55 =l copy $ctoqbestr
	R7 =l copy %isel.55
	call $printf, 0021
	%r0 =w copy R7
	%isel.54 =l addr S0
	R7 =l copy %isel.54
	call $plb, 0011
	copy R7
	%isel.53 =l copy $emptystr
	R7 =l copy %isel.53
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn7 ****
> After instruction selection:
function $qfn7() {
@start
	%abi.61 =l load S-2
	%abi.59 =l copy R14
	%p6 =w copy R13
	%p5 =w copy R12
	%p4 =w copy R11
	%p3 =w copy R10
	%p2 =w copy R9
	%p1 =w copy R8
	%p0 =w copy R7
	%isel.68 =l addr S0
	%abi.62 =l add %isel.68, 8
	storel %abi.61, %abi.62
	%isel.67 =l addr S0
	%abi.60 =l add %isel.67, 0
	storel %abi.59, %abi.60
	%isel.66 =w copy 7
	R8 =w copy %isel.66
	%isel.65 =l copy $ctoqbestr
	R7 =l copy %isel.65
	call $printf, 0021
	%r0 =w copy R7
	%isel.64 =l addr S0
	R7 =l copy %isel.64
	call $plb, 0011
	copy R7
	%isel.63 =l copy $emptystr
	R7 =l copy %isel.63
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn8 ****
> After instruction selection:
function $qfn8() {
@start
	%p7 =w copy R14
	%p6 =w copy R13
	%p5 =w copy R12
	%p4 =w copy R11
	%p3 =w copy R10
	%p2 =w copy R9
	%p1 =w copy R8
	%p0 =w copy R7
	%isel.72 =w copy 8
	R8 =w copy %isel.72
	%isel.71 =l copy $ctoqbestr
	R7 =l copy %isel.71
	call $printf, 0021
	%r0 =w copy R7
	%isel.70 =l addr S-2
	R7 =l copy %isel.70
	call $plb, 0011
	copy R7
	%isel.69 =l copy $emptystr
	R7 =l copy %isel.69
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn9 ****
> After instruction selection:
function $qfn9() {
@start
	%p0 =l copy R7
	%isel.75 =w copy 9
	R8 =w copy %isel.75
	%isel.74 =l copy $ctoqbestr
	R7 =l copy %isel.74
	call $printf, 0021
	%r0 =w copy R7
	R7 =l copy %p0
	call $pbig, 0011
	copy R7
	%isel.73 =l copy $emptystr
	R7 =l copy %isel.73
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn10 ****
> After instruction selection:
function $qfn10() {
@start
	%p10 =l load S-3
	%p9 =s copy R42
	%p8 =l load S-2
	%p7 =w copy R14
	%p6 =w copy R13
	%p5 =w copy R12
	%p4 =w copy R11
	%p3 =w copy R10
	%p2 =w copy R9
	%p1 =w copy R8
	%p0 =w copy R7
	%isel.78 =w copy 10
	R8 =w copy %isel.78
	%isel.77 =l copy $ctoqbestr
	R7 =l copy %isel.77
	call $printf, 0021
	%r0 =w copy R7
	R7 =l copy %p8
	call $pbig, 0011
	copy R7
	R42 =s copy %p9
	call $ps, 0101
	copy R7
	R7 =l copy %p10
	call $pl, 0011
	copy R7
	%isel.76 =l copy $emptystr
	R7 =l copy %isel.76
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function qfn11 ****
> After instruction selection:
function $qfn11() {
@start
	%p0 =l copy R7
	%isel.81 =w copy 11
	R8 =w copy %isel.81
	%isel.80 =l copy $ctoqbestr
	R7 =l copy %isel.80
	call $printf, 0021
	%r0 =w copy R7
	R7 =l copy %p0
	call $pddd, 0011
	copy R7
	%isel.79 =l copy $emptystr
	R7 =l copy %isel.79
	call $puts, 0011
	%r1 =w copy R7
	ret0
}

**** Function main ****
> After instruction selection:
function $main() {
@start
	%isel.226 =s load $".Lfp2"
	%abi.109 =w cast %isel.226
	R7 =w copy %abi.109
	%isel.225 =s load $".Lfp1"
	R49 =s copy %isel.225
	%isel.224 =s load $".Lfp1"
	R48 =s copy %isel.224
	%isel.223 =s load $".Lfp1"
	R47 =s copy %isel.223
	%isel.222 =s load $".Lfp1"
	R46 =s copy %isel.222
	%isel.221 =s load $".Lfp1"
	R45 =s copy %isel.221
	%isel.220 =s load $".Lfp1"
	R44 =s copy %isel.220
	%isel.219 =s load $".Lfp1"
	R43 =s copy %isel.219
	%isel.218 =s load $".Lfp1"
	R42 =s copy %isel.218
	call $cfn0, 0811
	copy R7
	%isel.217 =l copy $fi1
	%abi.108 =l add %isel.217, 4
	R43 =s load %abi.108
	%isel.216 =l copy $fi1
	%abi.107 =l add %isel.216, 0
	R8 =w load %abi.107
	%isel.215 =s load $".Lfp3"
	R42 =s copy %isel.215
	%isel.214 =w copy 1
	R7 =w copy %isel.214
	call $cfn1, 0221
	copy R7
	%isel.213 =s load $".Lfp4"
	R43 =s copy %isel.213
	%isel.212 =l copy $fi2
	%abi.106 =l add %isel.212, 4
	R8 =w load %abi.106
	%isel.211 =l copy $fi2
	%abi.105 =l add %isel.211, 0
	R42 =s load %abi.105
	%isel.210 =w copy 1
	R7 =w copy %isel.210
	call $cfn2, 0221
	copy R7
	%isel.209 =l copy $fi3
	%abi.104 =l add %isel.209, 0
	R8 =l load %abi.104
	%isel.208 =s load $".Lfp3"
	R42 =s copy %isel.208
	%isel.207 =w copy 1
	R7 =w copy %isel.207
	call $cfn3, 0121
	copy R7
	%isel.206 =l copy $ss
	%abi.103 =l add %isel.206, 4
	R43 =s load %abi.103
	%isel.205 =l copy $ss
	%abi.102 =l add %isel.205, 0
	R42 =s load %abi.102
	call $cfn4, 0201
	copy R7
	%isel.204 =l copy 10
	R8 =l copy %isel.204
	%isel.203 =s load $".Lfp2"
	R49 =s copy %isel.203
	%isel.202 =l copy $ss
	%abi.101 =l add %isel.202, 0
	R7 =l load %abi.101
	%isel.201 =d load $".Lfp1"
	R48 =d copy %isel.201
	%isel.200 =d load $".Lfp1"
	R47 =d copy %isel.200
	%isel.199 =d load $".Lfp1"
	R46 =d copy %isel.199
	%isel.198 =d load $".Lfp1"
	R45 =d copy %isel.198
	%isel.197 =d load $".Lfp1"
	R44 =d copy %isel.197
	%isel.196 =d load $".Lfp1"
	R43 =d copy %isel.196
	%isel.195 =d load $".Lfp1"
	R42 =d copy %isel.195
	call $cfn5, 0821
	copy R7
	%isel.194 =l copy $lb
	%abi.100 =l add %isel.194, 8
	R8 =l load %abi.100
	%isel.193 =l copy $lb
	%abi.99 =l add %isel.193, 0
	R7 =l load %abi.99
	call $cfn6, 0021
	copy R7
	%isel.192 =l copy 16
	%abi.95 =l salloc %isel.192
	%isel.191 =l copy $lb
	%abi.98 =l add %isel.191, 8
	%abi.97 =l load %abi.98
	%abi.96 =l add %abi.95, 0
	storel %abi.97, %abi.96
	%isel.190 =l copy $lb
	%abi.94 =l add %isel.190, 0
	R14 =l load %abi.94
	%isel.189 =w copy 0
	R13 =w copy %isel.189
	%isel.188 =w copy 0
	R12 =w copy %isel.188
	%isel.187 =w copy 0
	R11 =w copy %isel.187
	%isel.186 =w copy 0
	R10 =w copy %isel.186
	%isel.185 =w copy 0
	R9 =w copy %isel.185
	%isel.184 =w copy 0
	R8 =w copy %isel.184
	%isel.183 =w copy 0
	R7 =w copy %isel.183
	call $cfn7, 0081
	copy R7
	%isel.182 =l copy -16
	salloc %isel.182
	%isel.181 =l copy 16
	%abi.88 =l salloc %isel.181
	%isel.180 =l copy $lb
	%abi.93 =l add %isel.180, 8
	%abi.92 =l load %abi.93
	%abi.91 =l add %abi.88, 8
	storel %abi.92, %abi.91
	%abi.90 =l load $lb
	%abi.89 =l add %abi.88, 0
	storel %abi.90, %abi.89
	%isel.179 =w copy 0
	R14 =w copy %isel.179
	%isel.178 =w copy 0
	R13 =w copy %isel.178
	%isel.177 =w copy 0
	R12 =w copy %isel.177
	%isel.176 =w copy 0
	R11 =w copy %isel.176
	%isel.175 =w copy 0
	R10 =w copy %isel.175
	%isel.174 =w copy 0
	R9 =w copy %isel.174
	%isel.173 =w copy 0
	R8 =w copy %isel.173
	%isel.172 =w copy 0
	R7 =w copy %isel.172
	call $cfn8, 0081
	copy R7
	%isel.171 =l copy -16
	salloc %isel.171
	%isel.170 =l copy $big
	%blt.136 =l add %isel.170, 0
	%blt.134 =w loadub %blt.136
	%isel.169 =l addr S6
	%blt.135 =l add %isel.169, 0
	storeb %blt.134, %blt.135
	%isel.168 =l copy $big
	%blt.133 =l add %isel.168, 1
	%blt.131 =l load %blt.133
	%isel.167 =l addr S6
	%blt.132 =l add %isel.167, 1
	storel %blt.131, %blt.132
	%isel.166 =l copy $big
	%blt.130 =l add %isel.166, 9
	%blt.128 =l load %blt.130
	%isel.165 =l addr S6
	%blt.129 =l add %isel.165, 9
	storel %blt.128, %blt.129
	%isel.164 =l addr S6
	R7 =l copy %isel.164
	call $cfn9, 0011
	copy R7
	%isel.163 =l copy 16
	%abi.84 =l salloc %isel.163
	%abi.86 =l add %abi.84, 8
	%isel.162 =l copy 11
	storel %isel.162, %abi.86
	%abi.85 =l add %abi.84, 0
	%isel.161 =l addr S0
	storel %isel.161, %abi.85
	%isel.160 =l copy $big
	%blt.127 =l add %isel.160, 0
	%blt.125 =w loadub %blt.127
	%isel.159 =l addr S0
	%blt.126 =l add %isel.159, 0
	storeb %blt.125, %blt.126
	%isel.158 =l copy $big
	%blt.124 =l add %isel.158, 1
	%blt.122 =l load %blt.124
	%isel.157 =l addr S0
	%blt.123 =l add %isel.157, 1
	storel %blt.122, %blt.123
	%isel.156 =l copy $big
	%blt.121 =l add %isel.156, 9
	%blt.119 =l load %blt.121
	%isel.155 =l addr S0
	%blt.120 =l add %isel.155, 9
	storel %blt.119, %blt.120
	%isel.154 =s load $".Lfp0"
	R42 =s copy %isel.154
	%isel.153 =w copy 0
	R14 =w copy %isel.153
	%isel.152 =w copy 0
	R13 =w copy %isel.152
	%isel.151 =w copy 0
	R12 =w copy %isel.151
	%isel.150 =w copy 0
	R11 =w copy %isel.150
	%isel.149 =w copy 0
	R10 =w copy %isel.149
	%isel.148 =w copy 0
	R9 =w copy %isel.148
	%isel.147 =w copy 0
	R8 =w copy %isel.147
	%isel.146 =w copy 0
	R7 =w copy %isel.146
	call $cfn10, 0181
	copy R7
	%isel.145 =l copy -16
	salloc %isel.145
	%isel.144 =l copy $ddd
	%blt.118 =l add %isel.144, 0
	%blt.116 =l load %blt.118
	%isel.143 =l addr S12
	%blt.117 =l add %isel.143, 0
	storel %blt.116, %blt.117
	%isel.142 =l copy $ddd
	%blt.115 =l add %isel.142, 8
	%blt.113 =l load %blt.115
	%isel.141 =l addr S12
	%blt.114 =l add %isel.141, 8
	storel %blt.113, %blt.114
	%isel.140 =l copy $ddd
	%blt.112 =l add %isel.140, 16
	%blt.110 =l load %blt.112
	%isel.139 =l addr S12
	%blt.111 =l add %isel.139, 16
	storel %blt.110, %blt.111
	%isel.138 =l addr S12
	R7 =l copy %isel.138
	call $cfn11, 0011
	copy R7
	%isel.137 =w copy 0
	R7 =w copy %isel.137
	ret0 0001
}

