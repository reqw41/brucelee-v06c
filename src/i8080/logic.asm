; Bruce Lee: логика на i8080 для сверки с эталоном ZX (tools/run80.js) — раскладка Вектора (docs/VEC_LAYOUT.md).
;   python3 -I tools/mkvecdata.py && (cd src/i8080 && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/l80/logic.sym logic.asm)
			DEVICE	NOSLOT64K
			INCLUDE	"gen/zxequ.asm"

			ORG	0x0100
code_start:
			INCLUDE	"pers.asm"
			INCLUDE	"room.asm"
			INCLUDE	"game.asm"
			INCLUDE	"plat_test.asm"
code_end:
			INCLUDE	"gen/zxdata.asm"
			INCLUDE	"gen/zxvars.asm"
Z_SPRC:		INCBIN	"gen/sprcol.bin"
low_end:
			ASSERT	low_end <= 0x5B00
			ORG	0x5B00
			INCBIN	"../../build/zx_tap.bin", 0x5B00, 0x4500
			INCLUDE	"gen/roomz.asm"
			INCLUDE	"gen/sprhole.asm"
			SAVEBIN	"../../build/l80/logic.bin", 0, 0xA000
			DISPLAY	"код ", /D, code_end - code_start, " Б, низ до ", /H, low_end
