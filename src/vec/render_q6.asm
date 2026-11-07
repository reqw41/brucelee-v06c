; ---- быстрый путь: все три плоскости (показ Брюса, полная перерисовка), без вспышки оружия ----
;      без точек: чёрная бумага — pz_v по чернилам, иначе plain_cell; с точками: четвёрки на чёрной бумаге — cfq_v,
;      иначе — по плоскостям (pl_E, pl_C, pl_A)
rp_all:
.r:			ld	hl,(rp_map)
			ld	e,(hl)				; тайл
			ld	bc,amap - 0x6000
			add	hl,bc
			ld	a,(hl)
			or	a
			call	m,attr_fix
			and	0x3F
			ld	(rp_at),a
			ld	l,e					; точки тайла: (6000) + 8n
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ex	de,hl
			ld	hl,(0x6000)
			add	hl,de
			ex	de,hl
			ld	a,(rp_mask)
			rrca
			ld	(rp_mask),a
			jp	c,.sp
			ld	a,(rp_at)
			cp	8
			jp	nc,.pc
			add	a,a
			add	a,low pz_tab
			ld	l,a
			ld	h,high pz_tab
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
			ld	(.k+1),hl
			ld	hl,(rp_scr)
			ld	b,h
			ld	c,l
.k:			call	0
			jp	.nx
.pc:		ld	hl,(rp_scr)
			call	plain_cell
			jp	.nx
.sp:		ld	a,(rp_cm)
			cp	2
			jp	z,rp_dc				; один персонаж: прямо из кадра (render.asm)
			ld	a,(rp_at)
			cp	8
			jp	nc,.g
			add	a,a
			add	a,low cfq_tab
			ld	l,a
			ld	h,high cfq_tab
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
			ld	(.j+1),hl
			ld	hl,(rp_scr)
			ld	b,h
			ld	c,l
			ld	hl,(rp_vrow)		; источник: полоса
.j:			call	0
.nx:		ld	hl,(rp_vrow)
			ld	a,(rp_rs)
			ld	c,a
			ld	b,0
			add	hl,bc
			ld	(rp_vrow),hl
			ld	hl,(rp_map)
			ld	c,32
			add	hl,bc
			ld	(rp_map),hl
			ld	hl,rp_scr
			ld	a,(hl)
			sub	8
			ld	(hl),a
			ld	hl,rp_left
			dec	(hl)
			jp	nz,.r
			jp	rp_band.ncol
.g:			ld	hl,(rp_vrow)		; по плоскостям; .gs: HL = источник четвёрок, DE = точки тайла
.gs:		ld	(rp_src),hl
			ex	de,hl
			ld	(rp_tile),hl
			ld	a,1
			ld	(rp_cmc),a
			xor	a
			ld	(rp_flc),a
			ld	a,(rp_at)
			ld	e,a
			ld	d,0
			ld	hl,optab
			add	hl,de
			ld	a,(hl)
			ld	(rp_ops),a
			call	pl_E
			call	pl_C
			call	pl_A
			jp	.nx
