; logo.asm: логотип BRUCE LEE в полосе под полем (title.asm, plat.asm boot).
; ---- логотип BRUCE LEE под игровым полем (владелец 06.11): полоса строк 224..255 — чёрная (номер 1), логотип 144 x 24
;      жёлтым (номер 6) с x = 56, y = 228. Логотип живёт в экранной памяти: при запуске — из 5B50 (дальше 5B50 свободна
;      под буферы), на титуле — полоса -> LOGO_BUF (карта 6040, на титуле не нужна), при старте игры — обратно в полосу.
;      Формат источника — как t_block: клетки по рядам (3 x 18), 8 байт сверху вниз.
LOGO_BUF	equ	0x6040
LG_X		equ	7
LG_Y		equ	228
lg_band:	ld	h,0xA0				; DE = источник; полоса: A000, C000 = 0, E000 = FF
.f:			ld	l,0
.fl:		ld	a,h
			cp	0xE0
			sbc	a,a
			cpl
			ld	(hl),a
			inc	l
			ld	a,l
			cp	32
			jp	nz,.fl
			inc	h
			jp	nz,.f
			ld	c,255-LG_Y
.r:			ld	b,LG_X
.c:			ld	a,0xA0
			add	a,b
			ld	h,a
			ld	l,c
			push	bc
			ld	b,8
.k:			ld	a,(de)				; байт логотипа (C — временно, BC сохранён)
			inc	de
			ld	c,a
			ld	(hl),a				; A000
			ld	a,h
			add	a,0x20
			ld	h,a
			ld	(hl),c				; C000
			ld	a,h
			add	a,0x20
			ld	h,a
			ld	a,c
			cpl
			ld	(hl),a				; E000 — чёрная бумага вокруг букв
			ld	a,h
			sub	0x40
			ld	h,a
			dec	l
			dec	b
			jp	nz,.k
			pop	bc
			inc	b
			ld	a,b
			cp	LG_X+18
			jp	nz,.c
			ld	a,c
			sub	8
			ld	c,a
			cp	255-LG_Y-24
			jp	nz,.r
			ret
	MACRO	LG_TAKE
lg_take:	ld	de,LOGO_BUF			; полоса (A000) -> LOGO_BUF
			ld	c,255-LG_Y
.r:			ld	b,LG_X
.c:			ld	a,0xA0
			add	a,b
			ld	h,a
			ld	l,c
			push	bc
			ld	b,8
.k:			ld	a,(hl)
			ld	(de),a
			inc	de
			dec	l
			dec	b
			jp	nz,.k
			pop	bc
			inc	b
			ld	a,b
			cp	LG_X+18
			jp	nz,.c
			ld	a,c
			sub	8
			ld	c,a
			cp	255-LG_Y-24
			jp	nz,.r
			ret
	ENDM
