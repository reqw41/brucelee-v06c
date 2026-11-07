; Персонажи на i8080 (этап 2, docs/PLAN.md): перевод src/model/pers.js (= ZX C D24E..D7AB).
; Активный персонаж на время шага — рабочая копия pw (22 байта полей), домашняя запись — pcur.
; Флаги как на ZX: «Z — да» (пол есть, препятствие есть и т. п.).

pw:			DS	0x16
	IFDEF	AI_CPC
AI_TURN		equ	0x0F			; ИИ CPC в боевом образе (src/vec/aicpc.asm); run80 --ship ставит значения ZX
AI_RSP		equ	0x14
AI_APP		equ	0x0F
	ELSE
AI_TURN		equ	0x32
AI_RSP		equ	0x32
AI_APP		equ	0x4B
	ENDIF
P_DLY		equ	pw+0x00		; задержка шага
P_SPD		equ	pw+0x01		; перезагрузка задержки
P_ST		equ	pw+0x02		; состояние / поза (0 — нет)
P_DIR		equ	pw+0x03		; 0 вправо, 1 влево
P_YO		equ	pw+0x04		; смещение по Y / подкадр
P_COL		equ	pw+0x05
P_X			equ	pw+0x06
P_Y			equ	pw+0x07
P_PX		equ	pw+0x08
P_PY		equ	pw+0x09
P_DY		equ	pw+0x0A		; мигание / гибель
P_ACT		equ	pw+0x0B		; желаемое действие
P_C0C		equ	pw+0x0C
P_C0D		equ	pw+0x0D
P_DMG		equ	pw+0x0E
P_POSE		equ	pw+0x0F
P_RSP		equ	pw+0x10
P_BON		equ	pw+0x11
pcur:		DW	0			; домашняя запись активного

NINJA		equ	zc_CB1C
YAMO		equ	zc_CBBE
BRUCE		equ	zc_CCA5

; Z, если активен who
	MACRO	IS_CUR who			; младшие байты трёх записей различны
		LD	A,(pcur)
		CP	low who
	ENDM

; --- D4A3: HL = 6000 + (Y&31)*32 + (X&31) ------------------------------------------------------------
cell:		LD	A,(P_Y)
			RRCA
			RRCA
			RRCA
			LD	H,A
			AND	0xE0
			LD	L,A
			LD	A,(P_X)
			AND	0x1F
			OR	L
			LD	L,A
			LD	A,H
			AND	3
			OR	0x60
			LD	H,A
			RET

; --- D4BE: B = высота, C = ширина; FEAC = описатель, FEA4/FEA5; HL, DE сохраняются ---------------------
size:		PUSH	HL
			PUSH	DE
			LD	A,(P_ST)
			LD	HL,(pcur)
			JP	size_c
; то же по записи HL (не активной): поза — из записи
size_hl:	PUSH	HL
			PUSH	DE
			INC	HL
			INC	HL
			LD	A,(HL)
			DEC	HL
			DEC	HL
size_c:
			DEC	A
			ADD	A,A
			ADD	A,A
			ADD	A,0x16
			LD	E,A
			LD	D,0
			ADD	HL,DE
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			EX	DE,HL
			LD	(zv_FEAC),HL
			LD	C,(HL)
			INC	HL
			LD	B,(HL)
			LD	A,C
			LD	(zv_FEA4),A
			LD	A,B
			LD	(zv_FEA5),A
			POP	DE
			POP	HL
			RET

; --- D332: пол под ногами — Z ------------------------------------------------------------------------
floor_below:
			CALL	cell
			CALL	size
			LD	DE,0x20
.dn:		ADD	HL,DE
			DEC	B
			JP	NZ,.dn
.col:		LD	A,(HL)
			CP	0x40
			JP	NC,.yes
			CP	0x20
			JP	NC,.nx
			CP	0x18
			JP	NC,.yes
.nx:		INC	HL
			DEC	C
			JP	NZ,.col
			INC	C				; NZ
			RET
.yes:		CP	A
			RET

; --- D353: потолок — Z ---------------------------------------------------------------------------------
ceiling_above:
			LD	A,(P_Y)
			CP	3
			JP	C,.yes
			CALL	cell
			CALL	size
			LD	DE,0xFFE0
			ADD	HL,DE
			LD	B,C
.l:			LD	A,(HL)
			CP	0x40
			JP	NC,.yes
			INC	HL
			DEC	B
			JP	NZ,.l
			INC	B
			RET
.yes:		CP	A
			RET

; --- D405: верёвка/лестница — Z; A = счёт ----------------------------------------------------------------
rope_under:
			CALL	cell
			CALL	size
			LD	D,C
			DEC	D
			LD	A,(P_YO)
			OR	A
			JP	Z,.row
			INC	B
.row:		LD	E,0
.col:		LD	A,(HL)
			CP	0x20
			JP	NC,.nx
			CP	0x18
			JP	C,.nx
			INC	E
			LD	A,E
			CP	2
			RET	Z
.nx:		INC	HL
			DEC	C
			JP	NZ,.col
			LD	A,E
			CP	D
			RET	Z
			LD	A,(zv_FEA4)
			LD	C,A
			LD	A,0x20
			SUB	C
			ADD	A,L
			LD	L,A
			JP	NC,.nc
			INC	H
.nc:		DEC	B
			JP	NZ,.row
			INC	B
			RET

; --- D45C/D48F/D456/D43B/D447: препятствия — Z ----------------------------------------------------------
edge:		; D462: Z для Ниндзя и Ямо
			IS_CUR	NINJA
			RET	Z
			IS_CUR	YAMO
			RET
obst_left:	LD	A,(P_X)
			OR	A
			JP	Z,edge
			CALL	cell
			CALL	size
			DEC	HL
wallscan:	LD	DE,0x20
			LD	A,(P_YO)
			OR	A
			JP	Z,.l
			INC	B
.l:			LD	A,(HL)
			CP	0x40
			JP	NC,.yes
			ADD	HL,DE
			DEC	B
			JP	NZ,.l
			INC	B
			RET
.yes:		XOR	A
			RET
obst_right:	CALL	cell
			CALL	size
			LD	A,(P_X)
			ADD	A,C
			CP	0x20
			JP	NC,edge
			LD	E,C
			LD	D,0
			ADD	HL,DE
			JP	wallscan
obst_ahead:	LD	A,(P_DIR)
			RRCA
			JP	C,obst_left
			JP	obst_right
obst_left_edge:
			CALL	obst_left
			RET	Z
			LD	A,(P_X)
			OR	A
			RET	Z
			CP	1
			RET
obst_right_edge:
			CALL	obst_right
			RET	Z
			LD	A,(zv_FEA4)
			LD	B,A
			LD	A,(P_X)
			ADD	A,B
			CP	0x20
			RET	C
			CP	A
			RET

; --- D007: шаг дуги ----------------------------------------------------------------------------------
arc_step:	LD	HL,P_C0C
			INC	(HL)
			LD	E,(HL)
			LD	D,0
			LD	HL,zc_D018
			ADD	HL,DE
			LD	A,(HL)
			LD	(P_YO),A
			RET

; --- CEE9: щелчок шагов Брюса; A сохраняется ----------------------------------------------------------
click:		PUSH	AF
			IS_CUR	BRUCE
			JP	NZ,.x
			LD	A,(zv_FE9A)
			OR	A
			JP	Z,.x
			CALL	plat_click
.x:			POP	AF
			RET

; --- обработчики состояний (A = состояние на входе, A = новое) -----------------------------------------
h_CB8A:		RET

h_CD9B:		XOR	A
			LD	(P_C0C),A
			LD	(P_C0D),A
			IS_CUR	NINJA
			JP	Z,.f
			LD	A,(P_ACT)
			CP	9
			JP	NZ,.a10
			XOR	A
			LD	(P_DIR),A
			LD	A,2
			JP	click
.a10:		CP	0x0A
			JP	NZ,.f
			LD	A,1
			LD	(P_DIR),A
			LD	A,2
			JP	click
.f:			CALL	floor_below
			JP	NZ,cdcd
			LD	A,(P_ACT)
			CP	0x10
			JP	NZ,.a1
			CALL	obst_ahead
			LD	A,1
			RET	Z
			LD	A,(P_DIR)
			RRCA
			JP	NC,.p
			LD	HL,P_X
			DEC	(HL)
.p:			LD	A,0x16
			RET
.a1:		CP	1
			JP	NZ,.a2
			LD	A,(P_DIR)
			RRCA
			JP	C,.set0
.ret2:		LD	A,2
			RET
.set0:		XOR	A
			LD	(P_DIR),A
			LD	A,1
			RET
.a2:		CP	2
			JP	NZ,.a8
			LD	A,(P_DIR)
			RRCA
			JP	C,.ret2
			LD	A,1
			LD	(P_DIR),A
			RET
.a8:		CP	8
			JP	NZ,.a4
			LD	A,0x0C
			RET
.a4:		CP	4
			JP	NZ,.r1
			IS_CUR	BRUCE
			JP	NZ,.r1
			CALL	obst_right
			JP	NZ,.up
			CALL	obst_left
			JP	Z,.r1
			LD	HL,P_X
			DEC	(HL)
.up:		LD	HL,P_Y
			INC	(HL)
			INC	(HL)
			LD	A,8
			RET
.r1:		LD	A,1
			RET
cdcd:		CALL	rope_under
			LD	A,0x0E
			RET	Z
			IS_CUR	NINJA
			JP	Z,.n
			LD	A,1
			LD	(P_DIR),A
.n:			LD	A,0x11
			RET

h_CE48:		XOR	A
			LD	(P_C0C),A
			CALL	floor_below
			JP	NZ,cdcd
			LD	A,(P_DIR)
			RRCA
			JP	C,.left
			CALL	obst_right
			JP	Z,.r1
			LD	A,(P_ACT)
			CP	1
			JP	NZ,.r6b
.goR:		LD	HL,P_X
			INC	(HL)
			LD	A,3
			JP	click
.r6b:		IS_CUR	NINJA
			JP	Z,.r1
			LD	A,(P_ACT)
			CP	0x11
			JP	NZ,.r89
			LD	A,(P_C0D)
			CP	2
			JP	C,.goR
			CALL	obst_right
			JP	Z,.r1
			LD	A,4
			RET
.r89:		CP	9
			JP	NZ,.r1
			CALL	ceiling_above
			JP	Z,.goR
			LD	HL,P_Y
			DEC	(HL)
			LD	A,7
			LD	(P_YO),A
			LD	A,0x0A
			RET
.r1:		LD	A,1
			RET
.left:		CALL	obst_left
			JP	Z,.r1
			LD	A,(P_ACT)
			CP	2
			JP	NZ,.l6b
.goL:		LD	HL,P_X
			DEC	(HL)
			LD	A,3
			JP	click
.l6b:		IS_CUR	NINJA
			JP	Z,.r1
			LD	A,(P_ACT)
			CP	0x12
			JP	NZ,.l89
			LD	A,(P_C0D)
			CP	2
			JP	C,.goL
			CALL	obst_left
			JP	Z,.r1
			LD	HL,P_X
			DEC	(HL)
			LD	A,4
			RET
.l89:		CP	0x0A
			JP	NZ,.r1
			CALL	ceiling_above
			JP	Z,.goL
			LD	HL,P_X
			DEC	(HL)
			LD	HL,P_Y
			DEC	(HL)
			LD	A,7
			LD	(P_YO),A
			LD	A,0x0A
			RET

h_CF04:		CALL	floor_below
			JP	Z,.fl
			CALL	rope_under
			LD	A,0x0E
			RET	Z
			LD	A,0x11
			RET
.fl:		LD	HL,P_C0D
			INC	(HL)
			LD	A,2
			RET

h_CF18:		LD	D,8
			LD	HL,NINJA
			CALL	melee
			LD	D,8
			LD	HL,YAMO
			CALL	melee
			LD	D,8
			LD	HL,BRUCE
			CALL	melee
			LD	A,5
			RET

h_CF2D:		LD	HL,P_C0C
			INC	(HL)
			LD	A,(HL)
			CP	4
			JP	NC,.stop
			LD	A,(P_DIR)
			RRCA
			JP	C,.l
			CALL	obst_right
			JP	Z,.stop
			LD	HL,P_X
			INC	(HL)
			LD	A,4
			RET
.l:			CALL	obst_left
			JP	Z,.stop
			LD	HL,P_X
			DEC	(HL)
			LD	A,4
			RET
.stop:		XOR	A
			LD	(P_C0D),A
			LD	A,2
			RET

h_CF59:		XOR	A
			LD	(P_YO),A
			CALL	floor_below
			JP	Z,.f
			LD	HL,P_Y
			INC	(HL)
.f:			LD	A,(P_C0C)
			CP	2
			JP	NZ,.swing
			LD	A,0x14
			LD	(P_DLY),A
			CALL	killcheck
			JP	NC,.dead
			LD	HL,P_Y
			DEC	(HL)
			IS_CUR	BRUCE
			LD	A,1
			RET	Z
			LD	A,0x32
			LD	(P_DLY),A
			LD	A,1
			RET
.dead:		LD	A,6
			LD	(P_POSE),A
			RET
.swing:		LD	A,3
			LD	(P_DLY),A
			LD	A,(P_DIR)
			RRCA
			JP	C,.sl
			CALL	obst_left_edge
			JP	Z,.bump
			LD	HL,P_X
			DEC	(HL)
			LD	A,7
			RET
.sl:		CALL	obst_right_edge
			JP	Z,.bump
			LD	HL,P_X
			INC	(HL)
			LD	A,7
			RET
.bump:		LD	A,2
			LD	(P_C0C),A
			LD	A,6
			RET

h_CFB3:		LD	HL,P_C0C
			INC	(HL)
			LD	A,3
			LD	(P_DLY),A
			LD	A,6
			RET

h_CFBD:		LD	A,(P_ACT)
			CP	4
			LD	A,8
			RET	Z
			LD	HL,P_Y
			DEC	(HL)
			DEC	(HL)
			LD	A,1
			RET

h_CFCE:		CALL	arc_step
			OR	A
			JP	Z,.land
			LD	A,(P_DIR)
			RRCA
			JP	C,.l
			CALL	obst_right
			JP	Z,.land
			LD	A,0x0A
			RET
.l:			CALL	obst_left
			JP	Z,.land
			LD	HL,P_X
			DEC	(HL)
			LD	A,0x0A
			RET
.land:		LD	HL,P_Y
			INC	(HL)
			XOR	A
			LD	(P_YO),A
			LD	A,2
			JP	click

h_CFF8:		CALL	arc_step
			LD	A,(P_DIR)
			RRCA
			JP	C,.x
			LD	HL,P_X
			INC	(HL)
.x:			LD	A,9
			RET

h_D023:		LD	A,0x0A
			LD	(P_DLY),A
			LD	A,(P_DIR)
			RRCA
			LD	A,1
			RET	NC
			LD	HL,P_X
			INC	(HL)
			RET

h_D032:		LD	A,6
			LD	(P_DLY),A
			CALL	ceiling_above
			LD	A,1
			RET	Z
			LD	A,0x12
			RET

h_D03F:		CALL	arc_step
			OR	A
			JP	Z,.end
			LD	A,(P_C0C)
			CP	3
			JP	NZ,.d
			CALL	rope_under
			JP	NZ,.d
			XOR	A
			LD	(P_YO),A
			LD	A,0x0E
			RET
.d:			LD	A,0x0D
			RET
.end:		LD	HL,P_Y
			INC	(HL)
			LD	A,7
			LD	(P_DLY),A
			LD	A,1
			RET

; D066: лазанье; A = сохранённое состояние
h_D063:		LD	A,(P_ST)
climb:		LD	(cl_sv),A
			CALL	rope_under
			JP	NZ,.off
			LD	A,(P_ACT)
			CP	8
			JP	NZ,.a4
			LD	A,(P_YO)
			CP	4
			JP	NC,.sub
			CALL	ceiling_above
			LD	A,0
			JP	Z,.st
			LD	A,(P_YO)
.sub:		SUB	4
			JP	NC,.m6
			LD	HL,P_Y
			DEC	(HL)
.m6:		AND	6
.st:		LD	(P_YO),A
.fin:		LD	A,(P_DIR)
			XOR	1
			AND	1
			LD	(P_DIR),A
			LD	A,8
			LD	(P_DLY),A
			LD	A,(cl_sv)
			JP	click
.a4:		CP	4
			JP	NZ,.a1
			CALL	size
			LD	A,(P_Y)
			ADD	A,B
			CP	0x17
			JP	NC,.fin
			LD	A,(P_YO)
			ADD	A,4
			AND	4
			LD	(P_YO),A
			JP	NZ,.fin
			LD	HL,P_Y
			INC	(HL)
			JP	.fin
.a1:		CP	1
			JP	NZ,.a2
			LD	A,(cl_sv)
			CP	0x0F
			JP	Z,.incx
			CALL	obst_right
			JP	Z,.s0e
			LD	A,0x0F
			JP	.sv
.incx:		LD	HL,P_X
			INC	(HL)
.s0e:		LD	A,0x0E
.sv:		LD	(cl_sv),A
			JP	.fin
.a2:		CP	2
			JP	NZ,.none
			LD	A,(cl_sv)
			CP	0x0F
			JP	Z,.s0e
			CALL	obst_left
			JP	Z,.s0e
			LD	HL,P_X
			DEC	(HL)
			LD	A,0x0F
			JP	.sv
.none:		LD	A,8
			LD	(P_DLY),A
			LD	A,(cl_sv)
			RET
.off:		LD	A,(P_YO)
			LD	B,A
			XOR	A
			LD	(P_YO),A
			LD	A,B
			OR	A
			JP	Z,.o11
			LD	HL,P_Y
			INC	(HL)
.o11:		LD	A,0x11
			RET
cl_sv:		DB	0

h_D10D:		LD	A,0x0F
			JP	climb

h_D112:		LD	A,(P_YO)
			OR	A
			JP	Z,.z
			ADD	A,2
			AND	6
			JP	NZ,.rec
			LD	HL,P_Y
			INC	(HL)
.rec:		LD	(P_YO),A
			LD	A,2
			LD	(P_DLY),A
			LD	A,0x11
			RET
.z:			CALL	floor_below
			LD	A,2
			JP	NZ,.rec
			IS_CUR	BRUCE
			JP	NZ,.e
			LD	HL,(P_X)			; Брюс активен: его X,Y — в рабочей копии (на ZX — CCAB)
			EX	DE,HL
			LD	HL,(zc_CB22)
			CALL	cmp_hl_de
			JP	Z,.bonus
			LD	HL,(zc_CBC4)
			CALL	cmp_hl_de
			JP	NZ,.e
.bonus:		LD	HL,zc_C96B
			CALL	add_score
.e:			LD	A,6
			LD	(P_DLY),A
			LD	A,1
			JP	click

h_D15D:		LD	HL,P_Y
			DEC	(HL)
			LD	A,7
			LD	(P_YO),A
			XOR	A
			LD	(P_DIR),A
			LD	(P_C0C),A
			LD	A,0x0D
			RET

h_D16F:		LD	A,(P_DMG)
			CP	0x0A
			JP	NC,h_D1A2
			LD	A,0x0A
			LD	(P_DLY),A
			LD	A,(P_DIR)
			RRCA
			JP	C,.l
			CALL	obst_left_edge
			LD	A,1
			RET	Z
			LD	HL,P_X
			DEC	(HL)
			LD	A,0x14
			RET
.l:			CALL	obst_right_edge
			LD	A,1
			RET	Z
			LD	HL,P_X
			INC	(HL)
			LD	A,0x14
			RET

h_D198:		CALL	killcheck
			LD	A,1
			LD	(P_POSE),A
			RET

h_D1A2:		XOR	A
			LD	(P_C0C),A
			LD	A,3
			LD	(P_DLY),A
			LD	A,(P_DIR)
			RRCA
			JP	C,.l
			CALL	obst_left_edge
			JP	Z,h_D198
			LD	HL,P_X
			DEC	(HL)
			JP	.b8
.l:			CALL	obst_right_edge
			JP	Z,h_D198
.b8:		LD	A,6
			LD	(P_ST),A
			CALL	floor_below
			JP	Z,.f
			LD	HL,P_Y
			INC	(HL)
.f:			XOR	A
			LD	(P_YO),A
			LD	A,6
			RET

h_D1D2:		LD	D,9
			LD	HL,NINJA
			CALL	melee
			LD	D,9
			LD	HL,YAMO
			CALL	melee
			LD	D,9
			LD	HL,BRUCE
			CALL	melee
			LD	A,0x0F
			LD	(P_DLY),A
			LD	A,0x0B
			RET

; Z, если HL == DE
cmp_hl_de:	LD	A,H
			CP	D
			RET	NZ
			LD	A,L
			CP	E
			RET

; --- D1EB: урон — гибель и очки; CY = выжил -------------------------------------------------------------
killcheck:	LD	A,(P_DMG)
			CP	0x35
			JP	NC,.die
			LD	B,A
			IS_CUR	NINJA
			JP	NZ,.alive
			LD	A,B
			CP	0x23
			JP	C,.alive
.die:		LD	A,1
			LD	(P_DY),A
			XOR	A
			LD	(P_DMG),A
			IS_CUR	BRUCE
			JP	Z,.clr
			LD	A,(P_BON)
			OR	A
			RET	Z				; CY = 0
			IS_CUR	NINJA
			LD	HL,zc_C983
			JP	Z,.sc
			LD	HL,zc_C989
.sc:		CALL	add_score
.clr:		XOR	A
			LD	(P_BON),A
			RET					; CY = 0
.alive:		IS_CUR	BRUCE
			JP	Z,.ok
			LD	A,(P_BON)
			OR	A
			JP	Z,.ok
			LD	HL,zc_C977
			CP	8
			JP	NZ,.sc2
			LD	HL,zc_C971
.sc2:		CALL	add_score
.ok:		XOR	A
			LD	(P_BON),A
			SCF
			RET

; --- D375/D371: удар по HL (дом цели), урон D ----------------------------------------------------------
melee:		LD	A,D					; HL = цель, D = урон
			LD	(dmg),A
			LD	(tgt),HL
			EX	DE,HL				; DE = цель
			LD	HL,(pcur)
			CALL	cmp_hl_de
			RET	Z
			LD	HL,0x0A
			ADD	HL,DE
			LD	A,(HL)
			OR	A
			RET	NZ
			LD	HL,2
			ADD	HL,DE
			LD	A,(HL)
			OR	A
			RET	Z
			LD	HL,7
			ADD	HL,DE
			LD	B,(HL)				; Y цели
			LD	A,(P_Y)
			CP	B
			JP	Z,.row
			DEC	A
			CP	B
			RET	NZ
.row:		LD	HL,6
			ADD	HL,DE
			LD	B,(HL)				; X цели
			LD	A,(P_DIR)
			RRCA
			LD	A,(P_X)
			JP	C,.l
			INC	A
			CP	B
			JP	Z,.hr
			INC	A
			CP	B
			RET	NZ
.hr:		LD	C,1
			JP	.hit
.l:			CP	B
			JP	Z,.hl
			DEC	A
			CP	B
			RET	NZ
.hl:		LD	C,0
.hit:		LD	HL,3
			ADD	HL,DE
			LD	(HL),C
			LD	HL,0x0E
			ADD	HL,DE
			LD	A,(dmg)
			LD	B,A
			LD	A,(HL)
			ADD	A,B
			LD	(HL),A
			PUSH	HL
			IS_CUR	NINJA
			POP	HL
			JP	Z,.one
			LD	A,(HL)
			ADD	A,B
			LD	(HL),A
.one:		LD	HL,2
			ADD	HL,DE
			LD	(HL),0x13
			LD	HL,0
			ADD	HL,DE
			LD	(HL),1
			LD	A,(zv_FE9A)
			OR	A
			JP	Z,.ns
			LD	A,SND_HIT
			CALL	plat_sound
.ns:		IS_CUR	BRUCE
			JP	NZ,.nb
			LD	HL,(tgt)
			LD	DE,0x11
			ADD	HL,DE
			LD	A,(dmg)
			LD	(HL),A
.nb:		LD	A,(dmg)
			CP	8
			RET	NZ
			LD	A,3
			LD	(P_C0C),A
			RET
tgt:		DW	0
dmg:		DB	0

; --- D2EB: возвращение врага --------------------------------------------------------------------------
revive:		IS_CUR	BRUCE
			RET	Z
			LD	A,(zc_CCAC)
			LD	HL,0x600A
			CP	0x12
			JP	NC,.t
			LD	HL,0x602F
.t:			LD	A,(HL)
			AND	0x80
			RET	NZ
			PUSH	HL
			LD	HL,P_RSP
			DEC	(HL)
			POP	HL
			RET	NZ
			LD	A,(HL)
			AND	1
			LD	(P_DIR),A
			DEC	HL
			LD	A,(HL)
			LD	(P_Y),A
			DEC	HL
			LD	A,(HL)
			LD	(P_X),A
			LD	A,1
			LD	(P_DLY),A
			LD	(P_ST),A
			XOR	A
			LD	(P_YO),A
			LD	(P_DY),A
			IS_CUR	YAMO
			RET	NZ
.app:		LD	A,AI_APP			; Ямо после появления стоит: ZX 0x4B, CPC 0x0F (70C8)
			LD	(P_DLY),A
			JP	plat_appear			; звук появления Ямо (CPC 70C3; только вывод)

; --- D587: касание по точкам: HL = клетка карты, DE = байт кадра спрайта; NZ — касается ----------------
pix_collide:
			PUSH	DE
			LD	E,(HL)
			LD	D,0
			EX	DE,HL
			ADD	HL,HL
			ADD	HL,HL
			ADD	HL,HL
			EX	DE,HL
			LD	HL,(0x6000)
			ADD	HL,DE
			LD	A,(P_YO)
			LD	E,A
			LD	D,0
			ADD	HL,DE
			LD	B,H
			LD	C,L
			POP	DE					; DE = байт кадра в описателе (FEAC — описатель)
			PUSH	BC
			PUSH	DE
			LD	HL,(zv_FEAC)		; блок столкновений (точки ZX, байт на строку): сторона 1 — свой или зеркало
			LD	A,L
			CALL	spr_find
			LD	DE,spr_col
			ADD	HL,DE
			LD	A,(P_DIR)
			RRCA
			LD	A,0
			JP	NC,.s0
			INC	HL
			INC	HL
			LD	A,(HL)
			INC	HL
			OR	(HL)
			DEC	HL
			LD	A,0
			JP	NZ,.s0
			DEC	HL					; 0 — зеркало стороны 0
			DEC	HL
			INC	A
.s0:		LD	(pc_mir),A
			LD	A,(HL)
			INC	HL
			LD	H,(HL)
			LD	L,A
			LD	(pc_blk),HL
			POP	DE
			LD	HL,(zv_FEAC)		; клетка idx = ряд*w + столбец
			LD	A,E
			SUB	L
			SUB	2
			LD	C,A
			LD	B,(HL)				; w
			INC	HL
			LD	A,(HL)				; h -> шаг столбца 8h
			ADD	A,A
			ADD	A,A
			ADD	A,A
			LD	E,A
			LD	HL,(pc_blk)
			LD	D,0
			LD	A,C
.dv:		CP	B					; ряд: + 8
			JP	C,.dd
			SUB	B
			PUSH	DE
			LD	DE,8
			ADD	HL,DE
			POP	DE
			JP	.dv
.dd:		LD	C,A					; столбец (у зеркала — w-1-столбец): + 8h
			LD	A,(pc_mir)
			OR	A
			JP	Z,.mc
			LD	A,B
			DEC	A
			SUB	C
			LD	C,A
.mc:		DEC	C
			JP	M,.me
			ADD	HL,DE
			JP	.mc
.me:		POP	BC
.l:			LD	A,(pc_mir)
			OR	A
			LD	A,(HL)
			CALL	NZ,rev8
			LD	E,A
			LD	A,(BC)
			AND	E
			RET	NZ
			INC	HL
			INC	C
			LD	A,C
			AND	7
			JP	NZ,.l
			RET
pc_blk:		DW	0
pc_mir:		DB	0
; A -> A с обратным порядком битов; портит D
rev8:		PUSH	HL
			LD	L,A
			LD	D,8
.l:			LD	A,L
			RLA
			LD	L,A
			LD	A,H
			RRA
			LD	H,A
			DEC	D
			JP	NZ,.l
			POP	HL
			RET
; младший байт описателя A -> HL = 4*номер (смещение в spr_ptr / spr_col), B = вид (0 Ниндзя, 1 Ямо, 2 Брюс)
spr_find:	LD	HL,spr_lo
			LD	B,SPR_N
.l:			CP	(HL)
			JP	Z,.f
			INC	HL
			DEC	B
			JP	NZ,.l
			LD	HL,0
			LD	B,L
			RET
.f:			LD	DE,SPR_N			; spr_k — сразу за spr_lo
			ADD	HL,DE
			LD	B,(HL)
			LD	DE,-spr_k
			ADD	HL,DE
			ADD	HL,HL
			ADD	HL,HL
			RET
; описатель кадра HL, сторона C (бит 0) -> HL = видимый блок (заголовок vx, vw, vy, vh, столбцы по 2 байта на
; строку); кадры ходьбы (wk_lo) — вариант по фазе m = x mod 3 (sb_x; взгляд влево — (3 - m) mod 3); портит A, B, DE
spr_block:	LD	A,L
			LD	HL,wk_lo
			LD	B,WK_N
.w:			CP	(HL)
			JP	Z,.wk
			INC	HL
			DEC	B
			JP	NZ,.w
			CALL	spr_find
			LD	DE,spr_ptr
			ADD	HL,DE
			LD	A,C
			RRCA
			JP	NC,.s0
			INC	HL
			INC	HL
.s0:		LD	A,(HL)
			INC	HL
			LD	H,(HL)
			LD	L,A
			RET
.wk:		LD	DE,-wk_lo			; запись wk_ptr + 12*i, модуль фазы wk_mod[i] (3 или 2)
			ADD	HL,DE
			PUSH	HL
			LD	D,H
			LD	E,L
			ADD	HL,HL
			ADD	HL,DE
			ADD	HL,HL
			ADD	HL,HL
			LD	DE,wk_ptr
			ADD	HL,DE
			POP	DE
			PUSH	HL
			LD	HL,wk_mod
			ADD	HL,DE
			LD	B,(HL)
			POP	HL
			LD	A,(sb_x)
.m:			CP	B
			JP	C,.md
			SUB	B
			JP	.m
.md:		PUSH	AF
			LD	A,C
			RRCA
			JP	NC,.s0w
			LD	DE,6				; сторона 1; при модуле 3 — (3 - m) mod 3 (чётность от знака не зависит)
			ADD	HL,DE
			LD	A,B
			CP	3
			JP	NZ,.s0w
			POP	AF
			OR	A
			JP	Z,.ms
			CPL
			ADD	A,4
			JP	.ms
.s0w:		POP	AF
.ms:		ADD	A,A
			LD	E,A
			LD	D,0
			ADD	HL,DE
			LD	A,(HL)
			INC	HL
			LD	H,(HL)
			LD	L,A
			RET
sb_x:		DB	0
			INCLUDE	"gen/sprtab.asm"

; --- D4EC: объекты под персонажем ------------------------------------------------------------------------
objects:	CALL	cell
			CALL	size
			PUSH	HL
			LD	HL,(zv_FEAC)
			INC	HL
			INC	HL
			EX	DE,HL
			POP	HL
.cell:		LD	A,(HL)
			CP	0x17
			JP	Z,.trick
			JP	NC,.nx
			CP	0x10
			JP	C,.danger
			; 10..16: предмет (берёт только Брюс)
			PUSH	BC
			PUSH	DE
			PUSH	HL
			IS_CUR	BRUCE
			JP	NZ,.pop
			POP	HL
			PUSH	HL
			CALL	pix_collide
			JP	Z,.pop
			LD	HL,zc_C97D
			CALL	add_score
			LD	A,(zv_FE9A)
			OR	A
			JP	Z,.nk
			LD	A,SND_KEY
			CALL	plat_sound
.nk:		POP	HL
			PUSH	HL
			LD	DE,0xA000			; HL - 0x6000
			ADD	HL,DE
			LD	A,L
			AND	0x1F
			LD	E,A				; столбец
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
			LD	H,A				; строка
			LD	L,E
			PUSH	HL
			LD	A,(zv_FE03)
			CALL	will_apply
			POP	DE
			LD	HL,zc_D7D4
			CALL	room_dispatch
			JP	.pop
.trick:		PUSH	BC
			PUSH	DE
			PUSH	HL
			EX	DE,HL
			LD	HL,zc_D7FC
			CALL	room_dispatch
			JP	.pop
.danger:	PUSH	BC
			PUSH	DE
			PUSH	HL
			CALL	pix_collide
			JP	Z,.pop
			LD	A,1
			LD	(P_DY),A
			LD	A,(P_ST)
			LD	(P_POSE),A
.pop:		POP	HL
			POP	DE
			POP	BC
.nx:		INC	HL
			INC	DE
			DEC	C
			JP	NZ,.cell
			LD	A,(zv_FEA4)
			LD	C,A
			LD	A,0x20
			SUB	C
			PUSH	DE
			LD	E,A
			LD	D,0
			ADD	HL,DE
			POP	DE
			DEC	B
			JP	NZ,.cell
			RET

; --- D675: желаемое действие ---------------------------------------------------------------------------
ai:			LD	A,(zv_FE11)			; читается для всех трёх
			LD	B,A
			IS_CUR	BRUCE
			LD	A,B
			RET	Z
			LD	A,(zv_FE08)
			OR	A
			JP	Z,.cpu
			IS_CUR	YAMO
			JP	NZ,.cpu
			LD	A,(zv_FE06)
			CP	6
			JP	C,.p2
			LD	A,6
			LD	(zv_FE06),A
			JP	.cpu
.p2:		LD	A,(zv_FE12)
			OR	A
			RET	Z
			XOR	A
			LD	(zv_FE06),A
			LD	A,(zv_FE12)
			RET
.cpu:		LD	A,(P_ST)
			CP	4
			JP	C,.d6d4
			CP	0x0C
			JP	C,.zero
			CP	0x10
			JP	C,.d6b2
.zero:		XOR	A
			RET
.d6b2:		CALL	ceiling_above
			JP	Z,.face
			LD	A,(P_YO)
			OR	A
			JP	NZ,.r8
			CALL	obst_left
			JP	Z,.r8
			CALL	obst_right
			JP	Z,.r8
			LD	A,(P_Y)
			LD	B,A
			LD	A,(zc_CCAC)
			CP	B
			JP	Z,.near
			JP	NC,.face
.r8:		LD	A,8
			RET
.d6d4:		LD	A,(P_Y)
			LD	B,A
			LD	A,(zc_CCAC)
			CP	B
	IFDEF	AI_CPC						; CPC (6F70): Брюс выше врага до 8 точек (прыжок) — тоже «в ряду»;
			JP	Z,.near				; run80 --ship ставит на .ytol NOP — ряд как у ZX
.ytol:		INC	A
			CP	B
	ENDIF
			JP	NZ,.d742
.near:
	IFDEF	AI_CPC
			JP	ai_cpc				; боевой образ: ближний бой как у CPC (src/vec/aicpc.asm); run80 --ship
	ENDIF							; переводит переход на .nzx — сверка с ZX
.nzx:		LD	A,(P_X)
			LD	B,A
			LD	A,(zc_CCAB)
			SUB	2
			CP	B
			JP	NZ,.n2
			XOR	A
			LD	(P_DIR),A
			LD	A,0x10
			RET
.n2:		SUB	2
			CP	B
			JP	NZ,.n3
			LD	A,0x11
			RET
.n3:		ADD	A,6
			CP	B
			JP	NZ,.n4
			LD	A,1
			LD	(P_DIR),A
			LD	A,0x10
			RET
.n4:		ADD	A,2
			CP	B
			JP	NZ,.face
			LD	A,0x12
			RET
.face:		LD	A,(P_X)
			LD	B,A
			LD	A,(zc_CCAB)
			CP	B
			LD	A,(P_DIR)
			JP	C,.lt
			RRCA
			JP	C,.turn
			JP	.walk
.lt:		RRCA
			JP	NC,.turn
.walk:		CALL	obst_ahead
			LD	A,0
			RET	Z
			LD	A,(P_DIR)
			RRCA
			LD	A,1
			RET	NC
			INC	A
			RET
.turn:		LD	A,(P_DIR)
			XOR	1
			LD	(P_DIR),A
.tdly:		LD	A,AI_TURN			; пауза разворота: ZX 0x32, CPC 0x0F (6FCF)
			LD	(P_DLY),A
			XOR	A
			RET
.d742:		LD	A,(P_Y)
			LD	B,A
			LD	A,(zc_CCAC)
			INC	A
			CP	B
			JP	NC,.d768
			IS_CUR	YAMO
			JP	NZ,.d768
			LD	HL,P_Y
			DEC	(HL)
			CALL	rope_under
			JP	NZ,.d765
			CP	2
			JP	NZ,.d765
			LD	HL,P_Y
			INC	(HL)
			LD	A,8
			RET
.d765:		LD	HL,P_Y
			INC	(HL)
.d768:		CALL	plat_rand
			AND	3
			JP	NZ,.d79d
			IS_CUR	NINJA
			LD	HL,(zc_CB22)
			JP	NZ,.d77c
			LD	HL,(zc_CBC4)
.d77c:		LD	A,(P_Y)
			CP	H
			JP	NZ,.d79d
			LD	A,(P_X)
			SUB	2
			CP	L
			JP	NZ,.d791
			LD	A,1
			LD	(P_DIR),A
			LD	A,0x10
			RET
.d791:		ADD	A,4
			CP	L
			JP	NZ,.d79d
			XOR	A
			LD	(P_DIR),A
			LD	A,0x10
			RET
.d79d:		CALL	obst_ahead
			JP	Z,.turn
			LD	A,(P_DIR)
			RRCA
			LD	A,1
			RET	NC
			INC	A
			RET

; --- D24E: шаг персонажа; HL = домашняя запись -----------------------------------------------------------
pers_step:	LD	(pcur),HL
			LD	DE,0x0A				; быстрый путь: не гибнет и задержка не кончилась — DEC (IX+0)
			ADD	HL,DE
			LD	A,(HL)
			LD	HL,(pcur)
			OR	A
			JP	NZ,.full
			LD	A,(HL)
			DEC	A
			JP	Z,.full
			LD	(HL),A
			RET
.full:		CALL	pw_in				; запись -> pw
			CALL	step_body
			JP	pw_store

step_body:	LD	A,(P_DY)
			OR	A
			JP	Z,.alive
			INC	A
			LD	(P_DY),A
			CP	2
			JP	NZ,.d264
			LD	B,A
			LD	A,(zv_FE9A)
			OR	A
			JP	NZ,.d271
			LD	A,B
.d264:		AND	2
			LD	A,0
			JP	NZ,.d26d
.d26a:		LD	A,(P_POSE)
.d26d:		LD	(P_ST),A
			RET
.d271:		IS_CUR	BRUCE
			JP	NZ,.d26a
			LD	A,0x4B
			LD	(P_DY),A
			LD	A,SND_DIE
			CALL	plat_sound
			JP	.d26a
.alive:		LD	HL,P_DLY
			DEC	(HL)
			RET	NZ
			LD	A,(P_SPD)
			LD	(HL),A
			LD	A,(P_ST)
			OR	A
			JP	Z,revive
			CALL	ai
			LD	(P_ACT),A
			CALL	objects
			LD	A,(P_ST)
			DEC	A
			ADD	A,A
			ADD	A,A
			ADD	A,0x18
			LD	E,A
			LD	D,0
			LD	HL,(pcur)
			ADD	HL,DE
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			LD	A,(P_X)
			LD	(st_x0),A
			LD	A,(P_Y)
			LD	(st_y0),A
			LD	A,(P_ST)
			EX	DE,HL
			CALL	jp_hl
			CALL	plat_state			; звук по смене состояния (только вывод; A сохраняется)
			LD	(P_ST),A
			LD	A,(st_x0)
			LD	B,A
			LD	A,(P_X)
			CP	B
			JP	C,.x1
			LD	A,B
.x1:		CP	0x1D
			JP	C,.x2
			LD	A,0x1C
.x2:		LD	(P_PX),A
			LD	A,(st_y0)
			LD	B,A
			LD	A,(P_Y)
			CP	B
			JP	C,.y1
			LD	A,B
.y1:		CP	0x14
			JP	C,.y2
			LD	A,0x13
.y2:		CP	2
			JP	NC,.y3
			LD	A,2
.y3:		LD	(P_PY),A
			RET
jp_hl:		JP	(HL)
st_x0:		DB	0
st_y0:		DB	0

; --- CAF7 / CAE2 (HL = домашняя запись; поля через указатель) ---------------------------------------------
	MACRO	FELL_EXPIRE rec, lbl			; CAF7 + CAE2 для записи rec: поля — абсолютные адреса
.fell:		LD	A,(rec+2)			; размер по позе (+16 + 4*(поза-1))
			DEC	A
			ADD	A,A
			ADD	A,A
			ADD	A,0x16
			LD	L,A
			LD	H,0
			LD	DE,rec
			ADD	HL,DE
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			EX	DE,HL
			LD	(zv_FEAC),HL
			LD	A,(HL)
			LD	(zv_FEA4),A
			INC	HL
			LD	B,(HL)
			LD	A,B
			LD	(zv_FEA5),A
			LD	A,(rec+7)
			ADD	A,B
			CP	0x17
			JP	C,.exp
			LD	A,(rec+4)
			CP	4
			JP	C,.exp
			LD	A,(rec+0x0A)
			OR	A
			JP	NZ,.exp
			LD	A,0x5F
			LD	(rec+0x0A),A
			LD	A,(rec+2)
			LD	(rec+0x0F),A
.exp:		LD	A,(rec+0x0A)
			CP	0x64
			RET	C
			XOR	A
			LD	(rec+0x0A),A
			LD	(rec+2),A
lbl:		LD	A,AI_RSP			; до возвращения: ZX 0x32 шагов, CPC 0x14 (74AD)
			LD	(rec+0x10),A
			LD	HL,rec
			JP	plat_show1			; C2F7: показать область сразу
	ENDM
fell_ninja:	FELL_EXPIRE	NINJA, rsp_ninja
fell_yamo:	FELL_EXPIRE	YAMO, rsp_yamo
