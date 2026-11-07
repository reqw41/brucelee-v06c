; ---- вывод персонажей по плоскостям (решение владельца 05.11.2026) ----
; Ниндзя — синий (E000), Ямо — зелёный (A000): точка врага ставит свою плоскость и гасит две другие (чистый цвет
; поверх любого фона, 05.11); Брюс — три цвета с маской: строка — четвёрка (маска, точки C000, A000, E000). Плоскость:
;   (((тайл по операции & ~точки врагов чужих плоскостей) | точки врагов этой плоскости) & маска Брюса)
;   | точки Брюса этой плоскости | (бумага плоскости ? дырки маски Брюса : 0)
; Точка врага гасит две другие плоскости (05.11: враг — чистый цвет и поверх белого), поэтому любой показ
; перерисовывает все три плоскости. Дырка Брюса — ~(маска | C | A | E) (точки врагов в полосе гасят маску).
; Область рисуется полосами до 8 рядов клеток (полоса столбца STRIP — 64 строки по 4 байта, страница 9700).

; ---- перерисовка области ar0..ar1 x ac0..ac1 (rp_ps — всегда 7; repaint_ps оставлен для вызовов показа) ----
repaint:	ld	a,7
			ld	(rp_ps),a
repaint_ps:	ld	a,(ar0)
			ld	(rp_a0),a
			ld	(rp_r0),a
			ld	a,(ar1)
			ld	(rp_r1),a
.b:			ld	a,(rp_r0)			; полоса ar0 .. min(ar1, ar0 + 7)
			ld	(ar0),a
			add	a,7
			ld	b,a
			ld	a,(rp_r1)
			cp	b
			jp	c,.b1
			ld	a,b
.b1:		ld	(ar1),a
			call	rp_band
			ld	a,(ar1)
			ld	hl,rp_r1
			cp	(hl)
			jp	z,.e
			inc	a
			ld	(rp_r0),a
			jp	.b
.e:			ld	a,(rp_a0)
			ld	(ar0),a
			ret

rp_band:	ld	a,(ar1)
			ld	hl,ar0
			sub	(hl)
			inc	a
			ld	(rp_rows),a
			add	a,a
			add	a,a
			add	a,a
			ld	(rp_n),a
			call	pp_prep
			ld	a,(ac0)
.col:		ld	(rp_c),a
			call	col_prep
			ld	a,(rp_c)			; экран: H = E0 + столбец, L = 223 - 8*ar0
			add	a,0xE0
			ld	(rp_scr+1),a
			ld	a,(ar0)
			ld	l,a
			add	a,a
			add	a,a
			add	a,a
			cpl
			add	a,SCR_Y0+1
			ld	(rp_scr),a
			ld	h,0					; карта: 6000 + 32*ar0 + столбец
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	a,(rp_c)
			ld	e,a
			ld	d,0x60
			add	hl,de
			ld	(rp_map),hl
			ld	hl,(rp_vs)
			ld	(rp_vrow),hl
			ld	a,(rp_rows)
			ld	(rp_left),a
			ld	a,(wf_on)			; вспышка оружия — общий путь (ниже), иначе быстрые: одна плоскость или все три
			or	a
			jp	nz,.row
			jp	rp_all
.row:		ld	hl,(rp_map)
			ld	e,(hl)				; тайл
			ld	bc,amap - 0x6000
			add	hl,bc
			ld	a,(hl)
			or	a
			call	m,attr_fix			; мигание
			and	0x3F
			ld	(rp_at),a
			xor	a
			ld	(rp_flc),a
			ld	a,(wf_on)
			or	a
			jp	nz,.wf
.wd:		ld	l,e					; точки тайла: (6000) + 8n
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ex	de,hl
			ld	hl,(0x6000)
			add	hl,de
			ld	(rp_tile),hl
			ex	de,hl
			ld	a,(rp_mask)
			rrca
			ld	(rp_mask),a
			jp	c,.sp
			ld	a,(rp_ps)			; без точек спрайтов
			cp	7
			jp	nz,.p1
			ld	hl,(rp_scr)
			ld	a,(rp_at)
			call	plain_cell
			jp	.nx
.p1:		xor	a
			ld	(rp_cmc),a
			jp	.g
.sp:		ld	hl,(rp_vrow)		; источник: полоса столбца
			ld	(rp_src),hl
			ld	a,(rp_cm)
			ld	(rp_cmc),a
			cp	1					; четвёрки во всех плоскостях, чёрная бумага, без вспышки — вариант по чернилам
			jp	nz,.g
			ld	a,(rp_ps)
			cp	7
			jp	nz,.g
			ld	a,(rp_flc)
			or	a
			jp	nz,.g
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
			ld	hl,(rp_src)
.j:			call	0
			jp	.nx
.g:			ld	a,(rp_at)			; по плоскостям rp_ps
			ld	e,a
			ld	d,0
			ld	hl,optab
			add	hl,de
			ld	a,(hl)
			ld	(rp_ops),a
			ld	a,(rp_ps)
			and	1
			call	nz,pl_E
			ld	a,(rp_ps)
			and	2
			call	nz,pl_C
			ld	a,(rp_ps)
			and	4
			call	nz,pl_A
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
			jp	nz,.row
.ncol:		ld	a,(ac1)
			ld	hl,rp_c
			cp	(hl)
			ret	z
			ld	a,(hl)
			inc	a
			jp	.col
.wf:		ld	a,(rp_rows)			; вспышка оружия: строки 3..10, столбцы 11..20 — чернила XOR 7, спрайты чёрные
			ld	hl,rp_left
			sub	(hl)
			ld	hl,ar0
			add	a,(hl)
			sub	3
			cp	8
			jp	nc,.wd
			ld	a,(rp_c)
			sub	11
			cp	10
			jp	nc,.wd
			ld	a,(rp_at)
			xor	7
			ld	(rp_at),a
			ld	a,1
			ld	(rp_flc),a
			jp	.wd
