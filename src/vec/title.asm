; title.asm: титул и меню (C4B8, C530), начало игры (C714) — перевод ZX.
; Экран титула — карта символов CMAP (768, код клетки: 0 пусто, 32..127 шрифт, 128.. — клетки картинок D825,
; источник в BLK_SRC) и атрибуты amap; tp_all рисует всё (как C29C), t_fill — атрибуты сразу на экране
; (меню ZX пишет их прямо в 5800).

; C8C6: всё пусто, атрибуты 38
t_clear:	ld	hl,CMAP
			ld	de,amap
			ld	bc,768
.l:			ld	(hl),0
			ld	a,0x38
			ld	(de),a
			inc	hl
			inc	de
			dec	bc
			ld	a,b
			or	c
			jp	nz,.l
			ld	a,128
			ld	(blk_next),a
			ld	a,0xFF				; шапку потом рисовать заново
			ld	(hs_at),a
			ld	(hs_at+1),a
			ret
blk_next:	db	128
; C924: текст HL, позиция DE (0..767), B символов
t_text:		push	hl
			ld	hl,CMAP
			add	hl,de
			ex	de,hl
			pop	hl
.l:			ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	de
			dec	b
			jp	nz,.l
			ret
; D825: картинка HL (по 8 байт на клетку), позиция DE, B строк, C столбцов
t_block:	push	hl
			ld	hl,CMAP
			add	hl,de
			ex	de,hl
			pop	hl
.r:			push	bc
			push	de
.c:			ld	a,(blk_next)
			ld	(de),a
			inc	de
			push	de
			push	hl
			sub	128
			ld	l,a
			ld	h,0
			add	hl,hl
			ld	de,BLK_SRC
			add	hl,de
			pop	de					; DE = источник
			ld	(hl),e
			inc	hl
			ld	(hl),d
			ex	de,hl
			ld	de,8
			add	hl,de
			pop	de
			ld	a,(blk_next)
			inc	a
			ld	(blk_next),a
			dec	c
			jp	nz,.c
			pop	de
			push	hl
			ld	hl,32
			add	hl,de
			ex	de,hl
			pop	hl
			pop	bc
			dec	b
			jp	nz,.r
			ret
; атрибуты: позиция HL, B клеток, значение C (только в amap)
t_attr:		ld	de,amap
			add	hl,de
.l:			ld	(hl),c
			inc	hl
			dec	b
			jp	nz,.l
			ret
; то же и сразу на экран
t_fill:		push	hl
			push	bc
			call	t_attr
			pop	bc
			pop	hl
.l:			push	hl
			push	bc
			call	tp_cell
			pop	bc
			pop	hl
			inc	hl
			dec	b
			jp	nz,.l
			ret
; C29C для титула: все клетки
tp_all:		ld	hl,0
.l:			push	hl
			call	tp_cell
			pop	hl
			inc	hl
			ld	a,h
			cp	3
			jp	nz,.l
			ret
; клетка HL (0..767)
tp_cell:	push	hl
			ld	de,amap
			add	hl,de
			ld	a,(hl)
			ld	(tc_at),a
			pop	hl
			push	hl
			ld	de,CMAP
			add	hl,de
			ld	a,(hl)
			ld	de,zero8
			or	a
			jp	z,.s
			cp	128
			jp	nc,.b
			sub	32
			jp	c,.s
			ld	l,a
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	de,FONT
			add	hl,de
			ex	de,hl
			jp	.s
.b:			sub	128
			ld	l,a
			ld	h,0
			add	hl,hl
			ld	de,BLK_SRC
			add	hl,de
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
.s:			pop	hl					; экран: H = E0 + столбец, L = 223 - 8*строка
			ld	a,l
			and	0x1F
			add	a,0xE0
			ld	b,a
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	a,h					; строка
			add	a,a
			add	a,a
			add	a,a
			cpl
			add	a,SCR_Y0+1
			ld	l,a
			ld	h,b
			ld	a,(tc_at)
			call	attr_fix
			jp	plain_cell
tc_at:		db	0
zero8		equ	pal_black			; источник пустой клетки (8 нулей): вывод идёт по нему через inc e — в одной
			ASSERT	high zero8 = high (zero8 + 7)	; странице (06.11: ds 8 сдвинулся на FE — мусор на титрах)

; C8E1: экран титула
t_init:		call	t_clear
			ld	hl,LOGO_BUF			; (06.11: логотип — из полосы под полем, lg_take; титул на ряд выше, «PRESS SPACE…» под полем)
			ld	de,0x0047
			ld	bc,0x0312
			call	t_block
			ld	hl,0x0040
			ld	b,0x60
			ld	c,0x3A
			call	t_attr
	IFDEF	RUS
			ld	hl,ru_t0				; «ДАТАСОФТ ПРЕДСТАВЛЯЕТ» (gen/ru_a.asm)
			ld	de,RU_T0_P
			ld	b,RU_T0_N
	ELSE
			ld	hl,zv_FB00
			ld	de,0x0007
			ld	b,0x12
	ENDIF
			jp	t_text

; C4B8: включение / конец игры (звук вкл.); C4BD: рестарт клавишей
title_start:
			ld	a,1
			ld	(zv_FE9A),a
title_restart:
			ld	sp,STACK
			ld	a,7
			ld	(0x600B),a
			ld	(border),a
			xor	a
			ld	(wf_on),a
			call	lg_take				; логотип BRUCE LEE из полосы под полем -> LOGO_BUF (титул её закрасит)
			call	t_init
			call	t_lines				; строки титула — таблицей (hi9540.asm, 07.11)
			call	tp_title
	IFDEF	RUS
			ld	hl,ru_st1
	ELSE
			ld	hl,st1				; клавиша старта — красным под полем ZX (ряд 24, строки 224..231 Вектора)
	ENDIF
			ld	de,25*256+ST1_C0	; (char_cell рисует на ряд выше D); столбцы ST1_C0..ST1_C1-1
.st:		ld	a,(hl)
			push	hl
			push	de
			ld	c,0x3A
			call	char_cell
			pop	de
			pop	hl
			inc	hl
			inc	e
			ld	a,e
			cp	ST1_C1
			jp	nz,.st
			call	snd_music_on		; музыка CPC (титул 7E3B) — два прохода (2 x 18,7 с), дальше тишина
.rl:		ld	a,1					; пробел / огонь, которым ушли с заставки или GAME OVER, — не старт:
			call	snd_frames			; ждать, пока отпустят
			ld	a,(p1dir)
			and	0x10
			jp	nz,.rl
			ld	de,2*936
.tw:		ld	a,1
			call	snd_frames
			call	tw_keys				; пробел / огонь / 1 — один игрок, 2 — двое, Ф1+Ф3 — с читом (cheat.asm)
			ld	a,d
			or	e
			jp	z,.tw
			dec	de
			ld	a,d
			or	e
			jp	nz,.tw
			call	snd_music_off
			jp	.tw
.go:		ld	hl,zv_FE02			; как меню ZX при входе (C5BC): FE02..FE18 = 0 — один игрок, Ямо — компьютер,
			ld	b,0x17				; способ — клавиатура (у неё стрелки, пробел и джойстик «П»); FE0A = 4 — второго
			call	zero_b				; игрока нет; FE15 — как после ENTER меню
			ld	a,4
			ld	(zv_FE0A),a
			ld	a,0x21
			ld	(zv_FE15),a
			call	go_2p				; двое: FE08 = 1 (Ямо — игрок), FE0A = 2 (Kempston — «П» Б)
			call	key_release
			jp	start_game
; показ титула: палитра игры, все клетки
tp_title:	ld	h,0xA0				; полосы вне поля ZX (строки 0..31, 224..255) — серые (номер 7), как экран CPC
.g:			ld	l,0
			ld	a,0xFF
.b:			ld	(hl),a
			inc	l
			ld	a,l
			cp	32
			ld	a,0xFF
			jp	nz,.b
			ld	l,224
.t:			ld	(hl),a
			inc	l
			jp	nz,.t
			inc	h
			jp	nz,.g
			ld	hl,pal_title
			call	pal_set
			jp	tp_all

; C530: меню
; C714: новая игра
start_game:	ld	sp,STACK
			ld	de,LOGO_BUF			; полоса с логотипом под полем — до загрузки комнаты (она затрёт 6040)
			call	lg_band
			call	snd_music_off		; музыка CPC — только титул и меню
			ld	a,1
			ld	(zv_FE04),a
			ld	hl,zv_FEF2
			ld	b,12
.s:			ld	(hl),0x30
			inc	hl
			dec	b
			jp	nz,.s
			ld	hl,0x3430
			ld	a,(zv_FE07)
			or	a
			jp	z,.l
			ld	h,0x39
.l:			ld	(zv_FED0),hl
			ld	a,5
			ld	(zv_FE95),a
			ld	hl,0
			ld	(zv_FE05),hl
			ld	a,0x38
			ld	(hdr1),a
			ld	a,1					; бордюр — чёрный (номер 1 палитры игры)
			ld	(border),a
			xor	a
			ld	(want+0),a
			ld	(want+8),a
			ld	(want+16),a
			ld	(disp+0),a
			ld	(disp+8),a
			ld	(disp+16),a
			dec	a
			ld	(pd_dirs),a
			ld	(pd_dirs+1),a
			ld	(pd_dirs+2),a
			call	restart_level
game_loop:	call	pass
			jp	game_loop


