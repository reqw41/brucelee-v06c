; Создано tools/mkplanes.py.
qu_1:
			REPT	7
			ld	a,(de)
			and	(hl)
			inc	hl
			or	(hl)
			inc	hl
			inc	hl
			inc	hl
			ld	(bc),a
			dec	c
			inc	e
			ENDR
			ld	a,(de)
			and	(hl)
			inc	hl
			or	(hl)
			ld	(bc),a
			ret
qp_1:
			REPT	7
			inc	hl
			ld	a,(hl)
			ld	(bc),a
			inc	hl
			inc	hl
			inc	hl
			dec	c
			ENDR
			inc	hl
			ld	a,(hl)
			ld	(bc),a
			ret
qu_2:
			REPT	7
			ld	a,(de)
			and	(hl)
			inc	hl
			inc	hl
			or	(hl)
			inc	hl
			inc	hl
			ld	(bc),a
			dec	c
			inc	e
			ENDR
			ld	a,(de)
			and	(hl)
			inc	hl
			inc	hl
			or	(hl)
			ld	(bc),a
			ret
qp_2:
			REPT	7
			inc	hl
			inc	hl
			ld	a,(hl)
			ld	(bc),a
			inc	hl
			inc	hl
			dec	c
			ENDR
			inc	hl
			inc	hl
			ld	a,(hl)
			ld	(bc),a
			ret
