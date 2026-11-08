; Образ без заставки с адреса 0x0100 (владелец 08.11: «чтобы можно было запустить из CP/M») — .rom для эмуляторов
; (загрузка с 0x0100), для CP/M — переименовать в .COM (tools/mksplash.py). Гасит палитру, переносит сжатую игру в A000.., распаковщик — в FE00,
; распаковывает игру в 0000..9FFF и запускает с 0000 (как заставка, src/vec/splash.asm). В CP/M назад не возвращается.
			DEVICE	NOSLOT64K
			ORG	0x0100
			di
			ld	sp,0x0100
			ld	a,0xC9				; RST 38 — RET: будит HALT (вектор CP/M или мусор загрузчика не нужен)
			ld	(0x0038),a
			ld	a,0x88
			out	(0x00),a
			xor	a
			out	(0x02),a
			ld	a,0xFF
			out	(0x03),a
			ei						; палитра — в обратном ходе
			halt
			di
			ld	e,15				; палитра — чёрная (распаковка идёт через экран A000..)
.p:			ld	a,e
			out	(0x02),a
			xor	a
			out	(0x0C),a
			out	(0x0C),a
			out	(0x0C),a
			out	(0x0C),a
			dec	e
			jp	p,.p
			ld	hl,b_payload		; сжатая игра -> A000, распаковщик -> FE00
			ld	de,0xA000
			ld	bc,B_END - b_payload
			call	b_copy
			ld	hl,b_unpack_src
			ld	de,0xFE00
			ld	bc,b_unpack_end - b_unpack_src
			call	b_copy
			jp	0xFE00
b_copy:		ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	de
			dec	bc
			ld	a,b
			or	c
			jp	nz,b_copy
			ret
b_payload:	INCBIN	"game.zx0"
B_END:
b_unpack_src:
			DISP	0xFE00
			ld	sp,0
			ld	hl,0xA000
			ld	bc,0x0000
			call	dzx0
			jp	0x0000
			INCLUDE	"../i8080/dzx0.asm"
			ENT
b_unpack_end:
			ASSERT	B_END - b_payload <= 0xFE00 - 0xA000
			SAVEBIN	"boot0100.bin", 0x0100, $ - 0x0100
