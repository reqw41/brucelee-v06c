; hi9540.asm: 9540..963F — место строчных букв шрифта (убраны 07.11). Здесь то, что не выполняется в run80 (титул,
; прерывание): строки титула таблицей, старт 1 / 2 игрока, джойстики «П» А и Б.

; ---- джойстики «П»: порт 6 читает джойстик, выбранный битами 6:5 порта 5 (00 — оба, 01 — А, 10 — Б; ядро MiSTer
;      Vector-06C.sv joyP_o). Один игрок — оба; двое (FE08) — Брюс «П» Б (и клавиатура), Ямо «П» А -> joyraw1/2 ----
joy_rd2:	ld	a,(zv_FE08)
			or	a
			ld	a,0x9F				; оба
			jp	z,.a
			ld	a,0xDF				; Б (07.11, владелец: вдвоём Брюс — «П» Б и клавиатура)
.a:			out	(0x05),a
			in	a,(0x06)
			ld	(joyraw1),a
			ld	a,(zv_FE08)
			or	a
			ld	a,0xFF				; один игрок — второго джойстика нет
			jp	z,.b
			ld	a,0xBF				; А — Ямо
			out	(0x05),a
			in	a,(0x06)
.b:			ld	(joyraw2),a
			ld	a,0x9F
			out	(0x05),a
			ret
joyraw1:	db	0xFF
joyraw2:	db	0xFF

; ---- старт с титула: огонь / пробел / 1 — один игрок, 2 — двое ----
go_1p:		xor	a
			jp	go_12.s
go_12:		and	4					; A = биты клавиш 1 (2) и 2 (4)
.s:			ld	(two_p),a
			jp	title_restart.go
go_2p:		ld	a,(two_p)
			or	a
			ret	z
			ld	a,1
			ld	(zv_FE08),a			; Ямо — второй игрок (ZX: OPPONENT)
			inc	a
			ld	(zv_FE0A),a			; его ввод — Kempston (zx_build: p2dir <- «П» А)
			ret
two_p:		db	0

; ---- строки титула в карту символов (t_text): источник, позиция, длина; 0 — конец ----
t_lines:	ld	hl,.tab
.l:			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			inc	hl
			ld	a,d
			or	e
			ret	z
			push	de
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			inc	hl
			ld	b,(hl)
			inc	hl
			ex	(sp),hl
			call	t_text
			pop	hl
			jp	.l
.tab:
	IFDEF	RUS
			INCLUDE	"../i8080/gen/ru_tab.asm"	; русская версия: строки и позиции (tools/mkru.py)
	ELSE
		dw	zv_FC17, 0x00C7
			db	0x12
			dw	zv_FC29, 0x00E7
			db	0x36
			dw	zv_FC5F, 0x0148
			db	0x10
			dw	zv_FC6F, 0x0181
			db	0x1E
			dw	vv1, 14*32+4			; 06.11 (владелец): авторы версии для Вектора, управление
			db	24
			dw	vv2, 15*32+4
			db	24
			dw	ct1, 17*32+4
			db	24
			dw	ct2, 18*32+9
			db	13
			dw	ct3, 19*32+1			; 07.11: двое — Ямо на джойстике «П» А (1)
			db	30
			dw	tm_txt, 21*32+4			; (07.11: ряд ниже — под строкой двух игроков)
			db	0x32
	ENDIF
			dw	0

; ---- колдун (комната 18, владелец 07.11): у CPC звуков выстрела и взрыва нет (разбор BRUCE.N02); свои — шум ВИ53.
;      Выстрел — новый выстрел (FE3C = 1, wizcpc.asm), из прерывания; «пшик» — как неподключённый блок CPC 8E00
;      (шум N=1Eh). Номера шума — snd_noise (tools/mkcpcsnd.py): 80|k, k = 1, 6, 7, 0, 8, 9, 2 — N 4, 6, 8, 10, 11, 14, 31
wiz_tick:	ld	a,(zv_FE03)
			cp	18
			ret	nz
			call	wiz_lamp			; фонарик мигает (номер 3 палитры, wizcpc4.asm)
			ld	a,(zv_FE3C)
			ld	hl,wiz_last
			cp	(hl)
			ret	z
			ld	c,(hl)
			ld	(hl),a
			cp	3					; новый выстрел — FE3C стал 1 или 2 (wizcpc.asm), но не 1 -> 2: проход дольше кадра
			ret	nc					; может проскочить 1 мимо прерывания
			or	a
			ret	z
			dec	c
			ret	z
			ld	hl,sfx_shot
			jp	snd_sfx
wiz_last:	db	0
sfx_shot:	db	2, 0x09, 0xFF			; выстрел — короткий тон, 1 кадр (владелец 07.11: не шум; три кадра — «ужасно»)
; подбор оружия в комнате 18 (r_D98D -> plat_weapon): колдун исчезает (wiz_fade), звук — wf_nz. Флаг «во вспышке не
; стрелять» (wiz_mute) не нужен: после подбора колдун не стреляет (wiz_nw0), во время исчезновения логика стоит
plat_weapon:								; (D98D — только комната 18: обработчик D7F8; звук фонарика — objects)
			jp	wiz_fade
; sfx_boom — в sound.asm (низ памяти: 9540 полна)

; финал (владелец 07.11): сокровища комнаты 19 (номер 3, светло-голубой) мерцают, пока играет мелодия — раз в 4 кадра
win_shimmer:
			ld	a,(zc_CCA7)			; прыжок (Dh) — шаг логики раз в 2 прохода (задержка не больше 2): у ZX Брюс
			cp	0x0D				; висит ~30 кадров на 7 точках — «парит», раз в проход — слишком быстро (владелец 07.11)
			jp	nz,.s
			ld	a,(zc_CCA5)
			cp	3
			jp	c,.s
			ld	a,2
			ld	(zc_CCA5),a
.s:			ld	hl,.c
			ld	a,(snd_fr)			; HL — таблица 4 цветов номера 3, A — счётчик кадров (сокровища — по 4 кадра;
.u:			rrca					; фонарик комнаты 18 входит сюда с A >> 2 — по 16 кадров, wizlamp.asm)
			rrca
			and	3
			ld	e,a
			ld	d,0
			add	hl,de
			ld	a,(hl)
			ld	(pal_room+3),a
			ld	(pal_room+11),a
			ld	hl,pal_room
			jp	pal_set
.c:			db	0xF8,0xFF,0xF8,0xB8		; голубой, белый, голубой, приглушённый
; символ A в клетку D (строка + 1), E — столбец, цвет C (bigmsg.asm big_msg); регистры сохраняет
bm_ch:		push	bc
			push	de
			push	hl
			call	char_cell
			pop	hl
			pop	de
			pop	bc
			ret
