**** Function chacha20_rounds_qbe ****
> After instruction selection:
function $chacha20_rounds_qbe() {
@start
	%in.17 =l copy R4
	%out.98 =l copy R5
	%t0.99 =w loadsw [%in.17]
	%t1.100 =w loadsw [4 + %in.17]
	%t2.101 =w loadsw [8 + %in.17]
	%t3.102 =w loadsw [12 + %in.17]
	%t4.103 =w loadsw [16 + %in.17]
	%t5.104 =w loadsw [20 + %in.17]
	%t6.105 =w loadsw [24 + %in.17]
	%t7.106 =w loadsw [28 + %in.17]
	%t8.107 =w loadsw [32 + %in.17]
	%t9.108 =w loadsw [36 + %in.17]
	%t10.109 =w loadsw [40 + %in.17]
	%t11.110 =w loadsw [44 + %in.17]
	%t12.111 =w loadsw [48 + %in.17]
	%t13.112 =w loadsw [52 + %in.17]
	%t14.113 =w loadsw [56 + %in.17]
	%t15.114 =w loadsw [60 + %in.17]
@loop
	%counter.116 =w phi @start 10, @loop %counter.229
	%t15.117 =w phi @start %t15.114, @loop %t15.189
	%t14.118 =w phi @start %t14.113, @loop %t14.225
	%t13.119 =w phi @start %t13.112, @loop %t13.213
	%t12.120 =w phi @start %t12.111, @loop %t12.201
	%t11.121 =w phi @start %t11.110, @loop %t11.202
	%t10.122 =w phi @start %t10.109, @loop %t10.190
	%t9.123 =w phi @start %t9.108, @loop %t9.226
	%t8.124 =w phi @start %t8.107, @loop %t8.214
	%t7.125 =w phi @start %t7.106, @loop %t7.216
	%t6.126 =w phi @start %t6.105, @loop %t6.204
	%t5.127 =w phi @start %t5.104, @loop %t5.192
	%t4.128 =w phi @start %t4.103, @loop %t4.228
	%t3.129 =w phi @start %t3.102, @loop %t3.223
	%t2.130 =w phi @start %t2.101, @loop %t2.211
	%t1.131 =w phi @start %t1.100, @loop %t1.199
	%t0.132 =w phi @start %t0.99, @loop %t0.187
	%t0.133 =w add %t4.128, %t0.132
	%t12.134 =w xor %t12.120, %t0.133
	%rotl32_a.34 =w shl %t12.134, 16
	%rotl32_b.66 =w shr %t12.134, 16
	%t12.135 =w xor %rotl32_a.34, %rotl32_b.66
	%t8.136 =w add %t8.124, %t12.135
	%t4.137 =w xor %t4.128, %t8.136
	%rotl32_a.35 =w shl %t4.137, 12
	%rotl32_b.67 =w shr %t4.137, 20
	%t4.138 =w xor %rotl32_a.35, %rotl32_b.67
	%t0.139 =w add %t0.133, %t4.138
	%t12.140 =w xor %t12.135, %t0.139
	%rotl32_a.36 =w shl %t12.140, 8
	%rotl32_b.68 =w shr %t12.140, 24
	%t12.141 =w xor %rotl32_a.36, %rotl32_b.68
	%t8.142 =w add %t8.136, %t12.141
	%t4.143 =w xor %t4.138, %t8.142
	%rotl32_a.37 =w shl %t4.143, 7
	%rotl32_b.69 =w shr %t4.143, 25
	%t4.144 =w xor %rotl32_a.37, %rotl32_b.69
	%t1.145 =w add %t5.127, %t1.131
	%t13.146 =w xor %t13.119, %t1.145
	%rotl32_a.38 =w shl %t13.146, 16
	%rotl32_b.70 =w shr %t13.146, 16
	%t13.147 =w xor %rotl32_a.38, %rotl32_b.70
	%t9.148 =w add %t9.123, %t13.147
	%t5.149 =w xor %t5.127, %t9.148
	%rotl32_a.39 =w shl %t5.149, 12
	%rotl32_b.71 =w shr %t5.149, 20
	%t5.150 =w xor %rotl32_a.39, %rotl32_b.71
	%t1.151 =w add %t1.145, %t5.150
	%t13.152 =w xor %t13.147, %t1.151
	%rotl32_a.40 =w shl %t13.152, 8
	%rotl32_b.72 =w shr %t13.152, 24
	%t13.153 =w xor %rotl32_a.40, %rotl32_b.72
	%t9.154 =w add %t9.148, %t13.153
	%t5.155 =w xor %t5.150, %t9.154
	%rotl32_a.41 =w shl %t5.155, 7
	%rotl32_b.73 =w shr %t5.155, 25
	%t5.156 =w xor %rotl32_a.41, %rotl32_b.73
	%t2.157 =w add %t6.126, %t2.130
	%t14.158 =w xor %t14.118, %t2.157
	%rotl32_a.42 =w shl %t14.158, 16
	%rotl32_b.74 =w shr %t14.158, 16
	%t14.159 =w xor %rotl32_a.42, %rotl32_b.74
	%t10.160 =w add %t10.122, %t14.159
	%t6.161 =w xor %t6.126, %t10.160
	%rotl32_a.43 =w shl %t6.161, 12
	%rotl32_b.75 =w shr %t6.161, 20
	%t6.162 =w xor %rotl32_a.43, %rotl32_b.75
	%t2.163 =w add %t2.157, %t6.162
	%t14.164 =w xor %t14.159, %t2.163
	%rotl32_a.44 =w shl %t14.164, 8
	%rotl32_b.76 =w shr %t14.164, 24
	%t14.165 =w xor %rotl32_a.44, %rotl32_b.76
	%t10.166 =w add %t10.160, %t14.165
	%t6.167 =w xor %t6.162, %t10.166
	%rotl32_a.45 =w shl %t6.167, 7
	%rotl32_b.77 =w shr %t6.167, 25
	%t6.168 =w xor %rotl32_a.45, %rotl32_b.77
	%t3.169 =w add %t7.125, %t3.129
	%t15.170 =w xor %t15.117, %t3.169
	%rotl32_a.46 =w shl %t15.170, 16
	%rotl32_b.78 =w shr %t15.170, 16
	%t15.171 =w xor %rotl32_a.46, %rotl32_b.78
	%t11.172 =w add %t11.121, %t15.171
	%t7.173 =w xor %t7.125, %t11.172
	%rotl32_a.47 =w shl %t7.173, 12
	%rotl32_b.79 =w shr %t7.173, 20
	%t7.174 =w xor %rotl32_a.47, %rotl32_b.79
	%t3.175 =w add %t3.169, %t7.174
	%t15.176 =w xor %t15.171, %t3.175
	%rotl32_a.48 =w shl %t15.176, 8
	%rotl32_b.80 =w shr %t15.176, 24
	%t15.177 =w xor %rotl32_a.48, %rotl32_b.80
	%t11.178 =w add %t11.172, %t15.177
	%t7.179 =w xor %t7.174, %t11.178
	%rotl32_a.49 =w shl %t7.179, 7
	%rotl32_b.81 =w shr %t7.179, 25
	%t7.180 =w xor %rotl32_a.49, %rotl32_b.81
	%t0.181 =w add %t0.139, %t5.156
	%t15.182 =w xor %t15.177, %t0.181
	%rotl32_a.50 =w shl %t15.182, 16
	%rotl32_b.82 =w shr %t15.182, 16
	%t15.183 =w xor %rotl32_a.50, %rotl32_b.82
	%t10.184 =w add %t10.166, %t15.183
	%t5.185 =w xor %t5.156, %t10.184
	%rotl32_a.51 =w shl %t5.185, 12
	%rotl32_b.83 =w shr %t5.185, 20
	%t5.186 =w xor %rotl32_a.51, %rotl32_b.83
	%t0.187 =w add %t0.181, %t5.186
	%t15.188 =w xor %t15.183, %t0.187
	%rotl32_a.52 =w shl %t15.188, 8
	%rotl32_b.84 =w shr %t15.188, 24
	%t15.189 =w xor %rotl32_a.52, %rotl32_b.84
	%t10.190 =w add %t10.184, %t15.189
	%t5.191 =w xor %t5.186, %t10.190
	%rotl32_a.53 =w shl %t5.191, 7
	%rotl32_b.85 =w shr %t5.191, 25
	%t5.192 =w xor %rotl32_a.53, %rotl32_b.85
	%t1.193 =w add %t1.151, %t6.168
	%t12.194 =w xor %t12.141, %t1.193
	%rotl32_a.54 =w shl %t12.194, 16
	%rotl32_b.86 =w shr %t12.194, 16
	%t12.195 =w xor %rotl32_a.54, %rotl32_b.86
	%t11.196 =w add %t11.178, %t12.195
	%t6.197 =w xor %t6.168, %t11.196
	%rotl32_a.55 =w shl %t6.197, 12
	%rotl32_b.87 =w shr %t6.197, 20
	%t6.198 =w xor %rotl32_a.55, %rotl32_b.87
	%t1.199 =w add %t1.193, %t6.198
	%t12.200 =w xor %t12.195, %t1.199
	%rotl32_a.56 =w shl %t12.200, 8
	%rotl32_b.88 =w shr %t12.200, 24
	%t12.201 =w xor %rotl32_a.56, %rotl32_b.88
	%t11.202 =w add %t11.196, %t12.201
	%t6.203 =w xor %t6.198, %t11.202
	%rotl32_a.57 =w shl %t6.203, 7
	%rotl32_b.89 =w shr %t6.203, 25
	%t6.204 =w xor %rotl32_a.57, %rotl32_b.89
	%t2.205 =w add %t2.163, %t7.180
	%t13.206 =w xor %t13.153, %t2.205
	%rotl32_a.58 =w shl %t13.206, 16
	%rotl32_b.90 =w shr %t13.206, 16
	%t13.207 =w xor %rotl32_a.58, %rotl32_b.90
	%t8.208 =w add %t8.142, %t13.207
	%t7.209 =w xor %t7.180, %t8.208
	%rotl32_a.59 =w shl %t7.209, 12
	%rotl32_b.91 =w shr %t7.209, 20
	%t7.210 =w xor %rotl32_a.59, %rotl32_b.91
	%t2.211 =w add %t2.205, %t7.210
	%t13.212 =w xor %t13.207, %t2.211
	%rotl32_a.60 =w shl %t13.212, 8
	%rotl32_b.92 =w shr %t13.212, 24
	%t13.213 =w xor %rotl32_a.60, %rotl32_b.92
	%t8.214 =w add %t8.208, %t13.213
	%t7.215 =w xor %t7.210, %t8.214
	%rotl32_a.61 =w shl %t7.215, 7
	%rotl32_b.93 =w shr %t7.215, 25
	%t7.216 =w xor %rotl32_a.61, %rotl32_b.93
	%t3.217 =w add %t4.144, %t3.175
	%t14.218 =w xor %t14.165, %t3.217
	%rotl32_a.62 =w shl %t14.218, 16
	%rotl32_b.94 =w shr %t14.218, 16
	%t14.219 =w xor %rotl32_a.62, %rotl32_b.94
	%t9.220 =w add %t9.154, %t14.219
	%t4.221 =w xor %t4.144, %t9.220
	%rotl32_a.63 =w shl %t4.221, 12
	%rotl32_b.95 =w shr %t4.221, 20
	%t4.222 =w xor %rotl32_a.63, %rotl32_b.95
	%t3.223 =w add %t3.217, %t4.222
	%t14.224 =w xor %t14.219, %t3.223
	%rotl32_a.64 =w shl %t14.224, 8
	%rotl32_b.96 =w shr %t14.224, 24
	%t14.225 =w xor %rotl32_a.64, %rotl32_b.96
	%t9.226 =w add %t9.220, %t14.225
	%t4.227 =w xor %t4.222, %t9.226
	%rotl32_a.65 =w shl %t4.227, 7
	%rotl32_b.97 =w shr %t4.227, 25
	%t4.228 =w xor %rotl32_a.65, %rotl32_b.97
	%counter.229 =w sub %counter.116, 10
	jfine @loop, @done
@done
	storew %t0.187, [%out.98]
	storew %t1.199, [4 + %out.98]
	storew %t2.211, [8 + %out.98]
	storew %t3.223, [12 + %out.98]
	storew %t4.228, [16 + %out.98]
	storew %t5.192, [20 + %out.98]
	storew %t6.204, [24 + %out.98]
	storew %t7.216, [28 + %out.98]
	storew %t8.214, [32 + %out.98]
	storew %t9.226, [36 + %out.98]
	storew %t10.190, [40 + %out.98]
	storew %t11.202, [44 + %out.98]
	storew %t12.201, [48 + %out.98]
	storew %t13.213, [52 + %out.98]
	storew %t14.225, [56 + %out.98]
	storew %t15.189, [60 + %out.98]
	ret0
}

