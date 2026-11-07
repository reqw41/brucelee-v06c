; Комната на i8080: перевод src/model/room.js (= ZX C16E, D5BB, D60E/D626, D7AC.., DDA8, DE47, DF7A ..).

; --- HL = (строка, столбец) -> HL = 6000 + смещение (D60E/D626) -----------------------------------------
tile_addr:	LD	A,H
			RRCA
			RRCA
			RRCA
			LD	H,A
			LD	A,L
			XOR	H
			AND	0x1F
			XOR	H
			LD	L,A
			LD	A,H
			AND	3
			OR	0x60
			LD	H,A
			RET
; D60E: тайл A в (H, L)
tile_put:	PUSH	AF
			CALL	tile_addr
			POP	AF
			LD	(HL),A
			JP	plat_tile
; D626: тайл из фона 5D00
tile_redraw:
			CALL	tile_addr
			LD	D,H
			LD	E,L
			LD	A,D
			SUB	3
			LD	D,A
			LD	A,(DE)
			LD	(HL),A
			JP	plat_tile

; --- CA37: обработчик комнаты из таблицы HL, аргумент DE -------------------------------------------------
room_dispatch:
			LD	A,(zv_FE03)
			ADD	A,A
			PUSH	DE
			LD	E,A
			LD	D,0
			ADD	HL,DE
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			EX	DE,HL
			POP	DE
			JP	(HL)

; --- D5BB: «воля» комнаты A в точке HL --------------------------------------------------------------------
will_apply:	LD	(zv_FE98),A
			LD	(zv_FEAE),HL
			ADD	A,A
			LD	L,A
			LD	H,0x64
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			LD	HL,6
			ADD	HL,DE
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			LD	HL,(zv_FEAE)
			EX	DE,HL				; HL = список, DE = точка
.l:			LD	A,(HL)
			CP	0xFF
			RET	Z
			OR	A
			JP	P,.cmp
			LD	(zv_FEB0),HL
			INC	HL
			LD	A,(HL)
.cmp:		CP	E
			INC	HL
			JP	NZ,.n
			LD	A,(HL)
			CP	D
.n:			INC	HL
			INC	HL
			JP	NZ,.l
			LD	HL,(zv_FEB0)
			LD	A,(zv_FE04)
			CPL
			AND	(HL)
			LD	(HL),A
			LD	A,(zv_FE03)
			LD	B,A
			LD	A,(zv_FE98)
			CP	B
			RET	NZ
			INC	HL
.t:			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			INC	HL
			PUSH	HL
			EX	DE,HL
			CALL	tile_redraw
			POP	HL
			INC	HL
			LD	A,(HL)
			OR	A
			JP	P,.t
			RET

; --- DDFF: фаза воды — Z: двигать ----------------------------------------------------------------------
water_phase:
			LD	A,(zc_CCAF)
			OR	A
			RET	NZ
			LD	HL,zv_FE9B
			DEC	(HL)
			RET	NZ
			LD	A,(zv_FE9C)
			LD	B,A
			AND	0x3F
			LD	C,A
			RRCA
			RRCA
			AND	0x0F
			ADD	A,6
			LD	(HL),A
			LD	A,B
			AND	0x40
			JP	Z,.inc
			DEC	C
			JP	NZ,.e2e
			LD	A,B
			AND	0xBF
			LD	B,A
			JP	.e2e
.inc:		INC	C
			LD	A,C
			AND	0x40
			JP	Z,.e2e
			LD	A,B
			OR	0x7F
			XOR	0x80
			JP	.e33
.e2e:		LD	A,C
			XOR	B
			AND	0x3F
			XOR	B
.e33:		LD	(zv_FE9C),A
			CP	A
			RET

; --- рабочая копия персонажа вне шага ----------------------------------------------------------------------
pw_load:	LD	(pcur),HL			; запись HL -> pw (развёрнуто; HL портится)
pw_in:
.k = 0
			DUP	0x12				; поля 00..11 (указатели +12..+15 через pw не нужны)
			LD	A,(HL)
			LD	(pw+.k),A
			INC	HL
.k = .k + 1
			EDUP
			RET
pw_store:	LD	HL,(pcur)			; pw -> запись
pw_out:
.k = 0
			DUP	0x12				; поля 00..11 (указатели +12..+15 через pw не нужны)
			LD	A,(pw+.k)
			LD	(HL),A
			INC	HL
.k = .k + 1
			EDUP
			RET

; --- DE47/DF11: вода сдвигает картинку (вывод) и толкает персонажей; HL — адрес в теневом экране, BC ---------
water:		LD	A,1
			LD	(zv_FE1A),A
			LD	A,H
			AND	0x5F
			LD	H,A
			PUSH	BC
			PUSH	HL
			CALL	plat_water
			POP	HL
			POP	DE					; DE = BC
			LD	A,L					; DECD
			RLCA
			RLCA
			RLCA
			XOR	H
			AND	0xE7
			XOR	H
			AND	0x1F
			LD	H,A
			LD	A,L
			AND	0x1F
			LD	L,A
			LD	(wt_hl),HL
			EX	DE,HL
			LD	(wt_de),HL
			LD	HL,NINJA
			CALL	.one
			LD	HL,YAMO
			CALL	.one
			LD	HL,BRUCE
.one:		CALL	pw_load
			CALL	.push
			JP	pw_store
.push:		LD	HL,(wt_hl)
			EX	DE,HL
			LD	HL,(wt_de)
			EX	DE,HL
			CALL	overlap
			RET	NZ
			LD	A,(zv_FE9C)
			AND	0x80
			JP	NZ,.down
			CALL	ceiling_above		; DEA6
			RET	Z
			LD	A,(P_YO)
			SUB	2
			AND	6
			LD	(P_YO),A
			CP	6
			RET	NZ
			LD	HL,P_Y
			DEC	(HL)
			LD	A,(HL)
			CP	2
			RET	NC
			LD	(HL),2
			XOR	A
			LD	(P_YO),A
			RET
.down:		LD	A,(P_Y)				; DF60
			ADD	A,B
			CP	0x17
			RET	NC
			LD	A,(P_YO)
			ADD	A,2
			AND	6
			LD	(P_YO),A
			RET	NZ
			LD	HL,P_Y
			INC	(HL)
			RET
wt_hl:		DW	0
wt_de:		DW	0
; DEDD: Z — персонаж (pw) задевает область HL (строка, столбец), DE (D — ширина, E — высота); B = высота
overlap:	LD	A,(P_DY)
			OR	A
			RET	NZ
			LD	A,(P_ST)
			OR	A
			JP	Z,.no
			CALL	size
			LD	A,(P_X)
			ADD	A,C
			DEC	A
			CP	L
			JP	C,.no
			LD	A,L
			ADD	A,D
			DEC	A
			LD	C,A
			LD	A,(P_X)
			LD	B,A
			LD	A,C
			CP	B
			JP	C,.no2
			LD	A,H
			ADD	A,E
			DEC	A
			LD	C,A
			LD	A,(P_Y)
			LD	B,A
			LD	A,C
			CP	B
			JP	C,.no2
			CALL	size				; B = высота снова
			LD	A,(P_Y)
			ADD	A,B
			DEC	A
			CP	H
			JP	C,.no
			CP	A
			RET
.no2:
.no:		LD	A,1
			OR	A
			RET

; --- DF9D: полоса HL (6030..), состояние DE (FE72..) ---------------------------------------------------------
strip:		LD	A,(HL)
			OR	A
			RET	Z
			LD	A,(DE)
			OR	A
			JP	Z,.go
			DEC	A
			LD	(DE),A
			RET
.go:		INC	DE					; +1 (пишет прерывание)
			LD	A,(DE)
			CP	4
			RET	C
			XOR	A
			LD	(DE),A
			INC	DE
			INC	DE
			INC	DE					; +4
			LD	A,(DE)
			OR	A
			JP	NZ,.c4
			INC	HL
			LD	A,(HL)
			DEC	HL
			DEC	DE
			LD	(DE),A				; +3
			INC	DE
			LD	A,4
			JP	.ed
.c4:		CP	4
			LD	A,5
			JP	Z,.ed
			PUSH	HL
			PUSH	DE
			LD	B,(HL)
			DEC	DE
			LD	A,(DE)
			LD	L,A
			LD	H,B
			CALL	tile_redraw
			POP	DE
			POP	HL
			DEC	DE					; +3
			LD	A,(DE)
			INC	A
			LD	(DE),A
			LD	C,A
			INC	HL
			INC	HL
			LD	A,(HL)
			CP	C
			JP	NC,.e9
			INC	HL
			LD	A,(HL)
			DEC	DE
			DEC	DE
			DEC	DE					; +0
			LD	(DE),A
			INC	DE
			INC	DE
			INC	DE
			INC	DE					; +4
			XOR	A
			LD	(DE),A
			RET
.e9:		DEC	HL
			DEC	HL
			INC	DE					; +4
			LD	A,4
.ed:		LD	(DE),A
			LD	B,(HL)
			DEC	DE
			PUSH	AF
			LD	A,(DE)
			LD	L,A
			LD	H,B
			POP	AF
			JP	tile_put
; DF7A
strips:		LD	HL,0x6030
			LD	DE,zv_FE72
			CALL	strip
			LD	HL,0x6034
			LD	DE,zv_FE77
			CALL	strip
			LD	HL,0x6038
			LD	DE,zv_FE7C
			JP	strip

; --- DDA8: бегунок, описатель HL (6 байт: строка, столбец, начало, предел, напр., тайл) ---------------------
mover:		LD	(mv_p),HL
			LD	A,(HL)
			LD	(mv_r),A
			INC	HL
			INC	HL
			INC	HL
			INC	HL
			LD	A,(HL)				; +4
			INC	HL
			LD	B,(HL)				; +5
			RRCA
			JP	C,.lt
			LD	A,B
			CP	6
			LD	A,7
			JP	Z,.st
			CALL	.redraw
			LD	HL,(mv_p)
			INC	HL
			LD	A,(HL)				; +1
			INC	HL
			INC	HL
			CP	(HL)				; +3
			LD	A,6
			JP	NC,.rst
			LD	HL,(mv_p)
			INC	HL
			INC	(HL)
			JP	.st
.lt:		LD	A,B
			CP	7
			LD	A,6
			JP	Z,.st
			CALL	.redraw
			LD	HL,(mv_p)
			INC	HL
			INC	HL
			INC	HL
			LD	A,(HL)				; +3
			DEC	HL
			DEC	HL
			CP	(HL)				; +1
			LD	A,7
			JP	NC,.rst
			DEC	(HL)
			JP	.st
.rst:		LD	HL,(mv_p)
			INC	HL
			INC	HL
			LD	B,(HL)				; +2
			DEC	HL
			LD	(HL),B				; +1
.st:		LD	HL,(mv_p)
			LD	DE,5
			ADD	HL,DE
			LD	(HL),A
			PUSH	AF
			CALL	.at
			POP	AF
			JP	tile_put
.redraw:	CALL	.at
			JP	tile_redraw
.at:		LD	HL,(mv_p)
			LD	A,(HL)
			INC	HL
			LD	L,(HL)
			LD	H,A
			RET
mv_p:		DW	0
mv_r:		DB	0

; --- D9D7/D9E7: трещины в слотах FE60 (по 3 байта: счёт, столбец, строка) -------------------------------
cracks:		LD	HL,zv_FE60
			LD	B,6
.l:			LD	A,(HL)
			OR	A
			JP	Z,.n
			PUSH	BC
			PUSH	HL
			CALL	crack
			POP	HL
			POP	BC
.n:			INC	HL
			INC	HL
			INC	HL
			DEC	B
			JP	NZ,.l
			RET
crack:		INC	(HL)
			LD	A,(HL)
			CP	0x14
			RET	C
			LD	(ck_s),HL
			INC	HL
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			EX	DE,HL				; H = строка, L = столбец
			CP	0x14
			JP	NZ,.c32
			LD	A,8
			JP	tile_put
.c32:		CP	0x32
			JP	NZ,.c37
			LD	A,0x20
			JP	tile_put
.c37:		CP	0x37
			JP	NZ,.sp
			CALL	tile_redraw
			LD	HL,(ck_s)
			LD	(HL),0
			RET
.sp:		LD	DE,zc_DA51
			CP	0x19
			JP	Z,.go
			CP	0x28
			JP	Z,.go
			LD	DE,zc_DA57
			CP	0x1E
			JP	Z,.go
			LD	DE,zc_DA5D
			CP	0x2D
			RET	NZ
.go:		PUSH	HL
			DEC	H
			DEC	L
			CALL	.put3
			POP	HL
			DEC	L
.put3:		CALL	.put
			CALL	.put
.put:		PUSH	DE
			LD	A,(DE)
			PUSH	HL
			CALL	tile_put
			POP	HL
			INC	L
			POP	DE
			INC	DE
			RET
ck_s:		DW	0

; --- обработчики комнат -------------------------------------------------------------------------------------
r_D824:		RET
r_DAC4:		JP	plat_rand			; BUGFIX: ловушка-сброс выключена, LD A,R остаётся
flick:		LD	HL,zv_FE38
			LD	A,(HL)
			OR	A
			RET	Z
			INC	A
			OR	1
			LD	(HL),A
			AND	0x40
			LD	A,0x53
			JP	Z,.p
			LD	A,0x79
.p:			EX	DE,HL
			JP	tile_put
r_DA94:		LD	DE,0x0F05
			JP	flick
r_DAAD:		LD	DE,0x0F1A
			JP	flick
r_DAB2:		CALL	water_phase
			JP	NZ,strips
			LD	HL,0xE091
			LD	BC,0x0312
			CALL	water
			JP	strips
r_DACC:		CALL	water_phase
			JP	NZ,strips
			LD	HL,0xE09B
			LD	BC,0x0214
			CALL	water
			JP	strips
r_DAFF:		CALL	water_phase
			JP	NZ,strips
			LD	HL,0xE801
			LD	BC,0x020F
			CALL	water
			LD	HL,0xE08E
			LD	BC,0x0412
			CALL	water
			LD	HL,0xE81D
			LD	BC,0x020F
			CALL	water
			JP	strips
r_DADE:		LD	A,(zv_FE99)
			CP	3
			JP	C,.c
			XOR	A
			LD	(zv_FE99),A
			LD	HL,zc_DAF9
			CALL	mover
.c:			CALL	cracks
			JP	strips
r_DB23:		CALL	water_phase
			JP	NZ,.b82
			LD	HL,db23_t
			LD	B,10
.l:			PUSH	BC
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			INC	HL
			LD	C,(HL)
			INC	HL
			LD	B,(HL)
			INC	HL
			PUSH	HL
			EX	DE,HL
			CALL	water
			POP	HL
			POP	BC
			DEC	B
			JP	NZ,.l
.b82:		LD	A,(zv_FE99)
			CP	2
			JP	C,strips
			XOR	A
			LD	(zv_FE99),A
			LD	HL,zc_DBA4
			LD	A,(zv_FE3A)
			CP	2
			JP	NZ,mover
			LD	HL,zc_DBAA
			JP	mover
db23_t:		DW	0xE8A1,0x0204, 0xE863,0x0204, 0xE825,0x0204, 0xE0E7,0x0204, 0xE0E9,0x0202
			DW	0xE874,0x0206, 0xE836,0x0206, 0xE0F8,0x0206, 0xE0FA,0x0204, 0xE09D,0x0213
r_DBB0:		LD	HL,zv_FE38
			INC	(HL)
			LD	A,(HL)
			LD	DE,0x206C
			CP	0x40
			JP	Z,.go
			LD	DE,0x6C20
			CP	0xC0
			RET	NZ
.go:		LD	HL,0x6128
			LD	B,6
.a:			LD	(HL),D
			INC	HL
			DEC	B
			JP	NZ,.a
			LD	HL,0x6130
			LD	B,6
.b:			LD	(HL),E
			INC	HL
			DEC	B
			JP	NZ,.b
			LD	HL,0xF936
			LD	(zv_FEA8),HL
			LD	HL,0x0908			; сменились тайлы воды: строка 9, столбцы 8..13 и 16..21
			LD	BC,0x0106
			CALL	plat_rect
			LD	HL,0x0910
			LD	BC,0x0106
			CALL	plat_rect
			LD	A,1
			LD	(zv_FE0B),A
			RET
r_D9D7:		JP	cracks
r_DBEC:		CALL	cracks
			JP	strips
r_DBF2:		CALL	water_phase
			JP	NZ,.c
			LD	HL,0xE081
			LD	BC,0x0413
			CALL	water
.c:			CALL	cracks
			LD	A,(zc_CCAB)
			CP	8
			RET	C
			CP	0x1B
			RET	NC
			LD	A,(zc_CCAC)
			CP	0x0D
			RET	NZ
			LD	A,(zc_CCA9)
			OR	A
			RET	NZ
			LD	A,1
			LD	(zv_FE0C),A
			RET
r_DC1D:		LD	A,(zv_FE95)
			OR	0xC0
			LD	(zv_FE95),A
			JP	cracks
r_DC27:		LD	HL,zv_FE95
			LD	A,(HL)
			OR	A
			JP	Z,cracks
			CP	0xC0
			JP	NZ,.e4e
			LD	(HL),0
.w0:		LD	HL,0
.w:			CALL	plat_walls			; HL = 0 (стены целы) или 8686 (рухнули): вывод
			LD	A,1
			LD	(zv_FE0B),A
			JP	cracks
.e4e:		LD	B,A
			AND	0xBF
			LD	(HL),A
			LD	A,B
			AND	0x80
			JP	Z,cracks
			LD	A,B
			AND	0x40
			LD	HL,0x8686
			JP	NZ,.w
			LD	A,(zc_CCAC)
			CP	0x11
			JP	C,cracks
			LD	A,(zc_CCAB)
			CP	0x1A
			JP	NZ,cracks
			LD	HL,zv_FE95
			LD	A,(HL)
			AND	7
			JP	Z,cracks
			DEC	A
			LD	(HL),A
			CALL	lives_up
			JP	.w0
r_DC78:		LD	A,(zv_FE99)
			CP	3
			RET	C
			XOR	A
			LD	(zv_FE99),A
			LD	HL,zc_DCBE
			LD	B,8
.l:			PUSH	BC
			PUSH	HL
			CALL	mover
			POP	HL
			LD	DE,6
			ADD	HL,DE
			POP	BC
			DEC	B
			JP	NZ,.l
			RET
r_DCEE:		LD	A,(zv_FE99)
			CP	3
			JP	C,strips
			XOR	A
			LD	(zv_FE99),A
			LD	HL,zc_DD07
			CALL	mover
			JP	strips
r_DD0D:
	IFDEF	WIZ_CPC						; Вектор (владелец 07.11): стрельба колдуна как у CPC (src/vec/wizcpc.asm);
			JP	wiz_cpc					; run80 --ship: JP -> NOP — логика ZX
	ENDIF
			LD	A,(zv_FE3C)
			OR	A
			JP	Z,.d48
			INC	A
			LD	(zv_FE3C),A
			CP	0x1E
			RET	C
.mv:		LD	HL,(zv_FE17)		; полёт шара на ряд (wiz_cpc входит сюда со своим шагом FE19)
			PUSH	HL
			CALL	tile_redraw
			POP	HL
			LD	A,H
			CP	0x15
			LD	A,0
			JP	NC,.d63
			INC	H
			LD	A,(zv_FE19)
			ADD	A,L
			LD	L,A
			LD	(zv_FE17),HL
			EX	DE,HL
			LD	HL,(0x6000)
			PUSH	HL
			LD	HL,0x9EA8
			LD	(0x6000),HL
			EX	DE,HL
			XOR	A
			CALL	tile_put
			POP	HL
			LD	(0x6000),HL
			RET
.d48:		LD	HL,0x0810
			LD	(zv_FE17),HL
			LD	A,(zc_CCAB)
			LD	B,0xFF
			CP	0x0A
			JP	C,.d5d
			INC	B
			CP	0x12
			JP	C,.d5d
			INC	B
.d5d:		LD	A,B
			LD	(zv_FE19),A
			LD	A,1
.d63:		LD	(zv_FE3C),A
			RET
r_DD67:		JP	level_complete
r_DA63:		LD	HL,0xA000			; DE = клетка карты; DE - 0x6000
			ADD	HL,DE
			LD	A,L
			AND	0x1F
			LD	E,A
			LD	A,L
			RLCA
			RLCA
			RLCA
			AND	7
			LD	D,A
			LD	A,H
			ADD	A,A
			ADD	A,A
			ADD	A,A
			OR	D
			LD	D,A					; DE = (строка, столбец)
			LD	HL,zv_FE60
			LD	B,6
.l:			LD	A,(HL)
			OR	A
			JP	Z,.free
			INC	HL
			INC	HL
			INC	HL
			DEC	B
			JP	NZ,.l
			RET
.free:		INC	(HL)
			INC	HL
			LD	(HL),E
			INC	HL
			LD	(HL),D
			EX	DE,HL
			LD	A,0x20
			JP	tile_put
; после подбора предмета (D7D4): DE = (строка, столбец)
	MACRO	CNT_EQ var, n			; ++var, CP n
		LD	HL,var
		INC	(HL)
		LD	A,(HL)
		CP	n
	ENDM
r_D845:		CNT_EQ	zv_FE20, 0x15
			RET	NZ
			LD	A,1
			LD	HL,0x170F
			JP	will_apply
r_D856:		LD	A,D
			CP	0x10
			JP	NC,.a
			LD	A,E
			CP	0x1B
			RET	C
			LD	A,1
			LD	(zv_FE38),A
			LD	A,2
			LD	HL,0x111F
			JP	will_apply
.a:			CNT_EQ	zv_FE22, 4
			JP	NZ,.b
			LD	A,4
			LD	HL,0x1200
			JP	will_apply
.b:			CP	2
			RET	NZ
			LD	A,4
			LD	HL,0x1112
			JP	will_apply
r_D888:		CNT_EQ	zv_FE36, 8
			RET	NZ
			LD	A,5
			LD	HL,0x0300
			JP	will_apply
r_D898:		LD	A,D
			CP	0x0F
			JP	NC,.alt
			CNT_EQ	zv_FE24, 5
			JP	NZ,.b
			LD	A,6
			LD	HL,0x031B
			JP	will_apply
.b:			CP	0x0A
			RET	NZ
			LD	A,6
			LD	HL,0x091F
			JP	will_apply
.alt:		LD	HL,zv_FE26
			INC	(HL)
			LD	A,(HL)
			CP	2
			RET	C
			LD	HL,zc_DAFB
			LD	(HL),0x1C
			INC	HL
			LD	(HL),5
			INC	HL
			LD	(HL),1
			LD	A,7
			LD	HL,0x0B0B
			JP	will_apply
r_D8D4:		LD	A,E
			CP	6
			JP	NC,.ec
			LD	HL,zc_DAFB
			LD	(HL),5
			INC	HL
			LD	(HL),0x1C
			INC	HL
			LD	(HL),0
			LD	A,7
			LD	HL,0x1100
			JP	will_apply
.ec:		CP	0x15
			RET	NC
			LD	HL,zv_FE28
			INC	(HL)
			LD	A,(HL)
			CP	2
			RET	C
			LD	HL,0xC810
			LD	(zv_FE9B),HL
			LD	A,7
			LD	HL,0x0B14
			JP	will_apply
r_D902:		LD	A,D
			CP	6
			JP	NC,.a
			LD	HL,0xC810
			LD	(zv_FE9B),HL
			RET
.a:			CP	0x11
			RET	C
			LD	A,E
			CP	0x19
			JP	C,.b
			LD	HL,0x4810
			LD	(zv_FE9B),HL
			RET
.b:			CNT_EQ	zv_FE3A, 2
			RET	NZ
			LD	A,(zc_DBA5)
			LD	(zc_DBAB),A
			LD	A,7
			LD	HL,0x031F
			JP	will_apply
r_D928:		LD	HL,zv_FE2A
			INC	(HL)
			LD	A,(HL)
			CP	2
			RET	C
			LD	A,9
			LD	HL,0x1718
			JP	will_apply
r_D938:		CNT_EQ	zv_FE2C, 3
			RET	NZ
			LD	A,0x0A
			LD	HL,0x041F
			JP	will_apply
r_D948:		CNT_EQ	zv_FE2E, 3
			RET	NZ
			LD	A,0x0C
			LD	HL,0x0B1F
			JP	will_apply
r_D958:		LD	A,D
			CP	0x10
			JP	NC,.b
			CNT_EQ	zv_FE30, 2
			RET	NZ
			LD	A,0x0D
			LD	HL,0x041F
			JP	will_apply
.b:			CNT_EQ	zv_FE32, 2
			RET	NZ
			LD	A,0x0D
			LD	HL,0x121F
			JP	will_apply
r_D97D:		CNT_EQ	zv_FE34, 2
			RET	NZ
			LD	A,0x0E
			LD	HL,0x0B00
			JP	will_apply
r_D98D:		LD	HL,zc_C995			; подбор оружия
			CALL	add_score
			CALL	plat_weapon			; вывод: Брюс с оружием и вспышка (~255 кадров)
			XOR	A
			LD	(zv_FE0B),A			; C29C
			LD	A,0xFF
			LD	(zv_FE3C),A
			LD	A,1
			LD	(zv_FE0C),A
			RET

; --- C16E: загрузка комнаты FE03 -----------------------------------------------------------------------------
room_load:	CALL	plat_rl_begin		; ZX: DI на всю загрузку комнаты
			LD	A,(zv_FE03)
			ADD	A,A
			LD	L,A
			LD	H,0x64
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			PUSH	DE
			EX	DE,HL
			LD	DE,0x6000
			LD	B,0x40
.hd:		LD	A,(HL)
			LD	(DE),A
			INC	HL
			INC	DE
			DEC	B
			JP	NZ,.hd
			EX	(SP),HL				; HL = описатель, на стеке — после заголовка
			LD	DE,0x0C
			ADD	HL,DE
			LD	A,(zv_FE04)
			CP	1
			JP	Z,.p1
			INC	HL
.p1:		LD	(HL),1
			POP	HL
			LD	B,0x60				; поток тайлов комнаты — ZX0 на месте RLE (tools/mkvecdata.py): -> 6040, 704 байта
			LD	C,0x40
			CALL	dzx0
.rend:		LD	HL,0x6000
			LD	DE,0x5D00
			LD	BC,0x0003			; B — байт в странице, C — страниц
.sh:		LD	A,(HL)
			LD	(DE),A
			INC	HL
			INC	DE
			DEC	B
			JP	NZ,.sh
			DEC	C
			JP	NZ,.sh
			LD	HL,(0x6006)			; ключи и предметы
.k:			LD	A,(HL)
			OR	A
			JP	P,.kput
			CP	0xFF
			JP	Z,.kend
			LD	B,A
			LD	A,(zv_FE04)
			AND	B
			JP	Z,.kskip
			INC	HL
.kput:		LD	A,(HL)
			INC	HL
			LD	B,(HL)
			LD	C,A
			LD	A,B
			RRCA
			RRCA
			RRCA
			LD	B,A
			LD	A,C
			XOR	B
			AND	0x1F
			XOR	B
			LD	C,A
			LD	A,B
			AND	3
			LD	B,A
			INC	HL
			LD	A,(HL)
			PUSH	HL
			LD	HL,0x6000
			ADD	HL,BC
			LD	(HL),A
			POP	HL
			INC	HL
			JP	.k
.kskip:		INC	HL
.ks:		INC	HL
			INC	HL
			INC	HL
			LD	A,(HL)
			OR	A
			JP	P,.ks
			JP	.k
.kend:		LD	HL,0x6300
			LD	(zv_FEA6),HL
			LD	HL,0xFB00
			LD	(zv_FEA8),HL
			XOR	A
			LD	(zv_FE02),A
			LD	HL,rl_zero
.z:			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			INC	HL
			LD	A,D
			OR	E
			JP	Z,.zd
			XOR	A
			LD	(DE),A
			JP	.z
.zd:		LD	A,1
			LD	(zc_CCA7),A
			LD	HL,zv_FE72
			LD	B,0x0F
			CALL	zero_b
			LD	HL,zv_FE60
			LD	B,0x12
			CALL	zero_b
			LD	A,(zv_FE03)
			OR	A
			JP	Z,.nv
			CP	0x13
			JP	Z,.nv
			LD	HL,0x600C
			LD	A,(zv_FE04)
			CP	1
			JP	Z,.v1
			INC	HL
.v1:		LD	A,(HL)
			OR	A
			JP	NZ,.nv
			LD	HL,zc_C98F
			CALL	add_score
.nv:		LD	A,(zv_FE0D)
			OR	A
			LD	A,0x0A
			JP	NZ,.sp
			LD	A,0x28
.sp:		LD	(zc_CB2C),A
			LD	(zc_CBCE),A
			LD	HL,0
			LD	(zv_FE05),HL
			LD	HL,0x4810
			LD	(zv_FE9B),HL
			CALL	plat_room
			XOR	A
			LD	(zv_FE0B),A
			RET
rl_zero:	DW	zc_CB1E, zc_CBC0, zc_CB20, zc_CBC2, zc_CCA9, zc_CB2A, zc_CBCC, zc_CCB3, zc_CB26, zc_CBC8, zc_CCAF
			DW	zc_CB2D, zc_CBCF, zc_CCB6, 0
zero_b:		LD	(HL),0
			INC	HL
			DEC	B
			JP	NZ,zero_b
			RET

			INCLUDE	"dzx0.asm"
