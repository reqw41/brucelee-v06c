; sound.asm: музыка и звуки CPC (решение владельца 06.11.2026) на ВИ53, проигрыватель в прерывании (50 Гц).
; Счётчик 0 — секундомер (режим 2, 1,5 МГц, вниз); счётчик 1 — голос 1 (канал A CPC), счётчик 2 — голос 2
; (каналы B и C). Данные — tools/mkcpcsnd.py (src/i8080/gen/sound.asm). Как на CPC, звук игру не останавливает;
; музыка — только титул и меню (по кругу), в конце игры (GAME OVER) — снова титул с музыкой.

timer_now:	xor	a					; HL = счётчик 0
			out	(0x08),a
			in	a,(0x0B)
			ld	l,a
			in	a,(0x0B)
			ld	h,a
			ret

; голос: +0 новый звук (адрес, 0 — нет), +2 текущий звук, +4 музыка (адрес), +6 кадров ноты, +7 код на выходе
; (FF — шум/щелчок: тон всегда перезаписывается), +8 начало музыки, +10 кадров паузы после ноты
vc1:		dw	0, 0, 0
			db	0, 0
			dw	mus_v1
			db	0
vc2:		dw	0, 0, 0
			db	0, 0
			dw	mus_v2
			db	0

; ---- кадр (из прерывания): портит AF, BC, DE, HL ----
snd_tick:	call	wiz_tick			; колдун: звук выстрела (hi9540.asm)
			ld	hl,snd_fr
			inc	(hl)
			ld	hl,vc1
			ld	b,0x40
			call	.v
			ld	hl,vc2
			ld	b,0x80
			call	.v
			ld	a,(nz_on)			; шумит — вспышка шума на счётчик голоса (~3 мс; остальное — в простое, snd_idle)
			or	a
			ret	z
			ld	hl,(snd_rnd)
			ld	a,(nz_cnt)
			ld	c,a
.b:			call	nz_bit
			dec	c
			jp	nz,.b
			ld	(snd_rnd),hl
			ret
.v:			ld	e,(hl)				; новый звук -> текущий
			inc	hl
			ld	d,(hl)
			ld	a,d
			or	e
			jp	z,.c
			xor	a
			ld	(hl),a
			dec	hl
			ld	(hl),a
			inc	hl
			inc	hl
			jp	.s
.c:			inc	hl
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			dec	hl
			ld	a,d
			or	e
			jp	z,.m
.s:			ld	a,(zv_FE9A)			; HL = +2; звук выключен — звук обрывается
			or	a
			jp	z,.e
			ld	a,(de)
			inc	de
			cp	0xFF
			jp	z,.e
			ld	(hl),e
			inc	hl
			ld	(hl),d				; +3
			inc	hl
			inc	hl
			inc	hl
			inc	hl					; +7
			jp	vcode
.e:			xor	a					; конец звука
			ld	(hl),a
			inc	hl
			ld	(hl),a
			inc	hl
			jp	.q
.m:			inc	hl					; +4: музыка
			inc	hl
.q:			ld	a,(mus_on)
			or	a
			jp	z,.off
			ld	a,(zv_FE9A)
			or	a
			jp	z,.off
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			inc	hl					; +6
			dec	(hl)
			ret	nz
			push	hl				; пауза после ноты (+10)
			inc	hl
			inc	hl
			inc	hl
			inc	hl
			ld	a,(hl)
			ld	(hl),0
			pop	hl
			or	a
			jp	z,.n
			ld	(hl),a
			inc	hl
			xor	a
			jp	vcode
.n:			ld	a,(de)
			cp	0xFF
			jp	nz,.n1
			push	hl				; конец — с начала (+8)
			inc	hl
			inc	hl
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			pop	hl
			ld	a,(de)
.n1:		inc	de
			ld	c,a					; код, бит 7 — кадр паузы после ноты
			ld	a,(de)
			inc	de
			ld	(hl),a				; +6 кадров
			dec	hl
			ld	(hl),d
			dec	hl
			ld	(hl),e
			ld	a,c
			rlca
			and	1
			push	hl				; +4 -> +10
			inc	hl
			inc	hl
			inc	hl
			inc	hl
			inc	hl
			inc	hl
			ld	(hl),a
			pop	hl
			inc	hl
			inc	hl
			inc	hl					; +7
			ld	a,c
			and	0x7F
			jp	vcode
.off:		inc	hl					; HL = +4 -> +7, тишина
			inc	hl
			inc	hl
			xor	a
; A = код, HL = +7 (код на выходе), B = счётчик (40 / 80)
vcode:		ld	c,a					; этот голос больше не шумит (шум — биты на его счётчик ВИ53, snd_idle)
			ld	a,b
			cpl
			ld	e,a
			ld	a,(nz_on)
			and	e
			ld	(nz_on),a
			call	nz,nz_to			; шумит другой голос — биты на его счётчик
			ld	a,c
			cp	0x80
			jp	nc,.x
			cp	(hl)
			ret	z					; тот же тон — счётчик не трогать
			ld	(hl),a
			or	a
			jp	z,.sil
			add	a,a					; тон: делитель snd_divs[A-1]
			ld	e,a
			ld	d,0
			ld	hl,snd_divs-2
			add	hl,de
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
.div:		ld	a,b
			or	0x36				; режим 3, младший и старший
			out	(0x08),a
			ld	a,b
			cp	0x40
			jp	nz,.p2
			ld	a,e
			out	(0x0A),a
			ld	a,d
			out	(0x0A),a
			ret
.p2:		ld	a,e
			out	(0x09),a
			ld	a,d
			out	(0x09),a
			ret
.sil:		ld	a,b
			or	0x30				; режим 0 без счёта — выход стоит
			out	(0x08),a
			ret
.x:			ld	(hl),0xFF
			and	0x3F				; шум k: snd_noise[2k] — задержка и число бит вспышки, голос ВИ53 молчит
			ld	e,a
			ld	d,0
			ld	hl,snd_noise
			add	hl,de
			add	hl,de
			ld	a,(hl)
			ld	(nz_dly),a
			inc	hl
			ld	a,(hl)
			ld	(nz_cnt),a
			ld	a,(nz_on)
			or	b
			ld	(nz_on),a
			ld	a,b
			call	nz_to
			jp	.sil

; ---- ожидание прерывания (вместо EI / HALT): пока какой-то голос шумит — случайные биты на его счётчик ВИ53
;      (шум AY N: бит раз в 48*N тактов; петля ~100 тактов + 15 на единицу задержки) ----
snd_idle:	ei
			ld	a,(nz_on)
			or	a
			jp	nz,.n
			halt
			ret
.n:			push	hl
			push	bc
			ld	a,(snd_fr)
			ld	c,a
			ld	hl,(snd_rnd)
.l:			call	nz_bit
			ld	a,(snd_fr)
			cp	c
			jp	z,.l
			ld	(snd_rnd),hl
			pop	bc
			pop	hl
			ret
; бит шума (Галуа 16 в HL) и задержка nz_dly; портит A. Бит — на выход счётчика шумящего голоса ВИ53 (06.11,
; решение владельца: весь звук на ВИ53, кроме шагов): режим 0 — запись управляющего слова опускает выход, счёт 1
; поднимает его через такт; шум звучит в том же тракте и той же громкостью, что и тоны (nz_sel, порт — nz_to)
nz_bit:		ld	a,h
			or	a
			rra
			ld	h,a
			ld	a,l
			rra
			ld	l,a
			ld	a,(nz_sel)
			jp	nc,.z
			or	0x10				; режим 0, только младший байт
			out	(0x08),a
			ld	a,1
.pt:		out	(0x0A),a			; порт счётчика голоса (nz_to)
			ld	a,h
			xor	0xB4
			ld	h,a
			jp	.d
.z:			or	0x30				; режим 0, оба байта, счёта нет — выход внизу
			out	(0x08),a
.d:			ld	a,(nz_dly)
.dl:		dec	a
			jp	nz,.dl
			ret

; ---- музыка: HL — голос 1, DE — голос 2 (последовательности mus_*: с начала, по FF — снова с начала) ----
snd_play:	xor	a
			ld	(mus_on),a
			ld	(vc1+4),hl
			ld	(vc1+8),hl
			ex	de,hl
			ld	(vc2+4),hl
			ld	(vc2+8),hl
			inc	a
			ld	(vc1+6),a
			ld	(vc2+6),a
			ld	(mus_on),a
			ret

; ---- запуск звука: HL = звук (DB голос, кадры..., FF) ----
snd_sfx:	ld	a,(zv_FE9A)
			or	a
			ret	z
			ld	a,(hl)
			inc	hl
			ex	de,hl
			ld	hl,vc1
			dec	a
			jp	z,.v
			ld	hl,vc2
.v:			ld	(hl),e				; ISR забирает новый звук целиком (адрес не может быть 0)
			inc	hl
			ld	(hl),d
			ret

; A = звук логики (1 мелодия победы, 2 гибель, 3 фонарик, 4 удар)
plat_sound:	push	hl
			push	de
			push	bc
			cp	SND_JINGLE
			jp	z,.win
			ld	hl,sfx_die
			cp	SND_DIE
			jp	z,.r
			ld	hl,sfx_lamp
			cp	SND_KEY
			jp	nz,.nk
			call	snd_sfx				; фонарик — на оба голоса (биения, как дрожь тона CPC)
			ld	hl,sfx_lamp2
			jp	.r
.nk:
			ld	hl,sfx_whoosh
.r:			call	snd_sfx
.x:			pop	bc
			pop	de
			pop	hl
			ret
.win:		ld	a,(isr_game)		; победа (владелец 07.11): CONGRATULATIONS удвоенным шрифтом, ждать клавишу
			push	af				; (мелодия титула уже сыграна — plat_win_msg / plat_win_tick)
			xor	a
			ld	(isr_game),a
			ld	(mus_on),a			; мелодия кончилась: музыку — выкл. (08.11: иначе на новом круге конец звука уходил
										; в ветку музыки и флаг шума голоса не снимался — шипение после взрыва колдуна)
			ld	hl,win_txt
			call	big_msg
			call	bm_wait
			pop	af
			ld	(isr_game),a
			jp	.x


; ---- звуки CPC по смене состояния логики (A = новое, P_ST — старое; A сохраняется, портит BC, DE, HL) ----
; удар рукой (вход в 22): Брюс и Ямо — замах 8C0F, Ниндзя — 8C21; удар ногой (вход в 4 у Брюса и Ямо) — 8C12
plat_state:	ld	b,a
			ld	a,(P_ST)
			cp	b
			jp	z,.x
			ld	c,a
			ld	a,b
			cp	22
			jp	z,.att
			cp	4
			jp	nz,.x
			ld	a,c					; 5 -> 4 — тот же удар
			cp	5
			jp	z,.x
			IS_CUR	NINJA
			jp	z,.x
			ld	hl,sfx_kick
			jp	.go
.att:		ld	hl,sfx_whoosh
			IS_CUR	NINJA
			jp	nz,.go
			ld	hl,sfx_ninja
.go:		call	snd_sfx
.x:			ld	a,b					; финал (владелец 07.11): Брюс приземлился (1) — сразу присед 12h (face_f), без
			cp	1					; кадров боком (стойка 1, подготовка Ch); face_f = 0 вне финала (и в run80)
			ret	nz
			ld	a,(pcur)
			cp	low BRUCE
			ld	a,b
			ret	nz
			ld	a,(face_f)
			or	a
			ret	nz
			ld	a,b
			ret

; взрыв колдуна (wiznz.asm, после звука фонарика): шум от высокого к рокоту, ~1,1 с, дальше — рокот sfx_rmb
sfx_boom:	db	2
			DUP	3
			db	0x81
			EDUP
			DUP	4
			db	0x86
			EDUP
			DUP	5
			db	0x87
			EDUP
			DUP	5
			db	0x80
			EDUP
			DUP	6
			db	0x88
			EDUP
			DUP	7
			db	0x89
			EDUP
sfx_rmb:							; рокот — повтор хвоста (wiznz.asm): первый 82 — номер голоса (не 1 — голос 2)
			DUP	24
			db	0x82
			EDUP
			db	0xFF
