**** Function test ****
> After instruction selection:
function $test() {
@start
	%isel.171 =l addr S18
	R9 =l copy %isel.171
	call $t1, 2001
	copy R1
	%isel.170 =l copy 16
	R32 =l sub R32, %isel.170
	%isel.169 =l copy 0
	%abi.52 =l add R32, %isel.169
	%isel.168 =l addr S18
	storel %isel.168, %abi.52
	%isel.167 =l copy $fmt1
	R1 =l copy %isel.167
	call $printf, 0021
	%i1 =w copy R1
	%isel.166 =l copy 16
	R32 =l add R32, %isel.166
	call $t2, 0001
	%abi.50 =l copy R1
	%isel.165 =l copy 0
	%isel.164 =l addr S16
	%abi.51 =l add %isel.164, %isel.165
	storel %abi.50, %abi.51
	%isel.163 =l addr S16
	%w2 =w loadsw %isel.163
	%isel.162 =l copy 16
	R32 =l sub R32, %isel.162
	%isel.161 =l copy 0
	%abi.49 =l add R32, %isel.161
	storew %w2, %abi.49
	%isel.160 =l copy $fmt2
	R1 =l copy %isel.160
	call $printf, 0021
	%i2 =w copy R1
	%isel.159 =l copy 16
	R32 =l add R32, %isel.159
	call $t3, 0001
	%abi.47 =l copy R1
	%isel.158 =l copy 0
	%isel.157 =l addr S14
	%abi.48 =l add %isel.157, %isel.158
	storel %abi.47, %abi.48
	%isel.156 =l addr S14
	%s3 =s load %isel.156
	%isel.155 =l copy 4
	%isel.154 =l addr S14
	%r34 =l add %isel.154, %isel.155
	%w3 =w loadsw %r34
	%p3 =d exts %s3
	%isel.153 =l copy 16
	R32 =l sub R32, %isel.153
	%isel.152 =l copy 8
	%abi.46 =l add R32, %isel.152
	storew %w3, %abi.46
	%isel.151 =l copy 0
	%abi.45 =l add R32, %isel.151
	stored %p3, %abi.45
	%isel.150 =l copy $fmt3
	R1 =l copy %isel.150
	call $printf, 0021
	%i3 =w copy R1
	%isel.149 =l copy 16
	R32 =l add R32, %isel.149
	call $t4, 0002
	%abi.43 =l copy R2
	%abi.41 =l copy R1
	%isel.148 =l copy 8
	%isel.147 =l addr S31
	%abi.44 =l add %isel.147, %isel.148
	storel %abi.43, %abi.44
	%isel.146 =l copy 0
	%isel.145 =l addr S31
	%abi.42 =l add %isel.145, %isel.146
	storel %abi.41, %abi.42
	%isel.144 =l addr S31
	%w4 =w loadsw %isel.144
	%isel.143 =l copy 8
	%isel.142 =l addr S31
	%r48 =l add %isel.142, %isel.143
	%d4 =d load %r48
	%isel.141 =l copy 16
	R32 =l sub R32, %isel.141
	%isel.140 =l copy 8
	%abi.40 =l add R32, %isel.140
	stored %d4, %abi.40
	%isel.139 =l copy 0
	%abi.39 =l add R32, %isel.139
	storew %w4, %abi.39
	%isel.138 =l copy $fmt4
	R1 =l copy %isel.138
	call $printf, 0021
	%i4 =w copy R1
	%isel.137 =l copy 16
	R32 =l add R32, %isel.137
	call $t5, 0002
	%abi.37 =l copy R2
	%abi.35 =l copy R1
	%isel.136 =l copy 8
	%isel.135 =l addr S27
	%abi.38 =l add %isel.135, %isel.136
	storel %abi.37, %abi.38
	%isel.134 =l copy 0
	%isel.133 =l addr S27
	%abi.36 =l add %isel.133, %isel.134
	storel %abi.35, %abi.36
	%isel.132 =l addr S27
	%s5 =s load %isel.132
	%d5 =d exts %s5
	%isel.131 =l copy 8
	%isel.130 =l addr S27
	%r58 =l add %isel.130, %isel.131
	%l5 =l load %r58
	%isel.129 =l copy 16
	R32 =l sub R32, %isel.129
	%isel.128 =l copy 8
	%abi.34 =l add R32, %isel.128
	storel %l5, %abi.34
	%isel.127 =l copy 0
	%abi.33 =l add R32, %isel.127
	stored %d5, %abi.33
	%isel.126 =l copy $fmt5
	R1 =l copy %isel.126
	call $printf, 0021
	%i5 =w copy R1
	%isel.125 =l copy 16
	R32 =l add R32, %isel.125
	call $t6, 0002
	%abi.31 =l copy R2
	%abi.29 =l copy R1
	%isel.124 =l copy 8
	%isel.123 =l addr S10
	%abi.32 =l add %isel.123, %isel.124
	storel %abi.31, %abi.32
	%isel.122 =l copy 0
	%isel.121 =l addr S10
	%abi.30 =l add %isel.121, %isel.122
	storel %abi.29, %abi.30
	%isel.120 =l copy 16
	R32 =l sub R32, %isel.120
	%isel.119 =l copy 0
	%abi.28 =l add R32, %isel.119
	%isel.118 =l addr S10
	storel %isel.118, %abi.28
	%isel.117 =l copy $fmt6
	R1 =l copy %isel.117
	call $printf, 0021
	%i6 =w copy R1
	%isel.116 =l copy 16
	R32 =l add R32, %isel.116
	call $t7, 0002
	%abi.26 =l copy R2
	%abi.24 =l copy R1
	%isel.115 =l copy 8
	%isel.114 =l addr S23
	%abi.27 =l add %isel.114, %isel.115
	storel %abi.26, %abi.27
	%isel.113 =l copy 0
	%isel.112 =l addr S23
	%abi.25 =l add %isel.112, %isel.113
	storel %abi.24, %abi.25
	%isel.111 =l addr S23
	%s7 =s load %isel.111
	%d71 =d exts %s7
	%isel.110 =l copy 8
	%isel.109 =l addr S23
	%r78 =l add %isel.109, %isel.110
	%d72 =d load %r78
	%isel.108 =l copy 16
	R32 =l sub R32, %isel.108
	%isel.107 =l copy 8
	%abi.23 =l add R32, %isel.107
	stored %d72, %abi.23
	%isel.106 =l copy 0
	%abi.22 =l add R32, %isel.106
	stored %d71, %abi.22
	%isel.105 =l copy $fmt7
	R1 =l copy %isel.105
	call $printf, 0021
	%i7 =w copy R1
	%isel.104 =l copy 16
	R32 =l add R32, %isel.104
	call $t8, 0002
	%abi.20 =l copy R2
	%abi.18 =l copy R1
	%isel.103 =l copy 8
	%isel.102 =l addr S6
	%abi.21 =l add %isel.102, %isel.103
	storel %abi.20, %abi.21
	%isel.101 =l copy 0
	%isel.100 =l addr S6
	%abi.19 =l add %isel.100, %isel.101
	storel %abi.18, %abi.19
	%isel.99 =l copy 4
	%isel.98 =l addr S6
	%r84 =l add %isel.98, %isel.99
	%isel.97 =l copy 8
	%isel.96 =l addr S6
	%r88 =l add %isel.96, %isel.97
	%isel.95 =l copy 12
	%isel.94 =l addr S6
	%r812 =l add %isel.94, %isel.95
	%isel.93 =l addr S6
	%w81 =w loadsw %isel.93
	%w82 =w loadsw %r84
	%w83 =w loadsw %r88
	%w84 =w loadsw %r812
	%isel.92 =l copy 32
	R32 =l sub R32, %isel.92
	%isel.91 =l copy 24
	%abi.17 =l add R32, %isel.91
	storew %w84, %abi.17
	%isel.90 =l copy 16
	%abi.16 =l add R32, %isel.90
	storew %w83, %abi.16
	%isel.89 =l copy 8
	%abi.15 =l add R32, %isel.89
	storew %w82, %abi.15
	%isel.88 =l copy 0
	%abi.14 =l add R32, %isel.88
	storew %w81, %abi.14
	%isel.87 =l copy $fmt8
	R1 =l copy %isel.87
	call $printf, 0021
	%i8 =w copy R1
	%isel.86 =l copy 32
	R32 =l add R32, %isel.86
	call $t9, 0001
	%abi.12 =l copy R1
	%isel.85 =l copy 0
	%isel.84 =l addr S4
	%abi.13 =l add %isel.84, %isel.85
	storel %abi.12, %abi.13
	%isel.83 =l copy 4
	%isel.82 =l addr S4
	%r94 =l add %isel.82, %isel.83
	%isel.81 =l addr S4
	%w9 =w loadsw %isel.81
	%s9 =s load %r94
	%d9 =d exts %s9
	%isel.80 =l copy 16
	R32 =l sub R32, %isel.80
	%isel.79 =l copy 8
	%abi.11 =l add R32, %isel.79
	stored %d9, %abi.11
	%isel.78 =l copy 0
	%abi.10 =l add R32, %isel.78
	storew %w9, %abi.10
	%isel.77 =l copy $fmt9
	R1 =l copy %isel.77
	call $printf, 0021
	%i9 =w copy R1
	%isel.76 =l copy 16
	R32 =l add R32, %isel.76
	call $ta, 0001
	%abi.8 =l copy R1
	%isel.75 =l copy 0
	%isel.74 =l addr S2
	%abi.9 =l add %isel.74, %isel.75
	storel %abi.8, %abi.9
	%isel.73 =l copy 4
	%isel.72 =l addr S2
	%ra4 =l add %isel.72, %isel.73
	%isel.71 =l addr S2
	%wa =w loadsb %isel.71
	%sa =s load %ra4
	%da =d exts %sa
	%isel.70 =l copy 16
	R32 =l sub R32, %isel.70
	%isel.69 =l copy 8
	%abi.7 =l add R32, %isel.69
	stored %da, %abi.7
	%isel.68 =l copy 0
	%abi.6 =l add R32, %isel.68
	storew %wa, %abi.6
	%isel.67 =l copy $fmta
	R1 =l copy %isel.67
	call $printf, 0021
	%ia =w copy R1
	%isel.66 =l copy 16
	R32 =l add R32, %isel.66
	call $tb, 0001
	%abi.4 =l copy R1
	%isel.65 =l copy 0
	%isel.64 =l addr S0
	%abi.5 =l add %isel.64, %isel.65
	storel %abi.4, %abi.5
	%isel.63 =l copy 1
	%isel.62 =l addr S0
	%rb1 =l add %isel.62, %isel.63
	%isel.61 =l copy 4
	%isel.60 =l addr S0
	%rb4 =l add %isel.60, %isel.61
	%isel.59 =l addr S0
	%w0b =w loadsb %isel.59
	%w1b =w loadsb %rb1
	%sb =s load %rb4
	%db =d exts %sb
	%isel.58 =l copy 32
	R32 =l sub R32, %isel.58
	%isel.57 =l copy 16
	%abi.3 =l add R32, %isel.57
	stored %db, %abi.3
	%isel.56 =l copy 8
	%abi.2 =l add R32, %isel.56
	storew %w1b, %abi.2
	%isel.55 =l copy 0
	%abi.1 =l add R32, %isel.55
	storew %w0b, %abi.1
	%isel.54 =l copy $fmtb
	R1 =l copy %isel.54
	call $printf, 0021
	%ib =w copy R1
	%isel.53 =l copy 32
	R32 =l add R32, %isel.53
	ret0
}

