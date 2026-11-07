wizball3:	call	cell_setup			; HL — экран (E000), DE — точки шара (9EA8)
			ld	a,h
			sub	0x20				; плоскости C и A (владелец 07.11: жёлтый): на фоне — жёлтый (6), на малиновом — чёрный
			ld	h,a
			ld	c,8
.x:			ld	a,(de)				; строка: в текущую плоскость, переход в другую (C <-> A: H xor 60), в неё
			ld	b,a
			xor	(hl)
			ld	(hl),a
			ld	a,h
			xor	0x60
			ld	h,a
			ld	a,b
			xor	(hl)
			ld	(hl),a
			inc	de
			dec	l
			dec	c
			jp	nz,.x
			ret
