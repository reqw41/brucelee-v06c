; Создано tools/mkplanes.py.
pl_tabs:
tabP:		dw	pb_0, pb_t, pb_nt, pb_ff
tabQ_E:	dw	qp_3, qu_3, qg_2, qg_3
tabQ_C:	dw	qp_1, qu_1, qg_2, qg_3
tabQ_A:	dw	qp_2, qu_2, qg_2, qg_3
pl_tabs_end:
qg_2:		ld	a,2
			ld	(g_op),a
			jp	qg
qg_3:		ld	a,3
			ld	(g_op),a
			jp	qg
pl_E:		ld	a,(rp_ops)
			and	3
			ld	e,a
			ld	(g_op),a
			ld	a,(rp_cmc)
			or	a
			jp	z,.p
.q:			ld	a,(rp_flc)
			or	a
			jp	nz,.f
			ld	hl,tabQ_E
			jp	.go
.f:			ld	hl,qgf
			jp	.g1
.p:			ld	hl,tabP
.go:		ld	a,e
			add	a,a
			add	a,l
			ld	l,a
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
.g1:		ld	(.j+1),hl
			ld	a,3
			ld	(g_k),a
			ld	a,(rp_scr+1)
			ld	b,a
			ld	a,(rp_scr)
			ld	c,a
			ld	hl,(rp_tile)
			ex	de,hl
			ld	hl,(rp_src)
.j:			jp	0
pl_C:		ld	a,(rp_ops)
			rrca
			rrca
			and	3
			ld	e,a
			ld	(g_op),a
			ld	a,(rp_cmc)
			or	a
			jp	z,.p
.q:			ld	a,(rp_flc)
			or	a
			jp	nz,.f
			ld	hl,tabQ_C
			jp	.go
.f:			ld	hl,qgf
			jp	.g1
.p:			ld	hl,tabP
.go:		ld	a,e
			add	a,a
			add	a,l
			ld	l,a
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
.g1:		ld	(.j+1),hl
			ld	a,1
			ld	(g_k),a
			ld	a,(rp_scr+1)
			sub	0x20
			ld	b,a
			ld	a,(rp_scr)
			ld	c,a
			ld	hl,(rp_tile)
			ex	de,hl
			ld	hl,(rp_src)
.j:			jp	0
pl_A:		ld	a,(rp_ops)
			rrca
			rrca
			rrca
			rrca
			and	3
			ld	e,a
			ld	(g_op),a
			ld	a,(rp_cmc)
			or	a
			jp	z,.p
.q:			ld	a,(rp_flc)
			or	a
			jp	nz,.f
			ld	hl,tabQ_A
			jp	.go
.f:			ld	hl,qgf
			jp	.g1
.p:			ld	hl,tabP
.go:		ld	a,e
			add	a,a
			add	a,l
			ld	l,a
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
.g1:		ld	(.j+1),hl
			ld	a,2
			ld	(g_k),a
			ld	a,(rp_scr+1)
			sub	0x40
			ld	b,a
			ld	a,(rp_scr)
			ld	c,a
			ld	hl,(rp_tile)
			ex	de,hl
			ld	hl,(rp_src)
.j:			jp	0
