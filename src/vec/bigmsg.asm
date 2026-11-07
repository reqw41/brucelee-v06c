; bigmsg.asm: надписи GAME OVER и CONGRATULATIONS (владелец 07.11) — обычным шрифтом посередине поля на плашке цвета
; фона комнаты (бумага клетки — номер 0), без мигания; на итоговом экране под CONGRATULATIONS — легенда игры. Место — 9200.
; Блок: DB ширина плашки, строка экрана ZX + 1 (как char_cell), затем строки подряд: DB цвет (чернила, бумага 0), текст,
; 0; конец — FF. Цвет 6 — жёлтый, 4 — зелёный (общие во всех комнатах). Пустая строка (DB цвет, 0) — только плашка.

; HL = блок; портит всё
big_msg:	ld	b,(hl)				; B = ширина плашки
			inc	hl
			ld	d,(hl)				; D = строка
			inc	hl
.ln:		ld	c,(hl)				; C = цвет; FF — конец
			inc	hl
			ld	a,c
			inc	a
			jp	z,face_set			; конец (A = 0): лицо Брюса — обратно (кадры «со спины» нужны на лестнице)
			push	bc
			ld	a,32				; плашка: B клеток с (32 - B) / 2
			sub	b
			rra
			ld	e,a
.sp:		ld	a,' '
			call	bm_ch
			inc	e
			dec	b
			jp	nz,.sp
			pop	bc
			push	hl					; текст — посередине: с (32 - длина) / 2
			ld	e,32
.n:			ld	a,(hl)
			or	a
			jp	z,.nd
			inc	hl
			dec	e
			jp	.n
.nd:		pop	hl
			ld	a,e
			rra
			ld	e,a
.tx:		ld	a,(hl)
			inc	hl
			or	a
			jp	z,.nx
			call	bm_ch
			inc	e
			jp	.tx
.nx:		inc	d
			jp	.ln

; итоговый экран (комната 19): поздравление и легенда игры (Datasoft: пройти крепость, победить колдуна — его сокровища
; и секрет бессмертия). Шрифт — 32..95 без глифов, занятых кодом (" $ % & ( ) + / ; < = > ? [ \ ] ^ _)
	IFDEF	RUS
			INCLUDE	"../i8080/gen/ru_win.asm"	; русская версия (tools/mkru.py)
	ELSE
win_txt:	db	29, 7 + 1			; строки 7..13 — середина поля (0..21)
			db	6, 0
			db	4, 'CONGRATULATIONS!', 0
			db	6, 0
			db	6, 'THE WIZARD IS DEFEATED!', 0
			db	6, 'HIS TREASURE AND THE SECRET', 0
			db	6, 'OF IMMORTALITY ARE YOURS!', 0
			db	6, 0
			db	0xFF
	ENDIF
