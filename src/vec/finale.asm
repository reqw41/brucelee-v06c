; finale.asm: финал и надписи (владелец 07.11) — то, что не влезло в 9200 (bigmsg.asm): лицо Брюса, ожидание клавиши
; A = 12h — лицо (и признак финала для plat_state), 0 — со спины: face_tab (в дыре потока комнаты, gen/sprhole.asm) — куски блоков кадров CPC 3, 4: адрес,
; длина, XOR (байты S и K подряд)
face_set:	ld	hl,face_f
			cp	(hl)
			ret	z
			ld	(hl),a
			ld	hl,face_tab
.b:			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			inc	hl
			ld	a,d
			or	a
			jp	nz,.k
			dec	e					; DW 0 — конец, DW 1, адрес — продолжение в другой дыре
			ret	m
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
			jp	.b
.k:			ld	b,(hl)				; длина куска
			inc	hl
.r:			ld	a,(de)
			xor	(hl)
			ld	(de),a
			inc	hl
			inc	de
			dec	b
			jp	nz,.r
			jp	.b
face_f:		db	0

; дождаться: клавиши отпущены, нажатие, отпускание (GAME OVER, победа)
bm_wait:	call	.f
.p:			ei
			halt
			call	keyscan
			ld	a,e
			cp	0xFF
			jp	z,.p
.f:			ei
			halt
			call	keyscan
			ld	a,e
			cp	0xFF
			jp	nz,.f
			ret

; DD67, первое касание: мелодия титула один раз (не snd_music_on: он в дыре комнаты 4 — run80 её не держит), Брюсу —
; лицо на кадрах прыжка вверх (владелец 07.11)
plat_win_msg:
			ld	hl,mus_v1
			ld	de,mus_v2
			call	win_snd				; звук включается (winsnd.asm)
			ld	hl,go_end			; один раз: дальше тишина
			ld	(vc1+8),hl
			ld	(vc2+8),hl
			ld	a,0x0C				; лицо; заодно подстановка для plat_state (sound.asm): подготовка Ch — присед (кадр CPC 4)
			jp	face_set

; ---- колдун исчезает по точкам (подбор оружия, комната 18; владелец 07.11: вместо мигания): 64 шага по 4 кадра — в
;      каждой клетке колдуна (wiz_mask) гаснет одна точка, порядок (k * 37) mod 64 — строка, бит; в конце клетки
;      колдуна в amap — фон, чтобы перерисовка (шар, персонажи) его не возвращала (до следующего входа в комнату).
;      Обход клеток — wiz_step (wizstep.asm, на месте текстов меню ZX FBA7..FC16)
wiz_fade:	ld	hl,BRUCE
			call	plat_draw
			call	plat_show
			xor	a
.f:			ld	(wf_k),a
			call	wf_nz				; фонарик отзвучал — взрыв, потом рокот (wiznz.asm)
			ld	b,7					; шаг (~0,6 кадра; шум — только в простое, snd_idle) + 7 кадров шума: ~2,4 с
.w:			call	snd_idle
			dec	b
			jp	nz,.w
			ld	a,(wf_k)				; v = (k * 5) & 15: строка = v >> 1, 4 точки — узор 69 или 96 (v & 1)
			ld	c,a
			add	a,a
			add	a,a
			add	a,c
			and	15
			ld	b,a
			rrca
			and	7
			ld	(wf_ln),a
			ld	a,b
			rrca
			ld	a,0x96
			jp	nc,.mk
			ld	a,0x69
.mk:		ld	(wf_ms),a
			call	wiz_step
			ld	a,(wf_k)
			inc	a
			cp	16
			jp	nz,.f
			ret
wf_k:		db	0
wf_ln:		db	0
wf_ms:		db	0
			INCLUDE	"../i8080/gen/wizmask.asm"
