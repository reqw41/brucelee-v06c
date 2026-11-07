; ---- персонажи для полосы (один раз на полосу): pp — 3 записи по 10 байт (Ниндзя, Ямо, Брюс), всё, что не
;      зависит от столбца: +0 есть (пересекает строки), +1 x, +2 w, +3 шаг столбца (2vh), +4 первая строка в полосе,
;      +5 строк, +6 биты клеток (rp_mask), +7 источник первой строки в столбце 0. Рамка — содержимого кадра (заголовок
;      видимого блока: vx, vw, vy, vh), в строке 2 байта (свой цвет, чёрный) ----
pp_prep:	ld	hl,disp
			ld	de,pp
			ld	b,3
.p:			push	bc
			push	hl
			push	de
			xor	a
			ld	(de),a
			or	(hl)
			jp	z,.n
			call	vis_hdr				; DE = заголовок (блок или буфер отражения)
			push	de
			inc	hl
			ld	c,(hl)				; x
			inc	hl
			ld	a,(hl)
			ld	(pq_y),a
			inc	hl
			ld	a,(hl)
			ld	(pq_yo),a
			pop	hl					; заголовок блока
			pop	de					; запись pp
			push	de
			ld	a,c					; x' = x + vx (со знаком)
			add	a,(hl)
			ld	c,a
			inc	hl
			ld	b,(hl)				; vw
			ld	a,(ac1)				; x' > ac1 (x' >= 0) — правее
			cp	c
			jp	nc,.x1
			ld	a,c
			or	a
			jp	p,.n
.x1:		ld	a,c					; x' + vw - 1 < ac0 — левее
			add	a,b
			dec	a
			jp	m,.n
			push	hl
			ld	hl,ac0
			cp	(hl)
			pop	hl
			jp	c,.n
			ex	de,hl
			inc	hl
			ld	(hl),c				; +1 x
			inc	hl
			ld	(hl),b				; +2 w
			ex	de,hl
			inc	hl					; vy
			ld	a,(ar0)				; dy = y - ar0, только -8..11 (кадр может торчать вверх на 3 ряда)
			ld	c,a
			ld	a,(pq_y)
			sub	c
			add	a,8
			cp	20
			jp	nc,.n
			sub	8
			add	a,a
			add	a,a
			add	a,a
			ld	c,a
			ld	a,(pq_yo)
			add	a,c
			add	a,(hl)
			ld	b,a					; B = t0 = 8dy + yo + vy (со знаком)
			inc	hl
			ld	c,(hl)				; C = vh
			inc	hl					; HL = столбец 0
			ld	a,c
			add	a,a
			inc	de
			ld	(de),a				; +3 шаг столбца
			ld	a,b
			or	a
			jp	m,.neg
			ld	a,(rp_n)			; t0 >= 0: строк = min(vh, n - t0), первая = t0
			sub	b
			jp	z,.n
			jp	c,.n
			cp	c
			jp	c,.c0
			ld	a,c
.c0:		ld	c,a
			jp	.st
.neg:		cpl						; t0 < 0: s0 = -t0, строк = min(vh - s0, n), первая = 0, источник + 2*s0
			inc	a
			ld	b,a
			ld	a,c
			sub	b
			jp	z,.n
			jp	c,.n
			ld	c,a
			ld	a,(rp_n)
			cp	c
			jp	nc,.c1
			ld	c,a
.c1:		ld	a,b
			add	a,a
			add	a,l
			ld	l,a
			jp	nc,.c2
			inc	h
.c2:		ld	b,0
.st:		inc	de
			ld	a,b
			ld	(de),a				; +4 первая строка
			inc	de
			ld	a,c
			ld	(de),a				; +5 строк
			inc	de
			push	hl
			push	de
			ld	a,b					; биты клеток ia..ib: lowm[ib+1] & ~lowm[ia]
			add	a,c
			dec	a
			rrca
			rrca
			rrca
			and	7
			ld	e,a
			ld	d,0
			ld	hl,lowm+1
			add	hl,de
			ld	c,(hl)
			ld	a,b
			rrca
			rrca
			rrca
			and	7
			ld	e,a
			ld	hl,lowm
			add	hl,de
			ld	a,(hl)
			cpl
			and	c
			pop	de
			pop	hl
			ld	(de),a				; +6 биты
			inc	de
			ld	a,l
			ld	(de),a				; +7 источник
			inc	de
			ld	a,h
			ld	(de),a
			pop	de
			push	de
			ld	a,1
			ld	(de),a				; +0 есть
.n:			pop	de
			pop	hl
			ld	bc,10
			ex	de,hl
			add	hl,bc
			ex	de,hl
			ld	c,8
			add	hl,bc
			pop	bc
			dec	b
			jp	nz,.p
			ret
