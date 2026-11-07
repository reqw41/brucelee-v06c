; ---- столбец rp_c полосы: rp_mask, rp_cm (0 — нет точек, 1 — четвёрки в полосе STRIP), rp_vs, rp_rs ----
;      кадры персонажей — два слоя на строку (Y — свой цвет, K — чёрный, решение владельца 05.11.2026, цвета CPC);
;      столбец с кем-то из персонажей собирается в STRIP четвёрками (маска, C, A, E) и рисуется путём четвёрок
col_prep:	xor	a					; персонажи столбца ищет strip_build (нет — rp_cm 0)
			ld	(rp_cm),a

; ---- полоса STRIP четвёрками (маска, C, A, E): точка персонажа S = Y | K; маска &= ~S; C = (C & ~S) | (Брюс ? Y : 0)
;      (жёлтый = C + A); A = (A & ~S) | Y (жёлтый и зелёный); E = (E & ~S) | K (чёрный — номер 1 палитры).
;      Один персонаж в столбце (обычно) — его строки пишутся прямо, (FF, 0, 0, 0) — только края его клеток;
;      несколько — вся полоса (FF, 0, 0, 0), затем Ниндзя, Ямо, Брюс (поверх) смешиванием ----
strip_build:
			xor	a
			ld	(rp_mask),a
			ld	(sb_k),a
			ld	(sb_ri),a
			ld	hl,pp
			call	.rec
			ld	a,1
			ld	(sb_ri),a
			ld	hl,pp+10
			call	.rec
			ld	a,2
			ld	(sb_ri),a
			ld	hl,pp+20
			call	.rec
			ld	a,(sb_k)
			or	a
			ret	z					; никого — rp_cm 0
			ld	a,1					; четвёрки в STRIP (для одного без вспышки dc_setup это заменит)
			ld	(rp_cm),a
			ld	a,32
			ld	(rp_rs),a
			ld	hl,STRIP
			ld	(rp_vs),hl
			ld	a,(sb_k)
			dec	a
			jp	nz,.multi
			ld	a,(wf_on)			; один, без вспышки — прямой вывод клеток (rp_cm 2, render.asm dc_setup)
			or	a
			jp	z,dc_setup
			ld	hl,sbt				; один: края клеток и прямые строки
			ld	a,(hl)
			ld	(sb_n),a
			inc	l
			ld	c,(hl)				; первая строка
			inc	l
			ld	e,(hl)
			inc	l
			ld	d,(hl)
			inc	l
			ld	a,(hl)
			ld	(sb_kind),a
			ld	a,c					; верх клетки: строки (a & ~7) .. a-1
			and	0xF8
			ld	b,a
			add	a,a
			add	a,a
			ld	l,a
			ld	h,STRIP >> 8
			ld	a,c
			sub	b
			call	.fill
			ld	a,(sb_kind)
			cp	2
			jp	z,.db
.de:		ld	a,(de)				; враг: C000 гасится; данные (S, K): маска ~S, A000 = Y = S xor K, E000 = K
			ld	c,a
			inc	de
			ld	a,(de)
			inc	de
			ld	b,a
			xor	c
			push	af
			ld	a,c
			cpl
			ld	(hl),a
			pop	af
			ld	c,a
			inc	l
			ld	(hl),0
			inc	l
			ld	(hl),c
			inc	l
			ld	(hl),b
			inc	l
			ld	a,(sb_n)
			dec	a
			ld	(sb_n),a
			jp	nz,.de
			jp	.bot
.db:		ld	a,(de)				; Брюс: C000 = Y
			ld	c,a
			inc	de
			ld	a,(de)
			inc	de
			ld	b,a
			xor	c
			push	af
			ld	a,c
			cpl
			ld	(hl),a
			pop	af
			ld	c,a
			inc	l
			ld	(hl),c
			inc	l
			ld	(hl),c
			inc	l
			ld	(hl),b
			inc	l
			ld	a,(sb_n)
			dec	a
			ld	(sb_n),a
			jp	nz,.db
.bot:		ld	a,l					; низ клетки: до кратной 8 строки
			rrca
			rrca
			cpl
			inc	a
			and	7
.fill:		or	a					; A строк (FF, 0, 0, 0) с HL
			ret	z
			ld	b,a
.f:			ld	(hl),0xFF
			inc	l
			ld	(hl),0
			inc	l
			ld	(hl),0
			inc	l
			ld	(hl),0
			inc	l
			dec	b
			jp	nz,.f
			ret
.multi:		ld	hl,STRIP			; несколько: вся полоса, смешивание по порядку записей
			ld	a,(rp_n)
			call	.fill
			ld	hl,sbt
.mn:		ld	a,(hl)
			ld	(sb_n),a
			inc	l
			ld	c,(hl)
			inc	l
			ld	e,(hl)
			inc	l
			ld	d,(hl)
			inc	l
			ld	a,(hl)
			inc	l
			push	hl
			cp	2
			jp	nz,.me
			call	.b
			jp	.mx
.me:		call	.en
.mx:		pop	hl
			ld	a,(sb_k)
			dec	a
			ld	(sb_k),a
			jp	nz,.mn
			ret
.rec:		call	sb_span				; запись HL: есть в столбце — в sbt (строк, первая, источник, кто)
			or	a
			ret	z
			ld	b,a
			ld	hl,sb_k
			ld	a,(hl)
			inc	(hl)
			ld	l,a
			add	a,a
			add	a,a
			add	a,l
			add	a,low sbt
			ld	l,a
			ld	h,high sbt
			ld	(hl),b
			inc	l
			ld	(hl),c
			inc	l
			ld	(hl),e
			inc	l
			ld	(hl),d
			inc	l
			ld	a,(sb_ri)
			ld	(hl),a
			ret
.b:			call	.dst				; смешивание Брюса (C = Y)
.bl:		ld	a,(de)
			ld	c,a
			inc	de
			ld	a,(de)
			ld	b,a
			inc	de
			xor	c					; (S, K) -> C = Y = S xor K
			ld	c,a
			ld	a,b
			or	c
			cpl
			and	(hl)
			ld	(hl),a
			inc	l
			ld	a,b
			or	c
			cpl
			and	(hl)
			or	c
			ld	(hl),a
			inc	l
			ld	a,b
			or	c
			cpl
			and	(hl)
			or	c
			ld	(hl),a
			inc	l
			ld	a,b
			or	c
			cpl
			and	(hl)
			or	b
			ld	(hl),a
			inc	l
			ld	a,(sb_n)
			dec	a
			ld	(sb_n),a
			jp	nz,.bl
			ret
.en:		call	.dst				; смешивание врага (C гасится)
.e:			ld	a,(de)
			ld	c,a
			inc	de
			ld	a,(de)
			ld	b,a
			inc	de
			xor	c					; (S, K) -> C = Y = S xor K
			ld	c,a
			ld	a,b
			or	c
			cpl
			and	(hl)
			ld	(hl),a
			inc	l
			ld	a,b
			or	c
			cpl
			and	(hl)
			ld	(hl),a
			inc	l
			ld	a,b
			or	c
			cpl
			and	(hl)
			or	c
			ld	(hl),a
			inc	l
			ld	a,b
			or	c
			cpl
			and	(hl)
			or	b
			ld	(hl),a
			inc	l
			ld	a,(sb_n)
			dec	a
			ld	(sb_n),a
			jp	nz,.e
			ret
.dst:		ld	a,c					; HL = STRIP + 4*C
			add	a,a
			add	a,a
			ld	l,a
			ld	h,STRIP >> 8
			ret
