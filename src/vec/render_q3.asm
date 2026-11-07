; ---- общий путь плоскости для четвёрок (бумага, вспышка): g_op — операция тайла, g_k — точки плоскости ----
;      строка: обычно ((тайл & маска) | точки k) | (бумага ? ~(маска | C | A | E) : 0);
;      вспышка (qgf): (тайл & маска & ~(C | A | E)) | (бумага ? ~(маска | C | A | E) : 0) — спрайты чёрные
qgf:		ld	a,1
			jp	qg0
qg:			xor	a
qg0:		ld	(g_fl),a
			ld	a,8
			ld	(g_n),a
.l:			push	bc
			ld	a,(de)				; операция тайла -> B
			ld	b,a
			ld	a,(g_op)
			cp	1
			jp	z,.tc
			cp	2
			jp	z,.t2
			jp	c,.t0
			ld	b,0xFF
			jp	.tc
.t0:		ld	b,0
			jp	.tc
.t2:		ld	a,b
			cpl
			ld	b,a
.tc:		ld	a,(g_fl)
			or	a
			jp	nz,.fl
			ld	a,b
			and	(hl)
			ld	b,a
			push	hl
			ld	a,(g_k)
			add	a,l
			ld	l,a
			jp	nc,$+4
			inc	h
			ld	a,b
			or	(hl)
			ld	b,a
			pop	hl
			jp	.ho
.fl:		inc	hl
			ld	a,(hl)
			inc	hl
			or	(hl)
			inc	hl
			or	(hl)
			dec	hl
			dec	hl
			dec	hl
			cpl
			and	(hl)
			and	b
			ld	b,a
.ho:		ld	a,(g_op)
			and	2
			jp	z,.st
			ld	a,(hl)
			inc	hl
			or	(hl)
			inc	hl
			or	(hl)
			inc	hl
			or	(hl)
			dec	hl
			dec	hl
			dec	hl
			cpl
			or	b
			ld	b,a
.st:		ld	a,b
			pop	bc
			ld	(bc),a
			dec	c
			inc	e
			inc	hl
			inc	hl
			inc	hl
			inc	hl
			ld	a,(g_n)
			dec	a
			ld	(g_n),a
			jp	nz,.l
			ret
