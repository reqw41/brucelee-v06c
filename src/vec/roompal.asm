; roompal.asm: палитры комнат как у CPC (решение владельца 06.11). Страница 0 (0040..): между переходами 0000/0038
; свободно. Номер палитры = цвет ZX тайла; 1 (чёрный), 4 (зелёный), 6 (жёлтый) — персонажи, шапка и бордюр, не меняются.
; Комната: 5 байт — номера 0 (фон), 2, 3, 5, 7. Подбор: снимки 20 комнат CPC с модели (build/cpc/rooms_cpc_real.png),
; голосование цвета CPC под каждым номером при лучшем совмещении экранов + правка на глаз (build/cpc/rooms_recolor.png).
; Наши 5..8 = CPC 8, 5, 6, 7 (раскладка).
roompal:	db	0x5B,0x07,0xC7,0xC4,0xFF	; 0  серый, горы (как CPC 0..2)
			db	0x5B,0x07,0xC7,0xC4,0xFF	; 1
			db	0x5B,0x07,0xC7,0xC4,0xFF	; 2
			db	0xE4,0x80,0x80,0x00,0x80	; 3  голубой, синие решётки (CPC 3)
			db	0xE4,0x07,0x00,0x00,0x84	; 4  голубой (CPC 4)
			db	0xE4,0x00,0xC7,0xA4,0xFF	; 5  голубой, пагода (CPC 8)
			db	0x07,0x84,0xC7,0x00,0x84	; 6  красный (CPC 5)
			db	0x07,0xFF,0x80,0x80,0x80	; 7  красный (CPC 6)
			db	0x07,0xFF,0x80,0x80,0x80	; 8  красный (CPC 7)
			db	0x5B,0x07,0xC7,0xC4,0xFF	; 9  серый, небо (CPC 9)
			db	0x5B,0x07,0x00,0x00,0xFF	; 10 серый, чёрно-белые балки (CPC 10, 12..14)
			db	0x87,0x04,0x00,0x00,0x00	; 11 малиновый (CPC 11)
			db	0x5B,0x07,0x00,0x00,0xFF	; 12
			db	0x5B,0x07,0x00,0x00,0xFF	; 13
			db	0x5B,0x07,0x00,0x00,0xFF	; 14
			db	0xE4,0x07,0xC7,0x00,0xFF	; 15 голубой (CPC 15)
			db	0xE4,0x07,0xC7,0x05,0xFF	; 16 голубой (CPC 16); 5 — тёмно-красная башня (пагода, tilefix)
			db	0x5B,0xA0,0xC7,0xC4,0xA0	; 17 серый, сине-зелёный (CPC 17)
			db	0x40,0x07,0x07,0xC0,0x87	; 18 фон тёмно-синий (40 — самый тёмный) (владелец 07.11: Брюса на чёрном не видно), зал малиновый, колдун
			db	0x80,0x07,0xF8,0xC0,0xA4	; 19 тёмно-синий, белые стены (CPC 19)
; палитра комнаты zv_FE03 -> pal_room, загрузка (вместо pal_game)
room_pal:	ld	a,(zv_FE03)
			ld	l,a
			add	a,a
			add	a,a
			add	a,l
			ld	e,a
			ld	d,0
			ld	hl,roompal
			add	hl,de
			ex	de,hl
			ld	hl,pal_room
			ld	bc,0x0038			; C — зелёный (4)
			call	.b					; 0
			ld	(hl),b				; 1 — чёрный
			inc	hl
			call	.b					; 2
			call	.b					; 3
			ld	(hl),c				; 4
			inc	hl
			call	.b					; 5
			ld	(hl),0x3F			; 6 — жёлтый
			inc	hl
			call	.b					; 7
			ld	hl,pal_room			; 8..15 = 0..7
			ld	de,pal_room+8
			ld	b,8
.c:			ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	de
			dec	b
			jp	nz,.c
			ld	hl,pal_room
			jp	pal_set
.b:			ld	a,(de)
			inc	de
			ld	(hl),a
			inc	hl
			ret

