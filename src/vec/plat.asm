; plat.asm: платформа Вектора для логики Bruce Lee (src/i8080): запуск, прерывание, ввод, клавиши, ход игры.
; Клавиатура ZX эмулируется: zx_kb — 8 рядов ZX (FEFE..7FFE, бит 0 = нажата) из матрицы Вектора, плюс
; стрелки/пробел/джойстик «П» — на клавиши выбранного в меню способа (как в jetpac-v06c). Опрос ввода в
; прерывании — перевод C02D/C085/C0D7 ZX с чтением zx_kb вместо порта FE и kempston вместо порта 1F.

; ---- запуск ----
boot:		ld	a,0x88				; ППА: A — скролл/ряд клавиатуры, B — бордюр, C — клавиши СС/УС/РУС
			out	(0x00),a
			xor	a
			out	(0x02),a
			ld	a,0xFF
			out	(0x03),a
			ld	a,0x83				; джойстик «П»: ППА2, чтение — порт 6
			out	(0x04),a
			ld	a,0x9F
			out	(0x05),a
			call	timer_init
			call	snd_silence
			ld	hl,pal_black
			call	pal_set
			call	clear_screen
			ld	hl,0x5B50			; логотип и запас колдуна (ZX0) -> LOGO_BUF (карта, ещё свободна)
			ld	bc,LOGO_BUF
			call	dzx0
			ld	de,LOGO_BUF			; логотип в полосу под полем; DE -> запас колдуна
			call	lg_band
			ex	de,hl				; запас (узоры, цвета, номера, флаг 0) -> R18_ST (5B50..; дальше до 5CFF свободно)
			ld	de,R18_ST
			ld	b,R18_N*10+1
.r18:		ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	de
			dec	b
			jp	nz,.r18
			ei
			jp	title_start

; ---- прерывание кадра ----
isr:		push	af
			push	bc
			push	de
			push	hl
			ld	hl,8				; возврат внутрь pass.crit..pass.crit_e — на pass.w (SRL (HL) ZX неделим)
			add	hl,sp
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			ld	a,e
			sub	low pass.crit
			ld	c,a
			ld	a,d
			sbc	a,high pass.crit
			jp	nz,.nc
			ld	a,c
			cp	pass.crit_e - pass.crit + 1
			jp	nc,.nc
			ld	(hl),high pass.w
			dec	hl
			ld	(hl),low pass.w
.nc:		ld	a,(pal_load)		; палитра
			or	a
			jp	z,.np
			dec	a
			ld	(pal_load),a
			ld	hl,(pal_ptr)
			ld	de,15
			add	hl,de
			ld	e,0x0F
.pl:		ld	a,e
			out	(0x02),a
			ld	a,(hl)
			dec	hl
			out	(0x0C),a
			out	(0x0C),a
			out	(0x0C),a
			out	(0x0C),a
			dec	e
			jp	p,.pl
.np:		ld	a,(border)
			out	(0x02),a
			call	vec_scan			; клавиатура — только в начале прерывания (порт 03 — ещё и прокрутка)
			call	zx_build
			ld	hl,flash_cnt
			inc	(hl)
			ld	a,(hl)
			and	15
			jp	nz,.nf
			ld	a,(flash_ph)
			xor	1
			ld	(flash_ph),a
			ld	a,1
			ld	(flash_dirty),a
.nf:		call	snd_tick			; звук CPC (sound.asm) — каждый кадр
			ld	a,(isr_game)
			or	a
			call	nz,game_tick
			pop	hl
			pop	de
			pop	bc
			pop	af
			ei
			ret
flash_cnt:	db	0
isr_game:	db	1					; 0 — как DI на ZX (загрузка комнаты, звук): игровая часть прерывания стоит

; C003: игровая часть прерывания ZX
game_tick:	call	input_isr
			ld	hl,zv_FE02			; SCF / RL (HL)
			ld	a,(hl)
			scf
			rla
			ld	(hl),a
			ld	hl,(zv_FE05)
			inc	hl
			ld	(zv_FE05),hl
			ld	hl,zv_FE99
			inc	(hl)
			ld	hl,zv_FE73
			inc	(hl)
			ld	hl,zv_FE78
			inc	(hl)
			ld	hl,zv_FE7D
			inc	(hl)
			ret

; ---- C02D: направление игроков -> FE1B/FE1C -> FE11/FE12 ----
input_isr:	ld	hl,zv_FE15
			ld	a,(hl)
			and	0xFE
			ld	(hl),a
			ld	a,(zv_FE09)
			call	decode
			ld	hl,zv_FE13
			cp	(hl)
			ld	(hl),a
			jp	nz,.c042
			ld	(zv_FE1B),a
.c042:		ld	a,(zv_FE08)
			or	a
			jp	z,.c07e
			ld	hl,zv_FE15
			ld	a,(hl)
			or	1
			ld	(hl),a
			ld	a,(zv_FE0A)
			cp	4
			jp	z,.c07e
			call	decode
			ld	hl,zv_FE14
			cp	(hl)
			ld	(hl),a
			jp	nz,.c061
			ld	(zv_FE1C),a
.c061:		ld	a,(zv_FE04)
			cp	2
			jp	nz,.c07e
			ld	a,(zv_FE08)
			or	a
			jp	z,.c07e
			ld	a,(zv_FE07)
			or	a
			jp	z,.c07e
			ld	hl,(zv_FE1B)
			ld	a,h
			ld	h,l
			ld	l,a
			ld	(zv_FE11),hl
			ret
.c07e:		ld	hl,(zv_FE1B)
			ld	(zv_FE11),hl
			ret
; C085: A = способ (0 клавиатура, 1 Protek, 2 Kempston, 3 Interface 2) -> A = направление (биты R L D U огонь)
decode:		push	af					; запомненный результат (ряды не менялись): по способу и классу FE15
			ld	c,a
			add	a,a
			add	a,c
			ld	c,a
			ld	a,(zv_FE15)
			cp	2
			jp	c,.cl
			ld	a,2
.cl:		add	a,c
			ld	e,a
			ld	d,0
			ld	hl,dc_val
			add	hl,de
			ld	(dc_ptr),hl
			ld	a,(hl)
			cp	0xFF
			jp	z,.calc
			pop	bc
			ld	(zv_FE10),a
			ret
.calc:		pop	af
			call	.dec
			ld	hl,(dc_ptr)
			ld	(hl),a
			ret
.dec:		cp	2					; способы ввода: 0 — клавиатура (игрок 1), 2 — Kempston («П» второго игрока);
			jp	nz,.kb				; Protek и Interface 2 меню ZX у нас не выбираются (убраны 07.11)
.kem:		ld	a,(kempston)
			jp	.st
.kb:		ld	hl,zc_C0E5
			ld	b,0x7F
.kl:		call	rowread
			ld	c,a
			ld	a,b
			rrca
			ld	b,a
			ld	a,c
			jp	c,.kl
.st:		ld	(zv_FE10),a
			ret
dc_ptr:		dw	0
dc_val:		ds	12,0xFF
pk_val:		db	0xFF					; plat_keys по текущим рядам (FF — не считан)
; C0D7: ряд B (как старший байт порта FE), таблица HL (5 байт) -> A |= коды нажатых
rowread:	push	af
			ld	a,b
			call	zx_in
			ld	d,a
			pop	af
			ld	e,5
.l:			ld	c,a
			ld	a,d
			rrca
			ld	d,a
			ld	a,c
			jp	c,.n
			or	(hl)
.n:			inc	hl
			dec	e
			jp	nz,.l
			ret
; A = старший байт адреса порта FE (0 в бите — ряд выбран) -> A = биты 0..4 (0 — нажата), биты 5..7 = 1
zx_in:		push	hl
			push	de
			ld	e,a
			ld	d,0xFF
			ld	hl,zx_kb
			REPT	8
			ld	a,e
			rrca
			ld	e,a
			jp	c,$+6
			ld	a,d
			and	(hl)
			ld	d,a
			inc	hl
			ENDR
			ld	a,d
			or	0xE0
			pop	de
			pop	hl
			ret

; ---- клавиатура Вектора: vec_kbmat (1 = нажата), [8] — СС (0x20), УС (0x40), РУС (0x80) из порта 01 ----
vec_kbmat:	ds	9
vec_scan:	ld	a,0x8A				; порт B — вход
			out	(0x00),a
			ld	hl,vec_kbmat
			ld	b,0xFE
			ld	c,0					; отличия от прошлого кадра
.l:			ld	a,b
			out	(0x03),a
			in	a,(0x02)
			cpl
			ld	d,a
			xor	(hl)
			or	c
			ld	c,a
			ld	(hl),d
			inc	hl
			ld	a,b
			rlca
			ld	b,a
			jp	c,.l
			in	a,(0x01)
			cpl
			and	0xE0
			ld	d,a
			xor	(hl)
			or	c
			ld	(kb_chg),a
			ld	(hl),d
			ld	a,0x88
			out	(0x00),a
			ld	a,0xFF
			out	(0x03),a
			ld	a,(border)
			out	(0x02),a
			ret
; ряды ZX из матрицы + направления
zx_kb:		db	0x1F,0x1F,0x1F,0x1F,0x1F,0x1F,0x1F,0x1F
kempston:	db	0
kb_chg:		db	0xFF
zb_sig:		ds	5
zx_build:	ld	a,(kb_chg)			; пересобрать, только если что-то сменилось: клавиши, джойстики, способы
			ld	c,a
			call	joy_rd2				; джойстики «П» А и Б (hi9540.asm)
			ld	hl,zb_sig
			ld	a,(joyraw1)
			call	.sig
			ld	a,(joyraw2)
			call	.sig
			ld	a,(zv_FE08)
			call	.sig
			ld	a,(zv_FE09)
			call	.sig
			ld	a,(zv_FE0A)
			call	.sig
			ld	a,c
			or	a
			ret	z
			jp	.go
.sig:		ld	b,a
			xor	(hl)
			or	c
			ld	c,a
			ld	(hl),b
			inc	hl
			ret
.go:		ld	a,0xFF
			ld	(pk_val),a
			ld	hl,dc_val
			ld	b,12
.dv:		ld	(hl),0xFF
			inc	hl
			dec	b
			jp	nz,.dv
			ld	hl,zx_kb
			ld	de,vec_zxmap
			ld	c,8
.r:			ld	b,0x1F
			push	hl
			ld	a,1
			ld	(.bit+1),a
.k:			ld	a,(de)
			inc	de
			ld	l,a
			ld	h,0
			push	de
			ld	de,vec_kbmat
			add	hl,de
			pop	de
			ld	a,(de)
			inc	de
			and	(hl)
			jp	z,.nk
.bit:		ld	a,1
			cpl
			and	b
			ld	b,a
.nk:		ld	a,(.bit+1)
			add	a,a
			ld	(.bit+1),a
			cp	0x20
			jp	nz,.k
			pop	hl
			ld	(hl),b
			inc	hl
			dec	c
			jp	nz,.r
			; игрок 1: стрелки, пробел, джойстик «П» (порт 06); игрок 2: джойстик порта 0E
			ld	a,(vec_kbmat+0)
			ld	b,0
			rlca
			jp	nc,.a1
			ld	b,4					; вниз
.a1:		rlca
			jp	nc,.a2
			inc	b					; вправо
.a2:		rlca
			jp	nc,.a3
			ld	c,a
			ld	a,b
			or	8					; вверх
			ld	b,a
			ld	a,c
.a3:		rlca
			jp	nc,.a4
			ld	a,b
			or	2					; влево
			ld	b,a
.a4:		ld	a,(vec_kbmat+7)
			and	0x80
			jp	z,.a5
			ld	a,b
			or	0x10
			ld	b,a
.a5:		ld	a,(joyraw1)			; игрок 1: клавиатура + джойстик (один — оба «П», вдвоём — «П» Б)
			call	joy_dir
			or	b
			ld	(p1dir),a
			ld	a,(joyraw2)			; игрок 2 (Ямо, вдвоём): «П» А — через Kempston (FE0A = 2)
			call	joy_dir
			ld	(p2dir),a
			xor	a
			ld	(kempston),a
			ld	a,(p1dir)
			ld	b,a
			ld	a,(zv_FE09)
			call	apply_dir
			ld	a,(zv_FE08)
			or	a
			ret	z
			ld	a,(zv_FE0A)
			cp	4
			ret	nc
			ld	b,a
			ld	a,(p2dir)
			ld	c,a
			ld	a,b
			ld	b,c
; A = способ, B = направление, HL = таблица Interface 2 этого игрока
apply_dir:	cp	2					; 2 — Kempston, иначе — клавиши dir_kb
			jp	nz,.k
			ld	a,(kempston)
			or	b
			ld	(kempston),a
			ret
.k:			ld	hl,dir_kb
			ld	c,5
.l:			ld	a,b
			rrca
			ld	b,a
			jp	nc,.n
			push	bc
			ld	e,(hl)
			ld	d,0
			inc	hl
			ld	c,(hl)
			dec	hl
			push	hl
			ld	hl,zx_kb
			add	hl,de
			ld	a,(hl)
			and	c
			ld	(hl),a
			pop	hl
			pop	bc
.n:			inc	hl
			inc	hl
			dec	c
			jp	nz,.l
			ret
; A = порт джойстика «П» (0 — нажато: R L U D -- -- огонь огонь) -> A = R L D U огонь (биты 0..4)
joy_dir:	cpl
			ld	c,a
			and	0x30				; в покое биты 4, 5 — единицы; иначе джойстика нет
			ld	a,0
			ret	nz
			ld	a,c
			and	3					; R, L
			ld	d,a
			ld	a,c
			and	4
			jp	z,.u
			ld	a,d
			or	8
			ld	d,a
.u:			ld	a,c
			and	8
			jp	z,.d
			ld	a,d
			or	4
			ld	d,a
.d:			ld	a,c
			and	0xC0
			ld	a,d
			ret	z
			or	0x10
			ret
p1dir:		db	0
p2dir:		db	0
; (ряд ZX, маска AND) для R, L, D, U, огонь
dir_kb:		db	5,0xFE, 5,0xFD, 1,0xFE, 2,0xFE, 7,0xFB		; P O A Q M
; ряды ZX FEFE..7FFE по 5 клавиш: (смещение в vec_kbmat, маска)
vec_zxmap:	db	8,0x20, 7,0x04, 7,0x01, 4,0x08, 6,0x40		; CAPS(СС) Z X C V
			db	4,0x02, 6,0x08, 4,0x10, 4,0x40, 4,0x80		; A S D F G
			db	6,0x02, 6,0x80, 4,0x20, 6,0x04, 6,0x10		; Q W E R T
			db	2,0x02, 2,0x04, 2,0x08, 2,0x10, 2,0x20		; 1 2 3 4 5
			db	2,0x01, 3,0x02, 3,0x01, 2,0x80, 2,0x40		; 0 9 8 7 6
			db	6,0x01, 5,0x80, 5,0x02, 6,0x20, 7,0x02		; P O I U Y
			db	0,0x04, 5,0x10, 5,0x08, 5,0x04, 5,0x01		; ENTER(ВК) L K J H
			db	7,0x80, 8,0x40, 5,0x20, 5,0x40, 4,0x04		; SPACE SYM(УС) M N B

; ---- случайность вместо ld a,r: счётчик 0 ВИ53 + накопление; портит только A ----
plat_rand:	push	hl
			xor	a
			out	(0x08),a
			in	a,(0x0B)
			ld	l,a
			in	a,(0x0B)
			xor	l
			ld	hl,rnd_acc
			add	a,(hl)
			ld	(hl),a
			pop	hl
			ret
rnd_acc:	db	0x5A

; ---- ожидание ----
plat_wait:	jp	snd_idle			; EI / HALT; пока шумит звук CPC — шум на спикер (sound.asm)
plat_halts:	push	af
			call	snd_idle
			pop	af
			dec	a
			jp	nz,plat_halts
			ret
plat_rl_begin:
			xor	a
			ld	(isr_game),a
			ret

; ---- C121: клавиши паузы, рестарта, звука (на ZX: SPACE+CAPS, ENTER, SYMBOL SHIFT) ----
plat_keys:	ld	a,(pk_val)			; ответ зависит только от zx_kb — считается заново после пересборки рядов
			cp	0xFF
			ret	nz
			call	.calc
			ld	(pk_val),a
			ret
.calc:		ld	a,0x7F
			call	zx_in
			rra
			jp	c,.c135
			ld	a,0xFE
			call	zx_in
			rra
			jp	c,.c135
			ld	a,1
			ret
.c135:		ld	a,0xBF
			call	zx_in
			rra
			ld	a,2
			ret	nc
			ld	a,0x7F
			call	zx_in
			and	2
			ld	a,4
			ret	z
			xor	a
			ret
plat_menu_keys:
			rra
			jp	nc,.np
			call	key_release			; C12F: щелчок и рестарт (C4BD)
			jp	title_restart
.np:		rra
			jp	nc,.snd
			ld	hl,pause_txt			; пауза (ZX ENTER = ВК Вектора)
			ld	c,0x46
			call	plat_msg
			call	key_release			; ВК отпустить
.w:			ei
			halt
			ld	a,(vec_kbmat+1)		; АР2 (ряд 1, бит 2) — выход из игры в титул (владелец 07.11)
			and	4
			jp	nz,title_restart
			call	keyscan
			ld	a,e
			cp	0x21				; ВК — дальше
			jp	nz,.w
			ld	hl,zv_FED2
			ld	c,0x38
			call	plat_msg
			jp	key_release
.snd:		ld	a,(zv_FE9A)
			xor	1
			and	1
			ld	(zv_FE9A),a
			jp	key_release
; C158 (меню): только SYMBOL SHIFT
sym_key:	ld	a,0x7F
			call	zx_in
			and	2
			ret	nz
			jp	plat_menu_keys.snd

; ---- клавиши как в ПЗУ ZX: KEY-SCAN (028E) -> E = код (FF нет), NZ — нажато больше одной (кроме CAPS/SYM) ----
keyscan:	ld	e,0xFF
			ld	hl,zx_kb
			ld	c,7					; 7 - номер ряда
.r:			ld	a,(hl)
			ld	b,0x20				; код = (4 - бит)*8 + (7 - ряд)
			ld	d,0
.b:			rrca
			jp	c,.nb
			push	af
			ld	a,d
			rlca
			rlca
			rlca
			cpl
			add	a,0x21				; (4-бит)*8 = 32 - 8*бит
			add	a,c
			cp	0x27				; CAPS SHIFT
			jp	z,.sh
			cp	0x18				; SYMBOL SHIFT
			jp	z,.sh
			ld	b,a
			ld	a,e
			cp	0xFF
			jp	nz,.many
			ld	e,b
.sh:		pop	af
.nb:		inc	d
			push	af
			ld	a,d
			cp	5
			jp	z,.rn
			pop	af
			jp	.b
.rn:		pop	af
			inc	hl
			dec	c
			jp	p,.r
			xor	a
			ret
.many:		pop	af
			or	1
			ret
; C6D2: код клавиши, устойчивый два кадра
key_debounce:
			ld	b,2
			ld	c,a
.h:			ei
			halt
			push	bc
			call	keyscan
			pop	bc
			jp	nz,key_debounce
			ld	a,e
			cp	c
			jp	nz,key_debounce
			dec	b
			jp	nz,.h
			ret
; C6C3: дождаться отпускания, потом нажатия -> A = код
; C6E4: дождаться отпускания
key_release:
			call	key_debounce
			cp	0xFF
			jp	nz,key_release
			ret

; ---- конец игры (CAC0): GAME OVER удвоенным шрифтом на серой плашке (bigmsg.asm) и проигрыш, ждать клавишу ----
plat_game_over:
			ld	sp,STACK
			ld	hl,go_txt
			call	big_msg
			ld	hl,go_v1			; проигрыш (вариант Б владельца, у CPC мелодии нет), один раз
			ld	de,go_v2
			call	snd_play
			ld	hl,go_end
			ld	(vc1+8),hl
			ld	(vc2+8),hl
			call	bm_wait
			jp	title_start

; ---- надпись победы (DD67) ----
; (владелец 07.11) вместо мигающей надписи в шапке — мелодия титула один раз; Брюс прыгает на месте (логика ZX), пока
; она играет (plat_win_tick), потом CONGRATULATIONS (sound.asm, plat_sound SND_JINGLE)
; plat_win_msg — в bigmsg.asm (9200)
; DD67 (обработчик комнаты 19, каждый проход), повторно: мелодия играет — Брюс прыгает на месте (поза ZX 10h
; неподвижна: вернуть состояние 1, ввод «вверх» FE11 = 8), CY = 1 — дальше не идти (FE3E держать 1); доиграла (или звук
; выключен) — CY = 0, A = 3: надпись и новый круг
plat_win_tick:
			ld	a,(zv_FE9A)
			or	a
			jp	z,.d
			ld	hl,(vc1+4)			; голос 1 (длиннее) дошёл до тишины go_end
			ld	a,l
			cp	low (go_end+2)
			jp	nz,.p
			ld	a,h
			cp	high (go_end+2)
			jp	z,.d
.p:			ld	a,1
			ld	(zv_FE3E),a
			ld	a,(zc_CCA7)
			cp	0x10
			jp	nz,.j
			ld	a,0x0C				; из позы ZX 10h — подготовка Ch: присед CPC 4 (07.11; было 12h — вытянутый кадр)
			ld	(zc_CCA7),a
.j:			ld	a,8
			ld	(zv_FE11),a
			call	win_shimmer			; сокровища мерцают (bigmsg.asm)
			scf
			ret
.d:			ld	a,3
			or	a
			ret
