; запись pp HL -> её пересечение со столбцом rp_c: A = строк (0 — нет), DE = источник первой строки, C = первая
; строка в полосе, sb_cnt; биты клеток — в rp_mask
sb_span:	ld	a,(hl)
			or	a
			ret	z
			inc	hl
			ld	a,(rp_c)			; j = столбец - x; j >= w (беззнаково) — мимо
			sub	(hl)
			ld	c,a
			inc	hl
			ld	a,(hl)				; w
			cp	c
			jp	c,.no
			jp	z,.no
			inc	hl
			ld	e,(hl)				; шаг столбца
			ld	d,0
			inc	hl
			ld	b,(hl)				; первая строка
			inc	hl
			ld	a,(hl)
			ld	(sb_cnt),a
			inc	hl
			ld	a,(rp_mask)
			or	(hl)
			ld	(rp_mask),a
			inc	hl
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a					; источник столбца 0
.j:			dec	c					; + j*шаг
			jp	m,.jd
			add	hl,de
			jp	.j
.jd:		ex	de,hl
			ld	c,b
			ld	a,(sb_cnt)
			ret
.no:		xor	a
			ret

