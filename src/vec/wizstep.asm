;  wizstep.asm: обход клеток колдуна для wiz_fade (finale.asm) — гасит точку (wf_ln, wf_ms) в каждой клетке
;  wiz_mask; на последнем шаге (wf_k = 15) клетка в amap — фон, в копии карты 5D00 — пустая (WIZ_BLANK / 20). Лежит на месте текстов меню ZX (FBA7..FC16, меню убрано;
;  в run80 не выполняется — plat_weapon перехвачен)
wiz_step:	ld	hl,wiz_mask
			ld	e,0					; ряд
.r:			ld	c,(hl)
			inc	hl
			ld	b,(hl)
			inc	hl
			push	hl
			ld	d,0					; столбец
.c:			ld	a,b					; BC >> 1, CY — клетка колдуна
			or	a
			rra
			ld	b,a
			ld	a,c
			rra
			ld	c,a
			jp	nc,.nx
			push	bc
			ld	a,e					; L = 207 - (ряд * 8 + строка), H = A0 + 9 + столбец
			add	a,a
			add	a,a
			add	a,a
			ld	hl,wf_ln
			add	a,(hl)
			cpl
			add	a,208
			ld	l,a
			ld	a,d
			add	a,0xA9
			ld	h,a
			ld	a,(wf_ms)
			ld	b,a
			ld	c,3
.pl:		ld	a,(hl)
			and	b
			ld	(hl),a
			ld	a,h
			add	a,0x20
			ld	h,a
			dec	c
			jp	nz,.pl
			ld	a,(wf_k)				; последний шаг — клетка в amap: фон
			cp	15
			jp	nz,.na
			ld	a,e
			add	a,2
			ld	l,a
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	a,d
			add	a,9
			ld	c,a
			ld	b,0
			add	hl,bc
			push	hl
			ld	bc,amap
			add	hl,bc
			ld	(hl),0
			pop	hl
			ld	bc,0x6000			; карта 6040 (ряд + 2): класс клетки
			add	hl,bc
			ld	a,(hl)
			ld	bc,0x5D00-0x6000	; копия карты 5D00 (= 6000; из неё шар восстанавливает клетку): твёрдая — WIZ_BLANK,
			add	hl,bc				; проходимая — 20 (пол в клетках колдуна не бывает)
			cp	0x40
			ld	(hl),0x20
			jp	c,.na
			ld	(hl),WIZ_BLANK
.na:		pop	bc
.nx:		inc	d
			ld	a,d
			cp	14
			jp	nz,.c
			pop	hl
			inc	e
			ld	a,e
			cp	11
			jp	nz,.r
			ret
