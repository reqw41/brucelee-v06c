; tilefix.asm: цвета отдельных тайлов по комнатам (вызов — plat_room до атрибутов)
; ---- цвета тайлов по комнатам (владелец 06.11, как CPC): таблица цветов 6300 — только для вывода (логика ZX её не
;      читает), правится после загрузки комнаты. Запись: комната (FE — любая), атрибут, первый и последний тайл.
; Атрибут с битом 7: 80 | (X << 3) | Y — в клетках тайла с чернилами X чернила -> Y (бумага и прочее как есть).
;      Лестница 18/19 — жёлтая (6), в комнатах 0, 2, 16 (у CPC — лиана) — зелёная (4); мечи 0..3 в комнатах 7, 8 —
;      номер 2 (белый в палитре этих комнат); в комнате 8 номер 2 держали чёрные 8d..8f — на чёрный номер 1
tfix:		db	0xFE,0x46,0x18,0x19
			db	0,0x44,0x18,0x19
			db	2,0x44,0x18,0x19
			db	16,0x44,0x18,0x19
			db	12,0x46,0x1C,0x1E		; диагональные лестницы 12, 13 — жёлтые (у CPC жёлтые)
			db	13,0x46,0x1C,0x1E
			db	7,0x42,0x00,0x03
			db	8,0x42,0x00,0x03
			db	8,0x41,0x8D,0x8F
			; 18: цвета колдуна (тайлы AB..EF есть только в комнате 18) — при сборке в таблице (gen/room18attr.asm)
			db	19,0x80|(6<<3)|3,0x22,0x24	; 19: «золото» на водопадах (жёлтое) -> 3 (голубой, как вода CPC)
			db	19,0x80|(6<<3)|3,0x30,0x30
			db	19,0x80|(6<<3)|3,0xFA,0xFE
			db	0xFF
; таблица цветов 6300 общая на всю игру (room_load её не перезаписывает): перед правками комнаты — исходные цвета ZX
; всех тайлов, которые tile_fix трогает (иначе правки одной комнаты остаются в следующих, а замена чернил в комнате 18
; копилась с каждым входом — 06.11). Запись: первый тайл, число, исходные атрибуты ZX
tf_orig:	db	0x00,4
			INCBIN	"../../build/zx_tap.bin", 0x6300, 4
			db	0x18,2
			INCBIN	"../../build/zx_tap.bin", 0x6318, 2
			db	0x1C,3
			INCBIN	"../../build/zx_tap.bin", 0x631C, 3
			db	0x22,3
			INCBIN	"../../build/zx_tap.bin", 0x6322, 3
			db	0x30,1
			INCBIN	"../../build/zx_tap.bin", 0x6330, 1
			db	0x8D,3
			INCBIN	"../../build/zx_tap.bin", 0x638D, 3
			db	0xFA,5
			INCBIN	"../../build/zx_tap.bin", 0x63FA, 5
			db	0,0					; конец: тайл, число 0
tile_fix:	ld	a,(r18_on)			; колдун комнаты 18: сначала вернуть заёмные номера (до восстановления цветов),
			or	a					; после — занять снова, если это комната 18
			call	nz,r18_swap
			ld	hl,tf_orig
.or:		ld	e,(hl)				; тайл
			inc	hl
			ld	a,(hl)				; число (0 — конец)
			inc	hl
			or	a
			jp	z,.od
			ld	b,a
			ld	d,0x63
.oc:		ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	e
			dec	b
			jp	nz,.oc
			jp	.or
.od:		ld	a,(zv_FE03)
			cp	18
			call	z,r18_swap
			ld	a,(zv_FE03)
			ld	c,a
			ld	hl,tfix
.l:			ld	a,(hl)
			cp	0xFF
			ret	z
			inc	hl
			cp	c
			jp	z,.y
			cp	0xFE
			jp	z,.y
			inc	hl
			inc	hl
			inc	hl
			jp	.l
.y:			ld	b,(hl)				; атрибут
			inc	hl
			ld	e,(hl)				; первый тайл
			inc	hl
			ld	a,(hl)				; последний
			inc	hl
			push	hl
			ld	h,a
			ld	a,(0x6003)
			ld	d,a
.t:			ld	a,b				; бит 7 — только где чернила (биты 3..5) — заменить на биты 0..2
			or	a
			jp	p,.w
			ld	a,(de)
			and	7
			push	bc
			ld	c,a
			ld	a,b
			rrca
			rrca
			rrca
			and	7
			cp	c
			pop	bc
			jp	nz,.n
			ld	a,(de)
			and	0xF8
			push	bc
			ld	c,a
			ld	a,b
			and	7
			or	c
			pop	bc
.w:			ld	(de),a
.n:			ld	a,e
			inc	e
			cp	h
			jp	nz,.t
			pop	hl
			jp	.l

; ---- колдун комнаты 18 по рисунку владельца (06.11, tools/mkroom18tiles.py): R18_N проходимых номеров других комнат
;      на время комнаты 18 «заняты» — их узор (9800) и цвет (6300) меняются местами с запасом R18_ST (при запуске — из
;      ZX0 вместе с логотипом, plat.asm boot). Запас: узоры R18_N x 8, цвета R18_N, номера R18_N, флаг r18_on.
;      Обмен туда-обратно один и тот же, флаг переключается.
R18_ST		equ	0x5B50
r18_on		equ	R18_ST+R18_N*10
r18_swap:	ld	hl,r18_on
			ld	a,(hl)
			xor	1
			ld	(hl),a
			ld	bc,R18_ST			; узоры
			ld	de,R18_ST+R18_N*8	; цвета (+R18_N — номера)
.t:			push	de
			ld	hl,R18_N
			add	hl,de
			ld	l,(hl)				; номер тайла
			ld	h,0x63
			ld	a,(de)				; цвет <-> 6300+номер
			push	af
			ld	a,(hl)
			ld	(de),a
			pop	af
			ld	(hl),a
			ld	h,0x13				; узор: (1300 + номер) * 8 = 9800 + номер * 8
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	e,8
.p:			ld	a,(bc)
			ld	d,(hl)
			ld	(hl),a
			ld	a,d
			ld	(bc),a
			inc	bc
			inc	hl
			dec	e
			jp	nz,.p
			pop	de
			inc	de
			ld	a,e
			cp	low (R18_ST+R18_N*9)
			jp	nz,.t
			ret
