wizball2:	ld	de,-0x6000			; D = ряд, E = столбец
			add	hl,de
			ld	a,l
			and	0x1F
			ld	e,a
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	d,h
			jp	wizball3
