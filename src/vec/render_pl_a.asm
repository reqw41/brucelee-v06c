; Создано tools/mkplanes.py — вывод клетки по плоскостям.
pb_0:		xor	a
pb_fill:	REPT	7
			ld	(bc),a
			dec	c
			ENDR
			ld	(bc),a
			ret
pb_ff:		ld	a,0xFF
			jp	pb_fill
pb_t:
			REPT	7
			ld	a,(de)
			ld	(bc),a
			dec	c
			inc	e
			ENDR
			ld	a,(de)
			ld	(bc),a
			ret
pb_nt:
			REPT	7
			ld	a,(de)
			cpl
			ld	(bc),a
			dec	c
			inc	e
			ENDR
			ld	a,(de)
			cpl
			ld	(bc),a
			ret
qu_3:
			REPT	7
			ld	a,(de)
			and	(hl)
			inc	hl
			inc	hl
			inc	hl
			or	(hl)
			inc	hl
			ld	(bc),a
			dec	c
			inc	e
			ENDR
			ld	a,(de)
			and	(hl)
			inc	hl
			inc	hl
			inc	hl
			or	(hl)
			ld	(bc),a
			ret
qp_3:
			REPT	7
			inc	hl
			inc	hl
			inc	hl
			ld	a,(hl)
			ld	(bc),a
			inc	hl
			dec	c
			ENDR
			inc	hl
			inc	hl
			inc	hl
			ld	a,(hl)
			ld	(bc),a
			ret
