; Заставка Bruce Lee (tools/mksplash.py): образ 64 КБ с 0x0000. Показ картинки загрузки ZX в 16 цветах до
; клавиши (или огня джойстика «П»), затем — распаковка игры в 0000..9FFF и запуск с 0000.
			DEVICE	NOSLOT64K
			ORG	0x0000
			di
			ld	sp,0x0100
			jp	sp_entry
			ORG	0x0038
			ret						; будит HALT; дальше — с DI
			ORG	0x0040
sp_entry:	ld	a,0x88
			out	(0x00),a
			xor	a
			out	(0x02),a
			ld	a,0xFF
			out	(0x03),a
			ld	a,0x83				; джойстик «П»
			out	(0x04),a
			ld	a,0x9F
			out	(0x05),a
.w:			ei						; палитра — каждый кадр в обратном ходе (как в monty: разовая запись
			halt					; на некоторых эмуляторах попадает не туда)
			di
			ld	hl,sp_pal+15
			call	sp_palette
			ld	a,0x8A				; клавиатура: все ряды
			out	(0x00),a
			xor	a
			out	(0x03),a
			in	a,(0x02)
			ld	b,a
			ld	a,0xFF
			out	(0x03),a
			ld	a,0x88
			out	(0x00),a
			ld	a,b
			inc	a
			jp	nz,.go				; нажата клавиша
			in	a,(0x06)			; огонь джойстика (0 — нажат)
			ld	b,a
			in	a,(0x0E)
			and	b
			and	0xC0
			cp	0xC0
			jp	z,.w
.go:		ei
			halt
			di
			ld	hl,sp_black+15
			call	sp_palette
			ld	hl,sp_payload		; сжатая игра -> A000, распаковщик -> FE00
			ld	de,0xA000
			ld	bc,PAYLOAD_END - sp_payload
			call	sp_copy
			ld	hl,sp_unpack_src
			ld	de,0xFE00
			ld	bc,sp_unpack_end - sp_unpack_src
			call	sp_copy
			jp	0xFE00
; HL = последний байт палитры: 15..0
sp_palette:	ld	e,15
.l:			ld	a,e
			out	(0x02),a
			ld	a,(hl)
			dec	hl
			out	(0x0C),a
			out	(0x0C),a
			out	(0x0C),a
			out	(0x0C),a
			dec	e
			jp	p,.l
			xor	a
			out	(0x02),a
			ret
sp_copy:	ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	de
			dec	bc
			ld	a,b
			or	c
			jp	nz,sp_copy
			ret
sp_black:	ds	16
			ASSERT	$ <= 0x00E0
			ORG	0x0100
sp_payload:	INCBIN	"game.zx0"
PAYLOAD_END:
sp_pal:		INCBIN	"palette.bin"
sp_unpack_src:
			DISP	0xFE00
			ld	sp,0
			ld	hl,0xA000
			ld	bc,0x0000
			call	dzx0
			jp	0x0000
			INCLUDE	"../i8080/dzx0.asm"
			ENT
sp_unpack_end:
			ASSERT	$ <= 0x8000
			ASSERT	PAYLOAD_END - sp_payload <= 0xFE00 - 0xA000
			ORG	0x8000
			INCBIN	"screen.bin"
			SAVEBIN	"splash.rom", 0, 0x10000
