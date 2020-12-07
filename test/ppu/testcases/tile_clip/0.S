.define tilemap_loc 0x10000
.define tileset_loc 0x20000

	push entry_point
	popj

scanline_func:
	tile 0 0 size=SIZE_16 pfsize=SIZE_128 \
		tilemap=tilemap_loc tileset=tileset_loc \
		fmt=FORMAT_ARGB1555
	sync
	clip 0 319
	fill r=31
	popj

entry_point:
	clip 0 319
	fill r=31
# Generated code starts here
	clip 0 80
	push ret0
	push scanline_func
	popj
ret0:
	clip 0 81
	push ret1
	push scanline_func
	popj
ret1:
	clip 1 82
	push ret2
	push scanline_func
	popj
ret2:
	clip 1 83
	push ret3
	push scanline_func
	popj
ret3:
	clip 2 84
	push ret4
	push scanline_func
	popj
ret4:
	clip 2 85
	push ret5
	push scanline_func
	popj
ret5:
	clip 3 86
	push ret6
	push scanline_func
	popj
ret6:
	clip 3 87
	push ret7
	push scanline_func
	popj
ret7:
	clip 4 88
	push ret8
	push scanline_func
	popj
ret8:
	clip 4 89
	push ret9
	push scanline_func
	popj
ret9:
	clip 5 90
	push ret10
	push scanline_func
	popj
ret10:
	clip 5 91
	push ret11
	push scanline_func
	popj
ret11:
	clip 6 92
	push ret12
	push scanline_func
	popj
ret12:
	clip 6 93
	push ret13
	push scanline_func
	popj
ret13:
	clip 7 94
	push ret14
	push scanline_func
	popj
ret14:
	clip 7 95
	push ret15
	push scanline_func
	popj
ret15:
	clip 8 96
	push ret16
	push scanline_func
	popj
ret16:
	clip 8 97
	push ret17
	push scanline_func
	popj
ret17:
	clip 9 98
	push ret18
	push scanline_func
	popj
ret18:
	clip 9 99
	push ret19
	push scanline_func
	popj
ret19:
	clip 10 100
	push ret20
	push scanline_func
	popj
ret20:
	clip 10 101
	push ret21
	push scanline_func
	popj
ret21:
	clip 11 102
	push ret22
	push scanline_func
	popj
ret22:
	clip 11 103
	push ret23
	push scanline_func
	popj
ret23:
	clip 12 104
	push ret24
	push scanline_func
	popj
ret24:
	clip 12 105
	push ret25
	push scanline_func
	popj
ret25:
	clip 13 106
	push ret26
	push scanline_func
	popj
ret26:
	clip 13 107
	push ret27
	push scanline_func
	popj
ret27:
	clip 14 108
	push ret28
	push scanline_func
	popj
ret28:
	clip 14 109
	push ret29
	push scanline_func
	popj
ret29:
	clip 15 110
	push ret30
	push scanline_func
	popj
ret30:
	clip 15 111
	push ret31
	push scanline_func
	popj
ret31:
	clip 16 112
	push ret32
	push scanline_func
	popj
ret32:
	clip 16 113
	push ret33
	push scanline_func
	popj
ret33:
	clip 17 114
	push ret34
	push scanline_func
	popj
ret34:
	clip 17 115
	push ret35
	push scanline_func
	popj
ret35:
	clip 18 116
	push ret36
	push scanline_func
	popj
ret36:
	clip 18 117
	push ret37
	push scanline_func
	popj
ret37:
	clip 19 118
	push ret38
	push scanline_func
	popj
ret38:
	clip 19 119
	push ret39
	push scanline_func
	popj
ret39:
	clip 20 120
	push ret40
	push scanline_func
	popj
ret40:
	clip 20 121
	push ret41
	push scanline_func
	popj
ret41:
	clip 21 122
	push ret42
	push scanline_func
	popj
ret42:
	clip 21 123
	push ret43
	push scanline_func
	popj
ret43:
	clip 22 124
	push ret44
	push scanline_func
	popj
ret44:
	clip 22 125
	push ret45
	push scanline_func
	popj
ret45:
	clip 23 126
	push ret46
	push scanline_func
	popj
ret46:
	clip 23 127
	push ret47
	push scanline_func
	popj
ret47:
	clip 24 128
	push ret48
	push scanline_func
	popj
ret48:
	clip 24 129
	push ret49
	push scanline_func
	popj
ret49:
	clip 25 130
	push ret50
	push scanline_func
	popj
ret50:
	clip 25 131
	push ret51
	push scanline_func
	popj
ret51:
	clip 26 132
	push ret52
	push scanline_func
	popj
ret52:
	clip 26 133
	push ret53
	push scanline_func
	popj
ret53:
	clip 27 134
	push ret54
	push scanline_func
	popj
ret54:
	clip 27 135
	push ret55
	push scanline_func
	popj
ret55:
	clip 28 136
	push ret56
	push scanline_func
	popj
ret56:
	clip 28 137
	push ret57
	push scanline_func
	popj
ret57:
	clip 29 138
	push ret58
	push scanline_func
	popj
ret58:
	clip 29 139
	push ret59
	push scanline_func
	popj
ret59:
	clip 30 140
	push ret60
	push scanline_func
	popj
ret60:
	clip 30 141
	push ret61
	push scanline_func
	popj
ret61:
	clip 31 142
	push ret62
	push scanline_func
	popj
ret62:
	clip 31 143
	push ret63
	push scanline_func
	popj
ret63:
	clip 32 144
	push ret64
	push scanline_func
	popj
ret64:
	clip 32 145
	push ret65
	push scanline_func
	popj
ret65:
	clip 33 146
	push ret66
	push scanline_func
	popj
ret66:
	clip 33 147
	push ret67
	push scanline_func
	popj
ret67:
	clip 34 148
	push ret68
	push scanline_func
	popj
ret68:
	clip 34 149
	push ret69
	push scanline_func
	popj
ret69:
	clip 35 150
	push ret70
	push scanline_func
	popj
ret70:
	clip 35 151
	push ret71
	push scanline_func
	popj
ret71:
	clip 36 152
	push ret72
	push scanline_func
	popj
ret72:
	clip 36 153
	push ret73
	push scanline_func
	popj
ret73:
	clip 37 154
	push ret74
	push scanline_func
	popj
ret74:
	clip 37 155
	push ret75
	push scanline_func
	popj
ret75:
	clip 38 156
	push ret76
	push scanline_func
	popj
ret76:
	clip 38 157
	push ret77
	push scanline_func
	popj
ret77:
	clip 39 158
	push ret78
	push scanline_func
	popj
ret78:
	clip 39 159
	push ret79
	push scanline_func
	popj
ret79:
	clip 40 160
	push ret80
	push scanline_func
	popj
ret80:
	clip 40 161
	push ret81
	push scanline_func
	popj
ret81:
	clip 41 162
	push ret82
	push scanline_func
	popj
ret82:
	clip 41 163
	push ret83
	push scanline_func
	popj
ret83:
	clip 42 164
	push ret84
	push scanline_func
	popj
ret84:
	clip 42 165
	push ret85
	push scanline_func
	popj
ret85:
	clip 43 166
	push ret86
	push scanline_func
	popj
ret86:
	clip 43 167
	push ret87
	push scanline_func
	popj
ret87:
	clip 44 168
	push ret88
	push scanline_func
	popj
ret88:
	clip 44 169
	push ret89
	push scanline_func
	popj
ret89:
	clip 45 170
	push ret90
	push scanline_func
	popj
ret90:
	clip 45 171
	push ret91
	push scanline_func
	popj
ret91:
	clip 46 172
	push ret92
	push scanline_func
	popj
ret92:
	clip 46 173
	push ret93
	push scanline_func
	popj
ret93:
	clip 47 174
	push ret94
	push scanline_func
	popj
ret94:
	clip 47 175
	push ret95
	push scanline_func
	popj
ret95:
	clip 48 176
	push ret96
	push scanline_func
	popj
ret96:
	clip 48 177
	push ret97
	push scanline_func
	popj
ret97:
	clip 49 178
	push ret98
	push scanline_func
	popj
ret98:
	clip 49 179
	push ret99
	push scanline_func
	popj
ret99:
	clip 50 180
	push ret100
	push scanline_func
	popj
ret100:
	clip 50 181
	push ret101
	push scanline_func
	popj
ret101:
	clip 51 182
	push ret102
	push scanline_func
	popj
ret102:
	clip 51 183
	push ret103
	push scanline_func
	popj
ret103:
	clip 52 184
	push ret104
	push scanline_func
	popj
ret104:
	clip 52 185
	push ret105
	push scanline_func
	popj
ret105:
	clip 53 186
	push ret106
	push scanline_func
	popj
ret106:
	clip 53 187
	push ret107
	push scanline_func
	popj
ret107:
	clip 54 188
	push ret108
	push scanline_func
	popj
ret108:
	clip 54 189
	push ret109
	push scanline_func
	popj
ret109:
	clip 55 190
	push ret110
	push scanline_func
	popj
ret110:
	clip 55 191
	push ret111
	push scanline_func
	popj
ret111:
	clip 56 192
	push ret112
	push scanline_func
	popj
ret112:
	clip 56 193
	push ret113
	push scanline_func
	popj
ret113:
	clip 57 194
	push ret114
	push scanline_func
	popj
ret114:
	clip 57 195
	push ret115
	push scanline_func
	popj
ret115:
	clip 58 196
	push ret116
	push scanline_func
	popj
ret116:
	clip 58 197
	push ret117
	push scanline_func
	popj
ret117:
	clip 59 198
	push ret118
	push scanline_func
	popj
ret118:
	clip 59 199
	push ret119
	push scanline_func
	popj
ret119:
	clip 60 200
	push ret120
	push scanline_func
	popj
ret120:
	clip 60 201
	push ret121
	push scanline_func
	popj
ret121:
	clip 61 202
	push ret122
	push scanline_func
	popj
ret122:
	clip 61 203
	push ret123
	push scanline_func
	popj
ret123:
	clip 62 204
	push ret124
	push scanline_func
	popj
ret124:
	clip 62 205
	push ret125
	push scanline_func
	popj
ret125:
	clip 63 206
	push ret126
	push scanline_func
	popj
ret126:
	clip 63 207
	push ret127
	push scanline_func
	popj
ret127:
	clip 64 208
	push ret128
	push scanline_func
	popj
ret128:
	clip 64 209
	push ret129
	push scanline_func
	popj
ret129:
	clip 65 210
	push ret130
	push scanline_func
	popj
ret130:
	clip 65 211
	push ret131
	push scanline_func
	popj
ret131:
	clip 66 212
	push ret132
	push scanline_func
	popj
ret132:
	clip 66 213
	push ret133
	push scanline_func
	popj
ret133:
	clip 67 214
	push ret134
	push scanline_func
	popj
ret134:
	clip 67 215
	push ret135
	push scanline_func
	popj
ret135:
	clip 68 216
	push ret136
	push scanline_func
	popj
ret136:
	clip 68 217
	push ret137
	push scanline_func
	popj
ret137:
	clip 69 218
	push ret138
	push scanline_func
	popj
ret138:
	clip 69 219
	push ret139
	push scanline_func
	popj
ret139:
	clip 70 220
	push ret140
	push scanline_func
	popj
ret140:
	clip 70 221
	push ret141
	push scanline_func
	popj
ret141:
	clip 71 222
	push ret142
	push scanline_func
	popj
ret142:
	clip 71 223
	push ret143
	push scanline_func
	popj
ret143:
	clip 72 224
	push ret144
	push scanline_func
	popj
ret144:
	clip 72 225
	push ret145
	push scanline_func
	popj
ret145:
	clip 73 226
	push ret146
	push scanline_func
	popj
ret146:
	clip 73 227
	push ret147
	push scanline_func
	popj
ret147:
	clip 74 228
	push ret148
	push scanline_func
	popj
ret148:
	clip 74 229
	push ret149
	push scanline_func
	popj
ret149:
	clip 75 230
	push ret150
	push scanline_func
	popj
ret150:
	clip 75 231
	push ret151
	push scanline_func
	popj
ret151:
	clip 76 232
	push ret152
	push scanline_func
	popj
ret152:
	clip 76 233
	push ret153
	push scanline_func
	popj
ret153:
	clip 77 234
	push ret154
	push scanline_func
	popj
ret154:
	clip 77 235
	push ret155
	push scanline_func
	popj
ret155:
	clip 78 236
	push ret156
	push scanline_func
	popj
ret156:
	clip 78 237
	push ret157
	push scanline_func
	popj
ret157:
	clip 79 238
	push ret158
	push scanline_func
	popj
ret158:
	clip 79 239
	push ret159
	push scanline_func
	popj
ret159:
	clip 80 240
	push ret160
	push scanline_func
	popj
ret160:
	clip 80 241
	push ret161
	push scanline_func
	popj
ret161:
	clip 81 242
	push ret162
	push scanline_func
	popj
ret162:
	clip 81 243
	push ret163
	push scanline_func
	popj
ret163:
	clip 82 244
	push ret164
	push scanline_func
	popj
ret164:
	clip 82 245
	push ret165
	push scanline_func
	popj
ret165:
	clip 83 246
	push ret166
	push scanline_func
	popj
ret166:
	clip 83 247
	push ret167
	push scanline_func
	popj
ret167:
	clip 84 248
	push ret168
	push scanline_func
	popj
ret168:
	clip 84 249
	push ret169
	push scanline_func
	popj
ret169:
	clip 85 250
	push ret170
	push scanline_func
	popj
ret170:
	clip 85 251
	push ret171
	push scanline_func
	popj
ret171:
	clip 86 252
	push ret172
	push scanline_func
	popj
ret172:
	clip 86 253
	push ret173
	push scanline_func
	popj
ret173:
	clip 87 254
	push ret174
	push scanline_func
	popj
ret174:
	clip 87 255
	push ret175
	push scanline_func
	popj
ret175:
	clip 88 256
	push ret176
	push scanline_func
	popj
ret176:
	clip 88 257
	push ret177
	push scanline_func
	popj
ret177:
	clip 89 258
	push ret178
	push scanline_func
	popj
ret178:
	clip 89 259
	push ret179
	push scanline_func
	popj
ret179:
	clip 90 260
	push ret180
	push scanline_func
	popj
ret180:
	clip 90 261
	push ret181
	push scanline_func
	popj
ret181:
	clip 91 262
	push ret182
	push scanline_func
	popj
ret182:
	clip 91 263
	push ret183
	push scanline_func
	popj
ret183:
	clip 92 264
	push ret184
	push scanline_func
	popj
ret184:
	clip 92 265
	push ret185
	push scanline_func
	popj
ret185:
	clip 93 266
	push ret186
	push scanline_func
	popj
ret186:
	clip 93 267
	push ret187
	push scanline_func
	popj
ret187:
	clip 94 268
	push ret188
	push scanline_func
	popj
ret188:
	clip 94 269
	push ret189
	push scanline_func
	popj
ret189:
	clip 95 270
	push ret190
	push scanline_func
	popj
ret190:
	clip 95 271
	push ret191
	push scanline_func
	popj
ret191:
	clip 96 272
	push ret192
	push scanline_func
	popj
ret192:
	clip 96 273
	push ret193
	push scanline_func
	popj
ret193:
	clip 97 274
	push ret194
	push scanline_func
	popj
ret194:
	clip 97 275
	push ret195
	push scanline_func
	popj
ret195:
	clip 98 276
	push ret196
	push scanline_func
	popj
ret196:
	clip 98 277
	push ret197
	push scanline_func
	popj
ret197:
	clip 99 278
	push ret198
	push scanline_func
	popj
ret198:
	clip 99 279
	push ret199
	push scanline_func
	popj
ret199:
	clip 100 280
	push ret200
	push scanline_func
	popj
ret200:
	clip 100 281
	push ret201
	push scanline_func
	popj
ret201:
	clip 101 282
	push ret202
	push scanline_func
	popj
ret202:
	clip 101 283
	push ret203
	push scanline_func
	popj
ret203:
	clip 102 284
	push ret204
	push scanline_func
	popj
ret204:
	clip 102 285
	push ret205
	push scanline_func
	popj
ret205:
	clip 103 286
	push ret206
	push scanline_func
	popj
ret206:
	clip 103 287
	push ret207
	push scanline_func
	popj
ret207:
	clip 104 288
	push ret208
	push scanline_func
	popj
ret208:
	clip 104 289
	push ret209
	push scanline_func
	popj
ret209:
	clip 105 290
	push ret210
	push scanline_func
	popj
ret210:
	clip 105 291
	push ret211
	push scanline_func
	popj
ret211:
	clip 106 292
	push ret212
	push scanline_func
	popj
ret212:
	clip 106 293
	push ret213
	push scanline_func
	popj
ret213:
	clip 107 294
	push ret214
	push scanline_func
	popj
ret214:
	clip 107 295
	push ret215
	push scanline_func
	popj
ret215:
	clip 108 296
	push ret216
	push scanline_func
	popj
ret216:
	clip 108 297
	push ret217
	push scanline_func
	popj
ret217:
	clip 109 298
	push ret218
	push scanline_func
	popj
ret218:
	clip 109 299
	push ret219
	push scanline_func
	popj
ret219:
	clip 110 300
	push ret220
	push scanline_func
	popj
ret220:
	clip 110 301
	push ret221
	push scanline_func
	popj
ret221:
	clip 111 302
	push ret222
	push scanline_func
	popj
ret222:
	clip 111 303
	push ret223
	push scanline_func
	popj
ret223:
	clip 112 304
	push ret224
	push scanline_func
	popj
ret224:
	clip 112 305
	push ret225
	push scanline_func
	popj
ret225:
	clip 113 306
	push ret226
	push scanline_func
	popj
ret226:
	clip 113 307
	push ret227
	push scanline_func
	popj
ret227:
	clip 114 308
	push ret228
	push scanline_func
	popj
ret228:
	clip 114 309
	push ret229
	push scanline_func
	popj
ret229:
	clip 115 310
	push ret230
	push scanline_func
	popj
ret230:
	clip 115 311
	push ret231
	push scanline_func
	popj
ret231:
	clip 116 312
	push ret232
	push scanline_func
	popj
ret232:
	clip 116 313
	push ret233
	push scanline_func
	popj
ret233:
	clip 117 314
	push ret234
	push scanline_func
	popj
ret234:
	clip 117 315
	push ret235
	push scanline_func
	popj
ret235:
	clip 118 316
	push ret236
	push scanline_func
	popj
ret236:
	clip 118 317
	push ret237
	push scanline_func
	popj
ret237:
	clip 119 318
	push ret238
	push scanline_func
	popj
ret238:
	clip 119 319
	push ret239
	push scanline_func
	popj
ret239:
