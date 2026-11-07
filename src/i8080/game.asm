; Ход игры на i8080: перевод src/model/game.js (= ZX C7A4..C8C3, C93C, C99B, CA1A, CA46, C73C, DD67).

; --- C93C + C960: шапка: номер игрока и очки в FEB2.., FE0B = 1 ------------------------------------------
header:		LD	A,(zv_FE04)
			ADD	A,0x30
	IFDEF	RUS						; русская версия (07.11): шапка «И1 000000 РЕКОРД 000000 ЖИЗНИ 04» — номер,
			LD	(zv_FEB3),A			; очки и рекорд на клетку правее (подписи — шаблон FEB2, main.asm)
	ELSE
			LD	(zv_FEB2),A
	ENDIF
			LD	HL,zv_FEF2
			CP	0x31
			JP	Z,.c
			LD	HL,zv_FEF8
.c:	IFDEF	RUS
			LD	DE,zv_FEB5
	ELSE
			LD	DE,zv_FEB6
	ENDIF
			LD	B,6
.l:			LD	A,(HL)
			LD	(DE),A
			INC	HL
			INC	DE
			DEC	B
			JP	NZ,.l
header_msg:	LD	A,1
			LD	(zv_FE0B),A
			JP	plat_header

; --- CA1A: жизнь +1 -------------------------------------------------------------------------------------
lives_up:	LD	HL,(zv_FED0)		; L = старшая цифра, H = младшая
			LD	A,H
			INC	A
			CP	0x3A
			JP	C,.h
			INC	L
			LD	A,0x30
.h:			LD	H,A
			LD	A,L
			CP	0x3A
			JP	C,.s
			LD	HL,0x3939
.s:			LD	(zv_FED0),HL
			JP	header_msg

; --- C99B: очки HL (6 цифр ASCII) текущему игроку ----------------------------------------------------------
add_score:	PUSH	BC
			PUSH	DE
			LD	DE,zv_FEF2
			LD	A,(zv_FE04)
			CP	1
			JP	Z,.p
			LD	DE,zv_FEF8
.p:			LD	A,(DE)
			LD	(zv_FEAA),A
			INC	DE
			LD	A,(DE)
			LD	(zv_FEAB),A
			INC	DE
			INC	DE
			INC	DE
			INC	DE
			LD	BC,5
			ADD	HL,BC
			LD	BC,0x0600
.d:			LD	A,(DE)
			ADD	A,(HL)
			SUB	0x30
			ADD	A,C
			LD	C,0
			CP	0x3A
			JP	C,.nc
			SUB	0x0A
			LD	C,1
.nc:		LD	(DE),A
			DEC	DE
			DEC	HL
			DEC	B
			JP	NZ,.d
			LD	B,6
			INC	DE
	IFDEF	RUS
			LD	HL,zv_FEC3
	ELSE
			LD	HL,zv_FEC2
	ENDIF
.hi:		LD	A,(DE)
			CP	(HL)
			JP	C,.he
			JP	NZ,.cp
			INC	HL
			INC	DE
			DEC	B
			JP	NZ,.hi
			JP	.he
.cp:		LD	(HL),A
			INC	HL
			INC	DE
			LD	A,(DE)
			DEC	B
			JP	NZ,.cp
.he:		CALL	header
	IFDEF	RUS
			LD	HL,(zv_FEB5)
	ELSE
			LD	HL,(zv_FEB6)
	ENDIF
			EX	DE,HL
			LD	HL,(zv_FEAA)
			CALL	cmp_hl_de
			JP	Z,.x
			LD	A,D
			AND	0x0F
			JP	Z,.x
			DEC	A
			ADD	A,E
			AND	0x0F
			CP	0x0A
			JP	C,.k
			SUB	9
.k:			CP	3
			JP	Z,.life
			CP	6
			JP	Z,.life
			CP	9
			JP	NZ,.x
.life:		CALL	lives_up
.x:			POP	DE
			POP	BC
			RET

; --- C121: пауза, рестарт, звук — через платформу (A: бит 0 рестарт, 1 пауза, 2 звук) ---------------------------
check_keys:	CALL	plat_keys
			OR	A
			RET	Z
			JP	plat_menu_keys		; действие делает платформа (на ZX — меню, пауза, переключение звука)

; --- CAB6 ---------------------------------------------------------------------------------------------------
swap:		LD	A,(DE)
			LD	C,A
			LD	A,(HL)
			LD	(DE),A
			LD	(HL),C
			INC	HL
			INC	DE
			DEC	B
			JP	NZ,swap
			RET

; --- C790: шапка, комната игрока, загрузка ----------------------------------------------------------------------
next_player:
			CALL	header
			LD	HL,zv_FE0E
			LD	A,(zv_FE04)
			DEC	A
			JP	Z,.p
			INC	HL
.p:			LD	A,(HL)
			LD	(zv_FE03),A
			JP	room_load

; --- CA46: Брюс погиб -------------------------------------------------------------------------------------------
bruce_died:	LD	HL,(zv_FED0)		; L = FED0 (E), H = FED1 (D)
			LD	A,L
			CP	0x30
			JP	NZ,.live
			LD	A,H
			CP	0x30
			JP	Z,plat_game_over
.live:		DEC	H
			LD	A,H
			CP	0x30
			JP	NC,.s
			LD	H,0x39
			DEC	L
.s:			LD	(zv_FED0),HL
			CALL	header_msg
			LD	A,50
			CALL	plat_halts
			LD	A,(zc_CCAC)
			LD	HL,0x6008
			CP	0x12
			JP	NC,.t
			LD	HL,0x602D
.t:			LD	A,(HL)
			LD	(zc_CCAB),A
			INC	HL
			LD	A,(HL)
			LD	(zc_CCAC),A
			INC	HL
			LD	A,(HL)
			AND	1
			LD	(zc_CCA8),A
			XOR	A
			LD	(zc_CCA7),A
			LD	A,(zv_FE07)
			OR	A
			JP	Z,next_player
			LD	A,(zv_FE04)
			INC	A
			CP	2
			JP	Z,.pl
			LD	A,1
.pl:		LD	(zv_FE04),A
			LD	HL,zc_CCA5
			LD	DE,zv_FE81
			LD	B,0x12
			CALL	swap
			LD	HL,zv_FE20
			LD	DE,zv_FE40
			LD	B,0x20
			CALL	swap
			JP	next_player

; --- C73C: новый круг ---------------------------------------------------------------------------------------------
restart_level:
			LD	HL,0x0604
			LD	(zc_CCAB),HL
			LD	HL,zc_CCA5
			LD	DE,zv_FE81
			LD	B,0x12
.cp:		LD	A,(HL)
			LD	(DE),A
			INC	HL
			INC	DE
			DEC	B
			JP	NZ,.cp
			LD	HL,zv_FE20
			LD	B,0x40
			CALL	zero_b
			LD	HL,0x6400
.rm:		PUSH	HL
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			LD	HL,0x0C
			ADD	HL,DE
			LD	(HL),0
			INC	HL
			LD	(HL),0
			LD	HL,6
			ADD	HL,DE
			LD	E,(HL)
			INC	HL
			LD	D,(HL)
			EX	DE,HL
.k:			LD	A,(HL)
			OR	A
			JP	P,.k3
			CP	0xFF
			JP	Z,.kd
			OR	3
			LD	(HL),A
			INC	HL
.k3:		INC	HL
			INC	HL
			INC	HL
			JP	.k
.kd:		POP	HL
			LD	A,L
			ADD	A,2
			LD	L,A
			CP	0x28
			JP	C,.rm
			LD	HL,0
			LD	(zv_FE0E),HL
			JP	next_player

; --- DD67: финал ---------------------------------------------------------------------------------------------------
level_complete:
			LD	HL,zv_FE3E
			LD	A,(HL)
			INC	(HL)
			OR	A
			JP	NZ,.n0
			CALL	plat_win_msg		; надпись (вывод); C29C: FE0B = 0
			XOR	A
			LD	(zv_FE0B),A
			JP	.d77
.n0:
	IFDEF	VEC_WIN						; Вектор (владелец 07.11): прыжки, пока играет мелодия титула
.win_hook:								; run80 --ship: 4 байта -> NOP (логика ZX)
			CALL	plat_win_tick
			RET	C
	ENDIF
			CP	3
			JP	Z,.go
.d77:		XOR	A
			LD	(zv_FE11),A
			LD	(zv_FE12),A
			LD	(zc_CCA8),A
			INC	A
			LD	(zc_CCA5),A
			LD	A,0x10
			LD	(zc_CCA7),A
			RET
.go:		LD	A,SND_JINGLE
			CALL	plat_sound
			LD	A,1
			LD	(zv_FE0D),A
			LD	HL,(stack_top)		; как LD SP,FFFF на ZX: шаг кончается новым кругом
			LD	SP,HL
			CALL	restart_level
			JP	pass_end

; --- C7A4: один проход главного цикла --------------------------------------------------------------------------------
pass:		LD	HL,0
			ADD	HL,SP
			LD	(stack_top),HL
			CALL	check_keys
			XOR	A
			LD	(zv_FE0C),A
.w:			LD	HL,zv_FE02			; ждать кадр (флаг ставит прерывание)
.crit:		LD	A,(HL)				; .crit...crit_e: прерывание вернёт на .w (SRL (HL) на ZX неделим)
			OR	A
			JP	Z,.idle
			RRA
.crit_e:
			LD	(HL),A
			JP	NC,.w
			JP	.go
.idle:		CALL	plat_wait			; Вектор: EI / HALT
			JP	.w
.go:
			LD	A,(zv_FE0B)			; C29C: весь экран, иначе — прямоугольники персонажей (вывод)
			OR	A
			JP	Z,.show
			XOR	A
			LD	(zv_FE0B),A
			CALL	plat_screen
			JP	.er
.show:		CALL	plat_show
.er:		LD	HL,NINJA
			CALL	plat_erase
			LD	HL,YAMO
			CALL	plat_erase
			LD	HL,BRUCE
			CALL	plat_erase
			LD	HL,zc_D7AC
			CALL	room_dispatch
			LD	HL,zv_FE1A
			LD	A,(HL)
			LD	(HL),0
			OR	A
			JP	NZ,.c80b
			LD	HL,NINJA
			CALL	pers_step
			LD	HL,YAMO
			CALL	pers_step
			LD	HL,BRUCE
			CALL	pers_step
.c80b:		LD	A,(zc_CCAF)
			CP	0x64
			JP	NC,bruce_died
			CALL	fell_ninja			; CAF7 + CAE2: Ниндзя, Ямо
			CALL	fell_yamo
			LD	A,(zv_FE0C)
			OR	A
			JP	NZ,.c875
			LD	HL,BRUCE			; Брюс — прямо из его записи (без копии в pw)
			CALL	size_hl
			LD	A,(zc_CCAC)			; +07 y
			CP	3
			JP	NC,.c842
			LD	A,(zc_CCA9)			; +04 yo
			CP	4
			JP	C,.c875
.c842:		ADD	A,B
			CP	0x18
			JP	NC,.c875
			LD	A,(zc_CCA8)			; +03 сторона
			OR	A
			LD	A,(zc_CCAB)			; +06 x
			JP	Z,.c857
			OR	A
			JP	M,.c875
			JP	.draw
.c857:		ADD	A,C
			CP	0x21
			JP	NC,.c875
.draw:		LD	HL,NINJA
			CALL	plat_draw
			LD	HL,YAMO
			CALL	plat_draw
			LD	HL,BRUCE
			JP	plat_draw
.c875:		LD	E,0
			LD	A,(zc_CCAB)
			INC	A
			LD	B,A
			LD	A,(0x600E)
			CP	B
			JP	NC,.c889
			INC	E
			LD	A,(0x600F)
			CP	B
			JP	NC,.c889
			INC	E
.c889:		LD	A,(zc_CCAC)
			LD	B,A
			LD	A,(0x6010)
			CP	B
			JP	NC,.c89e
			INC	E
			INC	E
			INC	E
			LD	A,(0x6011)
			CP	B
			JP	NC,.c89e
			INC	E
			INC	E
			INC	E
.c89e:		LD	A,E
			ADD	A,A
			ADD	A,E
			LD	C,A
			LD	B,0
			LD	HL,0x6012
			ADD	HL,BC
			LD	DE,zv_FE0E
			LD	A,(zv_FE04)
			DEC	A
			JP	Z,.p1
			INC	DE
.p1:		LD	A,(HL)
			CP	0xFF
			JP	Z,bruce_died
			LD	(DE),A
			INC	HL
			LD	A,(HL)
			LD	(zc_CCAB),A
			INC	HL
			LD	A,(HL)
			LD	(zc_CCAC),A
			JP	next_player
pass_end:	RET
stack_top:	DW	0
