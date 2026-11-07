; Bruce Lee для Вектора-06Ц (ваниль 64 КБ, 8 цветов) — сборка образа (docs/VEC_LAYOUT.md).
;   python3 -I tools/mkvecdata.py && python3 -I tools/mkcpcsnd.py &&
;   (cd src/vec && ../../tools/sjasmplus --nologo --i8080 --sym=../../build/vec/brucelee.sym main.asm)
; Раскладка: 0000 переходы, 0038 прерывание; 0100.. код (логика src/i8080 + платформа src/vec), острова и
; переменные ZX, спрайты Z_SPR, буферы; стек вниз от STACK; 5B00..9FFF — данные ZX по своим адресам
; (в 933A..97FF — шрифт, стек, полоса / таблица картинок титула: звук ZX на Векторе не нужен); A000.. экран.
			DEVICE	NOSLOT64K
			INCLUDE	"../i8080/gen/zxequ.asm"
SND_JINGLE	equ	1
SND_DIE		equ	2
SND_KEY		equ	3
SND_HIT		equ	4
CMAP		equ	0x5D00				; титул: карта символов (на месте копии карты комнаты)
TILEBLANK	equ	0x5B00				; 5B00..5B1F: пустые тайлы (у ZX здесь нули)
FONT		equ	0x9340				; 9340..953F (символы 32..95); 9540..963F — свободно (07.11)
STACK		equ	0x9700				; стек 96A8..96FF, 88 байт (замер 06.11: глубина до 60 байт)
SND_HI		equ	0x9640				; 9640..968F — звуки CPC (gen/soundhi.asm)
SND_HI_END	equ	0x96A8
STRIP		equ	0x9700				; игра: полоса столбца (64 строки по 4 байта — вся страница)
BLK_SRC		equ	0x9700				; титул: источники клеток картинок (до 979B)

			DEFINE	AI_CPC				; ИИ ближнего боя CPC (src/vec/aicpc.asm, pers.asm ai.near)
			DEFINE	VEC_WIN				; победа: прыжки под мелодию титула (game.asm level_complete, plat_win_tick)
	IFDEF	RUS
			INCLUDE	"../i8080/gen/ru_eq.asm"	; русская версия: позиции строки старта (tools/mkru.py)
	ELSE
ST1_C0		equ	5					; строка старта: столбцы 5..25 (title.asm)
ST1_C1		equ	26
	ENDIF
			DEFINE	WIZ_CPC				; стрельба колдуна как у CPC (room.asm r_DD0D, wizcpc.asm)
			ORG	0x0000
			di
			ld	sp,STACK
			jp	boot
			INCLUDE	"aicpc.asm"
			ASSERT	$ <= 0x0038
			ORG	0x0038
			jp	isr
			INCLUDE	"roompal.asm"
			AI_CPC2
			ASSERT	$ <= 0x0100

			ORG	0x0100
code_start:
			INCLUDE	"../i8080/pers.asm"
			INCLUDE	"../i8080/room.asm"
			INCLUDE	"../i8080/game.asm"
			INCLUDE	"plat.asm"
			INCLUDE	"render.asm"
			INCLUDE	"tilefix.asm"
			INCLUDE	"logo.asm"
			INCLUDE	"finale.asm"
			INCLUDE	"title.asm"
			INCLUDE	"sound.asm"
			INCLUDE	"../i8080/gen/sound.asm"
			INCLUDE	"../i8080/gen/optab.asm"
code_end:
			INCLUDE	"../i8080/gen/zxdata.asm"
			INCLUDE	"../i8080/gen/zxvars.asm"
Z_SPRC:		INCBIN	"../i8080/gen/sprcol.bin"	; спрайты столбцами кадров (tools/mkvecdata.py)
pal_room:	ds	16					; палитра комнаты (roompal.asm)
amap:		ds	768
			ALIGN	32					; want: low 			ALIGN	64 31 = 0, want и disp в одной странице (render.asm ASSERT)
want:		ds	24					; персонажи: что нарисовать (3 x 8)
disp:		ds	24					; что на экране (3 x 8)
pp:			ds	30					; персонажи области перерисовки (3 x 10)
wr_rects:	ds	15					; вода: прямоугольники персонажей (3 x 5)
low_end:
			ASSERT	low_end <= 0x5B00
			ORG	0x5B00
			INCBIN	"../../build/zx_tap.bin", 0x5B00, 0x4500
			INCLUDE	"../i8080/gen/roomz.asm"
			INCLUDE	"../i8080/gen/sprhole.asm"
; код вывода в дырах потоков комнат (tools/mkvecdata.py: CODE_HOLES); метки hcodeN..hcodeN_end знают vecsoak и профили
			INCLUDE	"../i8080/gen/soundhole.asm"
			AI_CPC3						; за sfx_die в дыре 8 (soundhole.asm кончается ей)
			ASSERT	$ <= CODEEND_8
			ORG	ROOMHOLE_12
hcode0:
			INCLUDE	"render_q.asm"
hcode0_end:
			ASSERT	$ <= CODEEND_12	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_13
hcode1:
			INCLUDE	"render_q2.asm"
hcode1_end:
			ASSERT	$ <= CODEEND_13	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_10
hcode2:
			INCLUDE	"render_q4.asm"
hcode2_end:
			ASSERT	$ <= CODEEND_10	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_14
hcode3:
			INCLUDE	"render_pl_c.asm"
hcode3_end:
			INCLUDE	"sound_h14.asm"
			ASSERT	$ <= CODEEND_14	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_3
hcode4:
			INCLUDE	"render_pl_a.asm"
hcode4_end:
			ASSERT	$ <= CODEEND_3	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_9
hcode5:
			INCLUDE	"render_pl_b.asm"
hcode5_end:
			ASSERT	$ <= CODEEND_9	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_11
hcode6:
			INCLUDE	"render_pl_d.asm"
hcode6_end:
			ASSERT	$ <= CODEEND_11	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_4
hcode7:
			INCLUDE	"render_q5.asm"
			INCLUDE	"render_pl_n.asm"
hcode7_end:
			INCLUDE	"sound_h4.asm"
			ASSERT	$ <= CODEEND_4	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_7
hcode8:
			INCLUDE	"render_q6.asm"
hcode8_end:
			ASSERT	$ <= CODEEND_7	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ORG	ROOMHOLE_19
hcode9:
			INCLUDE	"render_pl_e.asm"
			INCLUDE	"render_q3.asm"
hcode9_end:
			INCLUDE	"sound_h19.asm"
			ASSERT	$ <= CODEEND_19	; бюджет кода (tools/mkvecdata.py CODE_BUDGET), дальше — спрайты
			ASSERT	high pl_tabs = high (pl_tabs_end - 1) && high pz_tab = high (pz_tab + 15) && high cfq_tab = high (cfq_tab + 15)
			ORG	TILEBLANK
			INCBIN	"../i8080/gen/tileblank.bin"
			ORG	0x9339
			INCLUDE	"sound_v.asm"
			ASSERT	$ <= FONT
			ORG	ROOMHOLE_18
			INCLUDE	"sound_h18.asm"
			ASSERT	$ <= CODEEND_18
			ORG	FONT
	IFDEF	RUS							; русская версия (07.11): кириллица на месте ненужных латинских (tools/mkru.py)
			INCBIN	"../i8080/gen/font_ru.bin"
	ELSE
			INCBIN	"../i8080/gen/font.bin"
	ENDIF
			ASSERT	$ = FONT + 512
			ORG	FONT + (';' - 32) * 8	; неиспользуемые глифы ;<=>? и [\]^_ (тексты — 46 знаков, mkvecdata.py)
			INCLUDE	"wizcpc2.asm"
			ASSERT	$ <= FONT + ('@' - 32) * 8
			ORG	FONT + ('[' - 32) * 8
			INCLUDE	"wizcpc3.asm"
			INCLUDE	"wizball3.asm"
			ASSERT	$ <= FONT + 512
	IFNDEF	RUS							; русская версия: глифы $%& + / — буквы, код — в другом месте (07.11)
			ORG	FONT + ('$' - 32) * 8	; глифы $%& и !" (не используются)
			INCLUDE	"wizball1.asm"
			ASSERT	$ <= FONT + (0x27 - 32) * 8
	ENDIF
	IFNDEF	RUS
			ORG	FONT + ('"' - 32) * 8	; глиф " (не используется; «!» — свободен для текстов, 07.11)
			INCLUDE	"wizlamp.asm"
			ASSERT	$ <= FONT + ('#' - 32) * 8
	ELSE								; русская версия (08.11): глифы $%& и " — буквы; вывод шара и мигание фонарика —
			ORG	0x9800 + 0xE4 * 8		; в узорах тайлов E4..E7 (номера колдуна, после объединения нигде не стоят;
			INCLUDE	"wizball1.asm"		; mkroom18tiles.py RESERVED)
			INCLUDE	"wizlamp.asm"
			ASSERT	$ <= 0x9800 + 0xE8 * 8
	ENDIF
			ORG	FONT + ('(' - 32) * 8	; глифы () (не используются)
			INCLUDE	"wizcpc4.asm"
			ASSERT	$ <= FONT + ('*' - 32) * 8
	IFNDEF	RUS
			ORG	FONT + ('+' - 32) * 8	; глиф + (не используется)
			INCLUDE	"winsnd.asm"
			ASSERT	$ <= FONT + (',' - 32) * 8
	ENDIF
	IFNDEF	RUS
			ORG	FONT + ('/' - 32) * 8	; глиф / (не используется)
			INCLUDE	"wizlamp2.asm"
			ASSERT	$ <= FONT + ('0' - 32) * 8
	ENDIF
			ORG	FONT + 512
FREE_9540:								; 9540..963F — строчные буквы шрифта убраны (07.11): код титула и ввода
			INCLUDE	"hi9540.asm"
			ASSERT	$ <= SND_HI
			ORG	SND_HI
			INCLUDE	"../i8080/gen/soundhi.asm"
nz_cnt:		db	1					; бит шума во вспышке прерывания (sound.asm)
nz_sel:		db	0x40				; счётчик шумящего голоса: 40 — голос 1 (порт 0A), 80 — голос 2 (порт 09)
; A = 40/80 (бит голоса; при двух шумящих — любой) -> nz_sel и порт в nz_bit.pt
nz_to:		and	0x40
			jp	nz,.s
			ld	a,0x80
.s:			ld	(nz_sel),a
			rlca
			rlca
			cpl
			add	a,0x0C				; 40 -> 0A, 80 -> 09
			ld	(nz_bit.pt+1),a
			ret
			ASSERT	$ <= SND_HI_END
			ASSERT	$ <= BLK_SRC
; ---- титул (06.11, владелец): меню выбора управления убрано; на месте его строк ZX (FB12..FC16) — тексты титула
;      ('#' — «П», '@' — © в шрифте, tools/mkvecdata.py)
	IFDEF	RUS
			ORG	zv_FB00					; строки титула по-русски (gen/ru_a.asm): FB00 + место английских vv1..st1
			INCLUDE	"../i8080/gen/ru_a.asm"
	ELSE
			ORG	zv_FB12
vv1:		db	'VECTOR VERSION @ 2026 BY'
vv2:		db	'B.LIKHACHEV AND N.ZEEMIN'
ct1:		db	'KEYBOARD - ARROWS, SPACE'
ct2:		db	'OR JOYSTICK #'
ct3:		db	'2 PLAYERS: YAMO - JOYSTICK # 1'
st1:		db	'PRESS 1 OR 2 TO START'
	ENDIF
			INCLUDE	"wizstep.asm"			; колдун исчезает по точкам (07.11) — на месте текстов меню ZX
wiz_step_end:
			ASSERT	$ <= zv_FC17
; ---- 06.11 (владелец): логотип OCEAN (9200) и строка «CONVERSION BY L.T.SOFTWARE FOR» (FC8D) убраны с титула.
;      9200..92F0 — надписи GAME OVER/CONGRATULATIONS (bigmsg.asm, с 07.11 вместо картинки); строки ZX TM (FCAB), пауза (92C0) и победа —
;      подряд в FC8D..FCFF (на месте CONVERSION, TM и прежней строки GAME OVER FCDD)
			ORG	0x9200
			INCLUDE	"bigmsg.asm"			; GAME OVER и CONGRATULATIONS удвоенным шрифтом (07.11, вместо картинки)
			INCLUDE	"wizcpc.asm"			; стрельба колдуна как у CPC (07.11)
			INCLUDE	"wiznz.asm"			; шум исчезновения колдуна (07.11)
			ASSERT	$ <= 0x92F1				; 92F1..9338 — блоки спрайтов (mkvecdata.py: дыра 20)
			INCLUDE	"../i8080/gen/room18attr.asm"	; цвета колдуна (только комната 18) — прямо в таблицу 6300
			INCLUDE	"../i8080/gen/room18.asm"		; колдун по рисунку: запечённые узоры и цвета (mkroom18tiles.py)
			ORG	0x5B50					; логотип + запас заёмных тайлов колдуна (ZX0, распаковка — boot)
			INCBIN	"../i8080/gen/logo18.zx0"
			ASSERT	$ <= 0x5D00
			ORG	0x5B20					; 5B20..5B4F — у ZX буфер принтера, пусто
			LG_TAKE
			ASSERT	$ <= 0x5B50
	IFDEF	RUS
			ORG	zv_FC17					; строки ©, прав и авторов по-русски — на месте английских FC17..FC8C
			INCLUDE	"../i8080/gen/ru_b.asm"
			INCLUDE	"wizlamp2.asm"		; (в run80 не выполняется: русский образ им не проверяется)
			ASSERT	$ <= zv_FC8D
			ORG	zv_FEB2					; шапка: «И1 000000 РЕКОРД 000000 ЖИЗНИ 04» (логика — game.asm IFDEF RUS)
			INCLUDE	"../i8080/gen/ru_hdr.asm"
			ORG	zv_FC8D
			INCLUDE	"../i8080/gen/ru_c.asm"	; «ИЛИ ДЖОЙСТИК П», TM, пауза, ИГРА ОКОНЧЕНА
			INCLUDE	"winsnd.asm"
	ELSE
			ORG	zv_FC17				; © ZX (7F) -> '@' (шрифт 32..95, tools/mkvecdata.py)
			db	'@'
			ORG	zv_FC6F + 15
			db	'@'
			ORG	zv_FC8D
tm_txt:		INCBIN	"../../build/zx_tap.bin", 0xFCAB, 50
pause_txt:	db	" * PAUSING :    PRESS 'ENTER' * "	; ZX 92C0, заглавными (в шрифте нет строчных)
go_txt:		db	11, 10 + 1, 6, 0, 6, 'GAME OVER', 0, 6, 0, 0xFF	; big_msg: плашка 11 клеток, строки 10..12 (середина поля), жёлтый (bigmsg.asm)
	ENDIF
			INCLUDE	"wizball2.asm"		; шар колдуна (07.11): здесь — код, в run80 не выполняется (plat_tile перехвачен)
			ASSERT	$ <= zv_FC8D + 115
	IFDEF	RUS
			SAVEBIN	"../../build/vec/brucelee_ru.bin", 0, 0xA000
	ELSE
			SAVEBIN	"../../build/vec/brucelee.bin", 0, 0xA000
	ENDIF
			DISPLAY	"код ", /D, code_end - code_start, " Б, низ до ", /H, low_end, " (стек с ", /H, STACK, ")"
