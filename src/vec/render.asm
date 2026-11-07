; render.asm: вывод Bruce Lee на экран Вектора (8 цветов, плоскости A000/C000/E000) — этап 3.
;
; ZX рисует в теневой экран E000 и копирует его на экран; у Вектора тени нет (память — под данные ZX).
; Здесь экран пишется сразу и каждый байт — один раз, итоговым значением (без мерцания):
; - клетка без спрайта: тайл 1 бит + атрибут (чернила/бумага) -> 3 плоскости (plain_cell);
; - клетка со спрайтами: полоса столбца (маска, точки по строкам, все персонажи) накладывается на тайл
;   (comp_cell). Спрайты ZX белые (чернила 7), «дырки» маски — цвета бумаги клетки.
; Персонажи: want — что нарисовала бы ZX в тень (plat_draw/plat_erase), disp — что на экране. Показ
; (plat_show/plat_screen, начало прохода, как C2EC/C29C на ZX) перерисовывает объединение старого и нового
; прямоугольника, если want != disp. Цвет: бит 0 ZX (синий) — E000, бит 1 (красный) — C000, бит 2 (зелёный) — A000;
; номер в палитре = цвет ZX (плоскость 8000 — данные ZX, палитра парами).
; Атрибуты клеток — amap (как F800 ZX): комната — из таблицы цветов тайлов; стены, оружие, мигание — свои.

SCR_Y0		equ	223					; младший байт адреса строки 0 ZX (экран ZX — строки 32..223 Вектора)

; ---- клетка без спрайта: HL = экран (H = E0+столбец, L = 223-8*строка), DE = 8 байт точек, A = атрибут (6 бит) ----
plain_cell:
			ld	c,a
			ld	b,0
			push	hl
			ld	hl,optab
			add	hl,bc
			ld	c,(hl)
			pop	hl
			push	hl
			push	de
			ld	a,c
			call	.pl
			pop	de
			pop	hl
			ld	a,h
			sub	0x20
			ld	h,a
			push	hl
			push	de
			ld	a,c
			rrca
			rrca
			call	.pl
			pop	de
			pop	hl
			ld	a,h
			sub	0x20
			ld	h,a
			ld	a,c
			rrca
			rrca
			rrca
			rrca
.pl:		and	3
			jp	z,p_0
			cp	2
			jp	c,p_t
			jp	z,p_nt
			jp	p_ff
p_0:		xor	a
p_fill:		REPT	7
			ld	(hl),a
			dec	l
			ENDR
			ld	(hl),a
			ret
p_ff:		ld	a,0xFF
			jp	p_fill
p_t:		REPT	7
			ld	a,(de)
			ld	(hl),a
			dec	l
			inc	e
			ENDR
			ld	a,(de)
			ld	(hl),a
			ret
p_nt:		REPT	7
			ld	a,(de)
			cpl
			ld	(hl),a
			dec	l
			inc	e
			ENDR
			ld	a,(de)
			cpl
			ld	(hl),a
			ret

cc_sp:		db	4					; cell_setup: 0 — клетка во вспышке оружия

; ---- атрибут: A = байт атрибута ZX -> A = 6 бит (мигание: чернила <-> бумага в нечётной фазе) ----
attr_fix:	or	a
			jp	p,.n
			push	de
			ld	e,a
			ld	a,(flash_ph)
			or	a
			ld	a,e
			jp	z,.p
			and	7
			add	a,a
			add	a,a
			add	a,a
			ld	d,a
			ld	a,e
			rrca
			rrca
			rrca
			and	7
			or	d
.p:			pop	de
.n:			and	0x3F
			ret

; ---- клетка комнаты (D = строка 2..23, E = столбец): атрибут из amap, точки тайла из карты 6000 ----
; выход: HL = экран, DE = точки, A = атрибут, cc_sp; NZ — клетка во вспышке оружия (не используется)
cell_setup:
			ld	a,d
			ld	(cs_r),a
			ld	a,e
			ld	(cs_c),a
			ld	l,d					; HL = строка*32 + столбец
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	d,0
			add	hl,de
			push	hl
			ld	de,0x6000
			add	hl,de
			ld	l,(hl)				; номер тайла -> точки: (6000) + n*8
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ex	de,hl
			ld	hl,(0x6000)
			add	hl,de
			ex	de,hl
			pop	hl
.am:		ld	bc,amap				; вход без точек тайла (вода): cs_r, cs_c, HL = строка*32 + столбец
			add	hl,bc
			ld	a,(hl)
			call	attr_fix
			ld	b,a
			ld	a,4
			ld	(cc_sp),a
			ld	a,(wf_on)			; вспышка оружия (D98D): строки 3..10, столбцы 11..20 — чернила XOR 7
			or	a
			jp	z,.nw
			ld	a,(cs_r)
			sub	3
			cp	8
			jp	nc,.nw
			ld	a,(cs_c)
			sub	11
			cp	10
			jp	nc,.nw
			ld	a,b
			xor	7
			ld	b,a
			xor	a
			ld	(cc_sp),a
.nw:		ld	a,(cs_c)			; экран
			add	a,0xE0
			ld	h,a
			ld	a,(cs_r)
			add	a,a
			add	a,a
			add	a,a
			cpl
			add	a,SCR_Y0+1
			ld	l,a
			ld	a,b
			ret
cs_r:		db	0
cs_c:		db	0


; ---- комната целиком (C16E..C29C): чёрная палитра; атрибуты из таблицы цветов; по плоскостям и столбцам
;      (операция плоскости на тайл — таблица в странице полосы); персонажей на экране нет ----
plat_room:
			ld	hl,pal_black
			call	pal_set_wait
			call	tile_fix			; цвета тайлов как у CPC (tilefix.asm)
			ld	hl,0x6040			; атрибуты из таблицы цветов (6003)
			ld	de,amap+0x40
			ld	a,(0x6003)
			ld	b,a
.at:		ld	c,(hl)
			ld	a,(bc)
			ld	(de),a
			inc	hl
			inc	de
			ld	a,h
			cp	0x63
			jp	nz,.at
			ld	hl,STRIP			; операции на тайл комнаты (с учётом пустых тайлов) — в странице полосы
.ot:		ld	a,(0x6003)
			ld	d,a
			ld	e,l
			ld	a,(de)
			and	0x3F
			ld	c,a
			ld	b,0
			ld	a,l					; пустой тайл?
			rrca
			rrca
			rrca
			and	0x1F
			ld	e,a
			ld	d,TILEBLANK >> 8
			ld	a,l
			and	7
			push	hl
			ld	l,a
			ld	h,0
			push	bc
			ld	bc,bitt
			add	hl,bc
			pop	bc
			ld	a,(de)
			and	(hl)
			ld	hl,optab
			jp	z,.nb
			ld	hl,optab_blank
.nb:		add	hl,bc
			ld	a,(hl)
			pop	hl
			ld	(hl),a
			inc	l
			jp	nz,.ot
			ld	a,(0x6001)			; база точек тайлов (младший байт 0) — в команду
			ld	(.gfx+1),a
			di							; очистка строк 2..23 трёх плоскостей через SP (на ZX загрузка комнаты — под DI)
			ld	hl,0
			add	hl,sp
			ld	(.ssp+1),hl
			ld	hl,0xA000 + SCR_Y0 - 15	; строки ZX 16..191: байты 32..207 столбца
			ld	de,0
.cl:		ld	sp,hl
			REPT	88
			push	de
			ENDR
			inc	h
			jp	nz,.cl
.ssp:		ld	sp,0
			ei
			ld	h,0xE0				; клетка — сразу три плоскости (06.11: прежде плоскость за плоскостью,
			ld	bc,0x6040			; тайл и адрес точек трижды): H = E0 + столбец, затем C0.., A0..
.col:		ld	l,SCR_Y0-16
.cell:		ld	a,(bc)				; тайл -> операции трёх плоскостей (биты 0-1 E000, 2-3 C000, 4-5 A000)
			ld	e,a
			ld	d,STRIP >> 8
			ld	a,(de)
			or	a					; (таблица — из optab, не больше 3F)
			jp	z,.z				; всё ноль — уже очищено
			ld	(rm_ops),a
			ld	a,e					; точки: база + n*8
			rlca
			rlca
			rlca
			ld	e,a
			and	7
.gfx:		add	a,0
			ld	d,a
			ld	a,e
			and	0xF8
			ld	e,a
			ld	a,(rm_ops)
			and	3
			call	nz,.d
			ld	a,h
			sub	0x20
			ld	h,a
			ld	a,(rm_ops)
			rrca
			rrca
			and	3
			call	nz,.d
			ld	a,h
			sub	0x20
			ld	h,a
			ld	a,(rm_ops)
			rlca
			rlca
			rlca
			rlca
			and	3
			call	nz,.d
			ld	a,h
			add	a,0x40
			ld	h,a
.z:			ld	a,l					; клетка ниже
			sub	8
			ld	l,a
			ld	a,c					; строка карты ниже
			add	a,32
			ld	c,a
			jp	nc,.c
			inc	b
.c:			ld	a,b
			cp	0x63
			jp	nz,.cell
			ld	a,c					; следующий столбец
			sub	32*22 & 0xFF
			ld	c,a
			ld	b,0x60
			inc	c
			inc	h
			ld	a,c
			cp	0x60
			jp	nz,.col
			jp	.end
; операция A (1 — точки, 2 — ~точки, 3 — FF) на 8 строк клетки HL (вниз), L и E сохраняются
.d:			dec	a
			jp	z,.t
			dec	a
			jp	z,.nt
			ld	a,0xFF
			REPT	8
			ld	(hl),a
			dec	l
			ENDR
.r:			ld	a,l
			add	a,8
			ld	l,a
			ret
.t:			REPT	8
			ld	a,(de)
			ld	(hl),a
			dec	l
			inc	e
			ENDR
.re:		ld	a,e
			sub	8
			ld	e,a
			jp	.r
.nt:		REPT	8
			ld	a,(de)
			cpl
			ld	(hl),a
			dec	l
			inc	e
			ENDR
			jp	.re
.end:
			xor	a					; на экране никого; want тоже (на ZX в проходе смены комнаты все стёрты,
			ld	(disp+0),a			; а таблица операций выше затёрла страницу 9700)
			ld	(disp+8),a
			ld	(disp+16),a
			ld	(want+0),a
			ld	(want+8),a
			ld	(want+16),a
			ld	(wf_on),a
			dec	a
			ld	(pd_dirs),a			; блоки кадров — искать заново (записи затёрты)
			ld	(pd_dirs+1),a
			ld	(pd_dirs+2),a
			call	room_pal			; палитра комнаты как у CPC (roompal.asm)
			ld	a,1
			ld	(isr_game),a		; конец DI загрузки комнаты (plat_rl_begin)
			ret
rm_ops:		db	0

; ---- тайл сменился (D60E/D626): HL = адрес в карте 6000.., A = тайл: атрибут из таблицы, перерисовать ----
plat_tile0:	ld	de,-0x6000			; (plat_tile — обёртка: шар колдуна XOR, wizball.asm)
			add	hl,de
			ld	a,l
			and	0x1F
			ld	e,a
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	d,h
			ld	h,d
			ld	l,e
			ld	b,1
			ld	c,1
			jp	plat_rect
; ---- прямоугольник сменившихся тайлов: H = строка, L = столбец, B = строк, C = столбцов ----
plat_rect:	push	hl
			push	bc
.r:			push	bc
			push	hl
.c:			push	bc
			push	hl
			ld	d,h
			ld	e,l
			ld	l,d
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	d,0
			add	hl,de
			push	hl
			ld	de,0x6000
			add	hl,de
			ld	c,(hl)
			ld	a,(0x6003)
			ld	b,a
			ld	a,(bc)
			pop	hl
			ld	de,amap
			add	hl,de
			ld	(hl),a
			pop	hl
			pop	bc
			inc	l
			dec	c
			jp	nz,.c
			pop	hl
			pop	bc
			inc	h
			dec	b
			jp	nz,.r
			pop	bc
			pop	hl
; ---- перерисовать прямоугольник с персонажами: H = строка, L = столбец, B = строк, C = столбцов ----
repaint_rc:	ld	a,h
			ld	(ar0),a
			add	a,b
			dec	a
			ld	(ar1),a
			ld	a,l
			ld	(ac0),a
			add	a,c
			dec	a
			ld	(ac1),a
			jp	repaint

; ---- перерисовка области ar0..ar1 x ac0..ac1 (строки 2..23, столбцы 0..31) ----
ar0:		db	0
ar1:		db	0
ac0:		db	0
ac1:		db	0
rp_c:		db	0
rp_n:		db	0					; строк области * 8
rp_mask:	db	0					; биты строк области, где есть точки спрайтов
rp_vs:		dw	0					; «виртуальная полоса» столбца: строка t -> rp_vs + u*t
rp_src:		dw	0
rp_scr:		dw	0
rp_map:		dw	0
rp_vrow:	dw	0
rp_tile:	dw	0
rp_left:	db	0
rp_rows:	db	0
rp_at:		db	0
rp_ps:		db	7					; плоскости перерисовки: 1 E000 (синяя), 2 C000 (красная), 4 A000 (зелёная)
rp_a0:		db	0
rp_r0:		db	0
rp_r1:		db	0
rp_cm:		db	0					; столбец: 0 — без точек, 1 — четвёрки (полоса STRIP)
rp_cmc:		db	0					; клетка: то же (0 — в клетке нет точек)
rp_flc:		db	0					; клетка во вспышке оружия
rp_ops:		db	0
rp_rs:		db	0					; шаг клетки в источнике: 8u
g_op:		db	0
g_k:		db	0
g_fl:		db	0
g_n:		db	0
pq_y:		db	0
pq_yo:		db	0
sb_n:		db	0
sb_k:		db	0
sb_ri:		db	0
sb_kind:	db	0
mbuf:		ds	3 * SPR_MAXB			; буферы отражения кадров (слоты Ниндзя, Ямо, Брюс)
sbt			equ	0x5C50				; до 3 записей: строк, первая строка, источник (2), кто (ОЗУ 5C05..5CFF свободно
										; после запуска — main.asm; 07.11, место внизу)
sb_cnt:		db	0
lowm:		db	0,1,3,7,15,31,63,127,255
			INCLUDE	"render_pl_t.asm"

bitt:		db	1,2,4,8,16,32,64,128,0

; ---- персонажи: want/disp — 3 записи по 8 байт: +0 есть (бит 7 — смотрит влево: рисуется отражение блока из mbuf),
;      +1 x, +2 y, +3 yo, +4 описатель, +6 видимый блок стороны 0 ----
; HL = запись персонажа ZX (NINJA, YAMO, BRUCE — младшие байты разные) -> HL = запись want, C = смещение 0/8/16
pers_slot:	ld	a,l
			ld	hl,want
			ld	c,0
			cp	low NINJA
			ret	z
			ld	l,low (want + 8)
			ld	c,8
			cp	low YAMO
			ret	z
			ld	l,low (want + 16)
			ld	c,16
			ret
			ASSERT	low NINJA != low YAMO && low NINJA != low BRUCE && low YAMO != low BRUCE
			ASSERT	high want = high (want + 23) && high want = high (disp + 23)
; C3CB: персонаж HL нарисован бы в тень (если жив): want = есть, x, y, yo, описатель, блок столбцов
plat_draw:	push	hl
			ld	a,l					; DE = запись want
			ld	de,want
			cp	low NINJA
			jp	z,.s
			ld	e,low (want + 8)
			cp	low YAMO
			jp	z,.s
			ld	e,low (want + 16)
.s:			inc	hl
			inc	hl
			ld	a,(hl)				; +2 поза
			or	a
			jp	z,.x
			ld	c,a
			ld	(pd_pose),a
			inc	hl
			ld	a,(hl)				; +3 сторона
			and	1
			ld	b,a
			inc	hl
			ld	a,(hl)				; +4 yo
			ld	(pd_yo),a
			inc	hl
			inc	hl
			ld	a,b					; +0 есть: 1, сторона 1 (влево) — 81 (кадр отражается в буфер, mirror_blk)
			rrca
			or	1
			ld	(de),a
			inc	de
			ld	a,(hl)				; +6 x
			ld	(de),a
			ld	(sb_x),a			; фаза ходьбы (spr_block)
			inc	de
			inc	hl
			ld	a,(hl)				; +7 y
			ld	(de),a
			inc	de
			ld	a,(pd_yo)
			ld	(de),a				; +3 yo
			inc	de
			pop	hl
			ld	a,c					; описатель: слово (поза-1)*4 + 0x16 записи
			dec	a
			add	a,a
			add	a,a
			add	a,0x16
			add	a,l
			ld	l,a
			jp	nc,.d
			inc	h
.d:			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
			ex	de,hl				; DE = описатель, HL = want+4
			ld	a,l					; C = номер записи (0..2)
			rrca
			rrca
			rrca
			and	3
			ld	c,a
			push	hl
			push	bc
			push	de
			call	tr_step				; входной кадр действия: сменился — пересчитать блок
			pop	de
			pop	bc
			pop	hl
			or	a
			jp	nz,.nb
			ld	a,(hl)				; блок столбцов: тот же кадр и сторона — прежний (spr_block — поиск)
			cp	e
			jp	nz,.nb
			inc	hl
			ld	a,(hl)
			cp	d
			dec	hl
			jp	nz,.nb
			push	hl
			ld	a,c
			add	a,low pd_dirs
			ld	l,a
			ld	h,high pd_dirs
			ld	a,b
			cp	(hl)
			pop	hl
			ret	z
.nb:		ld	(hl),e
			inc	hl
			ld	(hl),d
			inc	hl
			push	hl
			ld	a,c
			add	a,low pd_dirs
			ld	l,a
			ld	h,high pd_dirs
			ld	(hl),b
			ld	c,b
			ex	de,hl
			call	spr_block
			call	tr_pick				; в начале действия — входной кадр
			ex	de,hl
			pop	hl
			ld	(hl),e
			inc	hl
			ld	(hl),d
			ret
.x:			pop	hl
			ret
; входные и выходные кадры действий (spr_trx, 8 байт на описатель): DE = описатель, C = запись (0..2) -> A = 1, если
; блок надо пересчитать. Вошли в группу с входным блоком — TR_N показов он; вышли из группы G в описатель, у которого
; «группа выхода» G, — TR_N показов его блок выхода; кончился счёт — обычный кадр.
TR_N		equ	3
tr_step:	push	bc					; подмена кадра по состоянию (spr_sov) сменилась — тоже пересчитать
			push	de
			call	so_find
			ld	e,c
			ld	d,0
			ld	hl,so_last
			add	hl,de
			cp	(hl)
			ld	(hl),a
			ld	a,0
			jp	z,.s0
			inc	a
.s0:		ld	(so_frc),a
			pop	de
			pop	bc
			call	tr_step0
			ld	hl,so_frc
			or	(hl)
			ret
so_frc:		db	0
tr_step0:	ld	a,c
			ld	(tr_sl),a
			ex	de,hl
			ld	(tr_d),hl
			ld	b,0					; тот же описатель, что в прошлый раз, — группа та же (без поиска)
			push	hl
			ld	hl,tr_ld
			add	hl,bc
			ld	a,(tr_d)
			cp	(hl)
			ld	(hl),a
			pop	hl
			jp	z,.keep
			ld	a,l
			call	spr_find			; HL = 4*номер -> запись spr_trx (8*номер)
			add	hl,hl
			ld	de,spr_trx
			add	hl,de
			ld	(tr_e),hl
			ld	b,(hl)				; группа
			inc	hl
			ld	c,(hl)				; группа выхода
			ld	a,(tr_sl)
			ld	e,a
			ld	d,0
			ld	hl,tr_g
			add	hl,de
			ld	a,b
			cp	(hl)
			jp	z,.same
			ld	a,(hl)				; прошлая группа
			ld	(hl),b
			ld	hl,tr_m
			add	hl,de
			cp	c					; вышли из группы выхода этого описателя?
			jp	nz,.in
			or	a
			jp	z,.in
			ld	(hl),2				; выход
			jp	.cnt
.in:		ld	(hl),1				; вход (если есть входной блок)
			ld	a,b
			or	a
			jp	nz,.cnt
			ld	(hl),0
.cnt:		ld	hl,tr_c
			add	hl,de
			ld	a,(tr_sl)
			ld	e,a
			push	hl
			ld	hl,tr_m
			add	hl,de
			ld	a,(hl)
			pop	hl
			or	a
			jp	z,.z
			ld	a,TR_N
.z:			ld	(hl),a
			ld	a,1
			ret
.keep:		ld	a,(tr_sl)
			ld	e,a
			ld	d,0
.same:		ld	hl,tr_c
			add	hl,de
			ld	a,(hl)
			or	a
			ret	z
			dec	(hl)
			ld	a,0
			ret	nz
			inc	a
			ret
; запись C (0..2), состояние pd_pose -> A = номер подмены в spr_sov + 1 (0 — нет); портит HL, B
so_find:	ld	hl,spr_sov
			ld	b,1
.l:			ld	a,(hl)
			cp	0xFF
			jp	z,.no
			cp	c
			jp	nz,.n
			inc	hl
			ld	a,(pd_pose)
			cp	(hl)
			dec	hl
			ld	a,b
			ret	z
.n:			inc	hl
			inc	hl
			inc	hl
			inc	hl
			inc	b
			jp	.l
.no:		xor	a
			ret
so_last:	db	0, 0, 0
; HL = блок (spr_block) -> подмена по состоянию (spr_sov), иначе входной (tr_m 1) или выходной (2) блок, если идёт счёт записи tr_sl; портит A, B, DE
tr_pick:	push	hl
			ld	a,(tr_sl)
			ld	c,a
			call	so_find
			pop	hl
			or	a
			jp	z,.t
			push	de					; блок подмены: spr_sov + 4*(A-1) + 2
			add	a,a
			add	a,a
			sub	2
			ld	e,a
			ld	d,0
			ld	hl,spr_sov
			add	hl,de
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			ex	de,hl
			pop	de
			ret
.t:			ld	a,(tr_sl)
			ld	e,a
			ld	d,0
			push	hl
			ld	hl,tr_c
			add	hl,de
			ld	a,(hl)
			or	a
			jp	z,.no
			ld	hl,tr_m
			add	hl,de
			ld	a,(hl)
			ld	hl,(tr_e)
			inc	hl
			inc	hl					; +2 входной
			cp	2
			jp	nz,.g
			inc	hl
			inc	hl					; +4 выход
.g:			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			ld	a,d
			or	e
			jp	z,.no
			pop	hl
			ex	de,hl
			ret
.no:		pop	hl
			ret
tr_e:		dw	0
tr_m:		db	0, 0, 0
tr_sl:		db	0
tr_d:		dw	0
tr_g:		db	0, 0, 0
tr_c:		db	0, 0, 0
tr_ld:		db	0, 0, 0				; младший байт прошлого описателя (младшие байты описателей различны)
pd_dirs:	db	0xFF,0xFF,0xFF
pd_pose:	db	0
pd_yo:		db	0
			ASSERT	high pd_dirs = high (pd_dirs + 2)
			ASSERT	(low want & 31) = 0
; C366: стёрт бы из тени (если жив)
plat_erase:	push	hl
			inc	hl
			inc	hl
			ld	a,(hl)
			pop	hl
			or	a
			ret	z
			call	pers_slot
			ld	(hl),0
			ret
; C2EC для всех / C29C: показать изменения
plat_screen:
			ld	a,(wf_on)			; полная копия ZX снимает вспышку оружия с экрана
			or	a
			jp	z,plat_show
			xor	a
			ld	(wf_on),a
			ld	hl,0x030B
			ld	bc,0x080A
			call	repaint_rc
plat_show:	call	flash_redraw
			call	timer_now			; начало показов (ВИ53, счётчик 0 — вниз, 1,5 МГц)
			ld	(ps_t0),hl
			xor	a
			ld	(sh_def),a
			ld	b,16				; Брюс — первым (игрок), враги — если хватает времени прохода
			call	show_one
			ld	b,0
			call	show_late
			ld	b,8
; показ записи B, если с начала показов прошло меньше SH_LIMIT отсчётов; иначе — отложить (want != disp остаётся,
; дорисуется в следующем проходе; шаг логики не ждёт лишний кадр)
show_late:	push	bc
			call	timer_now
			ld	a,(ps_t0)
			sub	l
			ld	l,a
			ld	a,(ps_t0+1)
			sbc	a,h
			pop	bc
.lim:		cp	SH_LIMIT >> 8			; tools/vecscreens.js ставит FF — показ без откладывания
			jp	c,show_one
			ld	a,1
			ld	(sh_def),a
			ret
SH_LIMIT	equ	2000				; ~22 тыс. тактов: ещё один показ и шаг логики укладываются в кадр
ps_t0:		dw	0
sh_def:		db	0					; 1 — в этом проходе показ отложен (vecsoak: want != disp допустимо)
; CAE2 -> C2F7: показать область персонажа HL сразу
plat_show1:	call	pers_slot
			ld	b,c
; B = смещение записи: если want != disp — перерисовать объединение старого и нового прямоугольника
show_one:	ld	a,b
			add	a,low want
			ld	l,a
			ld	h,high want
			add	a,low disp - low want
			ld	e,a
			ld	d,h
			ld	a,(de)
			cp	(hl)
			jp	nz,.diff
			or	a					; оба «нет» — остальное не важно
			ret	z
			REPT	7					; байты 1..7 (0 уже равны)
			inc	hl
			inc	de
			ld	a,(de)
			cp	(hl)
			jp	nz,.diff
			ENDR
			ret
.diff:		ld	a,7					; все плоскости: точка врага гасит чужие
			ld	(rp_ps),a
			ld	a,b
			add	a,low want
			ld	l,a
			ld	h,high want
			ld	(so_w),hl
			add	a,low disp - low want
			ld	l,a
			ld	(so_d),hl

			call	rect_of				; старый
			ld	a,(rc_ok)
			ld	(so_ok),a
			ld	hl,rc_r0
			ld	de,so_r0
			call	cp4
			ld	hl,(so_d)			; disp = want
			ex	de,hl
			ld	hl,(so_w)
			REPT	7
			ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	de
			ENDR
			ld	a,(hl)
			ld	(de),a
			ld	hl,(so_d)
			call	mirror_blk			; влево — отражение кадра в буфер (старый прямоугольник уже посчитан)
			ld	hl,(so_d)
			call	rect_of				; новый
			ld	a,(so_ok)
			or	a
			jp	z,.new
			ld	a,(rc_ok)
			or	a
			jp	z,.old
			ld	hl,rc_r0			; объединение
			ld	de,ar0
			call	cp4
			ld	a,(so_r0)
			ld	hl,ar0
			cp	(hl)
			jp	nc,.u1
			ld	(hl),a
.u1:		ld	a,(so_c0)
			ld	hl,ac0
			cp	(hl)
			jp	nc,.u2
			ld	(hl),a
.u2:		ld	a,(so_r1)
			ld	hl,ar1
			cp	(hl)
			jp	c,.u3
			ld	(hl),a
.u3:		ld	a,(so_c1)
			ld	hl,ac1
			cp	(hl)
			jp	c,.u4
			ld	(hl),a
.u4:		ld	a,(ar1)
			ld	hl,ar0
			sub	(hl)
			cp	8
			jp	nc,.both
			ld	a,(ac1)
			ld	hl,ac0
			sub	(hl)
			cp	8
			jp	c,repaint_ps
.both:		call	.old
.new:		ld	a,(rc_ok)
			or	a
			ret	z
			ld	hl,rc_r0
			jp	paint4
.old:		ld	hl,so_r0
; HL -> 4 байта (r0, r1, c0, c1) -> ar0.. и перерисовать
paint4:		ld	de,ar0
			call	cp4
			jp	repaint_ps
cp4:		REPT	3
			ld	a,(hl)
			ld	(de),a
			inc	hl
			inc	de
			ENDR
			ld	a,(hl)
			ld	(de),a
			ret
so_w:		dw	0
so_d:		dw	0
; HL = запись -> rc_ok и прямоугольник rc_r0, rc_r1, rc_c0, rc_c1 (как ar0..ac1)
rect_of:	xor	a
			ld	(rc_ok),a
			ld	a,(hl)
			or	a
			ret	z
			call	vis_hdr				; DE = заголовок видимого блока (или буфера отражения)
			push	de
			inc	hl
			ld	a,(hl)				; x (со знаком)
			ld	(ro_x),a
			inc	hl
			ld	a,(hl)
			ld	(ro_y),a
			inc	hl
			ld	a,(hl)
			ld	(ro_yo),a
			pop	de					; рамка кадра — заголовок: vx, vw, vy, vh (vx, vy со знаком)
			ld	a,(de)				; x' = x + vx
			ld	hl,ro_x
			add	a,(hl)
			ld	(hl),a
			inc	de
			ld	a,(de)				; vw
			ld	b,a
			inc	de
			ld	a,(ro_yo)			; s = yo + vy + 64 (без знака: vy -24..+23)
			ld	l,a
			ld	a,(de)
			add	a,l
			add	a,64
			ld	l,a
			inc	de
			ld	a,(de)				; vh
			dec	a
			add	a,l					; s + vh - 1
			rrca
			rrca
			rrca
			and	0x1F
			sub	8
			ld	c,a					; r1 - y
			ld	a,l
			rrca
			rrca
			rrca
			and	0x1F
			sub	8
			ld	l,a					; r0 - y
			ld	a,(ro_y)
			add	a,l
			ld	(ro_y),a			; y' = y + (r0 - y)
			ld	a,c
			sub	l
			inc	a
			ld	c,a					; строк
			ld	a,(ro_x)			; c1 = x + w - 1; c0 = max(0, x)
			add	a,b
			dec	a
			cp	0x80
			ret	nc					; правый край левее экрана
			cp	32
			jp	c,.c1
			ld	a,31
.c1:		ld	(rc_c1),a
			ld	a,(ro_x)
			cp	0x80
			jp	c,.c0
			xor	a
.c0:		cp	32
			ret	nc
			ld	(rc_c0),a
			ld	a,(ro_y)			; r1 = y + h' - 1, не больше 23; r0 = max(2, y)
			add	a,c
			dec	a
			cp	2
			ret	c
			cp	24
			jp	c,.r1
			ld	a,23
.r1:		ld	(rc_r1),a
			ld	a,(ro_y)
			cp	24
			ret	nc
			cp	2
			jp	nc,.r0
			ld	a,2
.r0:		ld	(rc_r0),a
			ld	a,1
			ld	(rc_ok),a
			ret
; ---- прямой вывод: столбец с одним персонажем (strip_build -> dc_setup), rp_cm = 2: rp_vs = кадр - 2a (строка t
;      полосы — rp_vs + 2t), rp_rs = 16; клетки, целиком лежащие в строках персонажа [a, a+n), на чёрной бумаге —
;      dfq_* прямо из кадра; остальные (край фигуры, цветная бумага) — sb_cell в STRIP и путь четвёрок ----
dc_setup:	ld	hl,sbt
			ld	a,(hl)
			ld	(dc_n),a
			inc	l
			ld	c,(hl)				; a
			ld	a,c
			ld	(dc_a),a
			inc	l
			ld	e,(hl)
			inc	l
			ld	d,(hl)
			inc	l
			ld	a,(hl)
			ld	(sb_kind),a
			ex	de,hl
			ld	(dc_src),hl
			ld	a,c					; rp_vs = кадр - 2a
			add	a,a
			ld	e,a
			ld	a,l
			sub	e
			ld	l,a
			ld	a,h
			sbc	a,0
			ld	h,a
			ld	(rp_vs),hl
			ld	a,16
			ld	(rp_rs),a
			ld	a,2
			ld	(rp_cm),a
			ld	a,c					; целые ряды: f0 = (a+7)/8 <= r < f1 = (a+n)/8
			add	a,7
			rrca
			rrca
			rrca
			and	0x1F
			ld	(dc_f0),a
			ld	a,(dc_n)
			add	a,c
			rrca
			rrca
			rrca
			and	0x1F
			ld	(dc_f1),a
			ld	hl,dfq_tab			; таблица прямого вывода по виду: враг — dfq_e*, Брюс — dfq_b*
			ld	a,(sb_kind)
			cp	2
			jp	nz,.t
			ld	hl,dfq_tab+16
.t:			ld	(dc_tab),hl
			ret
rp_dc:		ld	a,(rp_rows)			; r = ряд полосы
			ld	hl,rp_left
			sub	(hl)
			ld	c,a
			ld	a,(rp_at)
			cp	8
			jp	nc,.q
			ld	a,c
			ld	hl,dc_f0
			cp	(hl)
			jp	c,.q
			inc	hl
			cp	(hl)
			jp	nc,.q
.d:			ld	hl,(rp_vrow)
.d2:		push	de
			ld	(dc_hl),hl
			ld	a,(rp_at)			; dc_tab + 2*чернила
			add	a,a
			ld	l,a
			ld	h,0
			ex	de,hl
			ld	hl,(dc_tab)
			add	hl,de
			ld	a,(hl)
			inc	hl
			ld	h,(hl)
			ld	l,a
			ld	(.j+1),hl
			pop	de
			ld	hl,(rp_scr)
			ld	b,h
			ld	c,l
			ld	hl,(dc_hl)
.j:			call	0
			jp	rp_all.nx
.q:			ld	a,(rp_at)			; край фигуры на чёрной бумаге — 8 строк в cb16 (вне фигуры нули) и прямо
			cp	8
			jp	nc,.qq
			push	de
			call	cb_cell
			pop	de
			ld	hl,cb16
			jp	.d2
.qq:		push	de					; цветная бумага: клетка в STRIP
			call	sb_cell
			pop	de
			ld	a,(rp_at)
			cp	8
			jp	nc,rp_all.gs
			add	a,a
			add	a,low cfq_tab
			ld	c,a
			ld	b,high cfq_tab
			ld	a,(bc)
			ld	(.k+1),a
			inc	bc
			ld	a,(bc)
			ld	(.k+2),a
			push	hl
			ld	hl,(rp_scr)
			ld	b,h
			ld	c,l
			pop	hl
.k:			call	0
			jp	rp_all.nx
; ряд C полосы -> HL = STRIP + 32C: строки ряда вне [a, a+n) — (FF, 0, 0, 0), внутри — четвёрки из кадра
sb_cell:	ld	a,c
			rrca
			rrca
			rrca
			ld	l,a					; 32r
			ld	h,STRIP >> 8
			push	hl
			ld	a,c
			add	a,a
			add	a,a
			add	a,a
			ld	b,a					; L0 = 8r
			ld	a,(dc_a)			; pre = clamp(a - L0, 0, 8)
			sub	b
			jp	nc,.p1
			xor	a
.p1:		cp	8
			jp	c,.p2
			ld	a,8
.p2:		push	af
			add	a,b					; start = L0 + pre
			ld	c,a
			ld	a,(dc_a)
			ld	e,a
			ld	a,(dc_n)
			add	a,e					; end = min(a+n, L0+8)
			ld	e,a
			ld	a,b
			add	a,8
			cp	e
			jp	nc,.p3
			ld	e,a
			ld	a,e
.p3:		ld	a,e
			sub	c					; mid = end - start
			ld	(sb_n),a
			ld	a,(dc_a)			; DE = кадр + 2*(start - a)
			ld	b,a
			ld	a,c
			sub	b
			add	a,a
			ld	l,a
			ld	h,0
			ex	de,hl
			ld	hl,(dc_src)
			add	hl,de
			ex	de,hl
			pop	af
			pop	hl
			push	hl
			call	strip_build.fill	; pre
			ld	a,(sb_kind)
			cp	2
			jp	nz,.en
			call	strip_build.db		; mid и до конца ряда (.bot)
			pop	hl
			ret
.en:		call	strip_build.de
			pop	hl
			ret
; ряд C полосы -> cb16: 8 строк по 2 байта (Y, K) из кадра, строки вне [a, a+n) — нули (тайл как есть)
cb_cell:	ld	a,c
			add	a,a
			add	a,a
			add	a,a
			ld	b,a					; L0 = 8r
			ld	hl,cb16
			xor	a
			REPT	16
			ld	(hl),a
			inc	hl
			ENDR
			ld	a,(dc_a)			; start = max(a, L0)
			cp	b
			jp	nc,.s
			ld	a,b
.s:			ld	c,a
			ld	a,(dc_a)
			ld	e,a
			ld	a,(dc_n)
			add	a,e
			ld	e,a					; a + n
			ld	a,b
			add	a,8
			cp	e					; end = min(a+n, L0+8)
			jp	c,.e
			ld	a,e
.e:			sub	c					; mid
			ret	z
			ret	c
			add	a,a
			ld	(cb_m2),a
			ld	a,c					; приёмник: cb16 + 2*(start - L0)
			sub	b
			add	a,a
			add	a,low cb16
			ld	l,a
			ld	h,high cb16
			push	hl					; приёмник
			ld	a,(dc_a)			; источник: кадр + 2*(start - a)
			ld	b,a
			ld	a,c
			sub	b
			add	a,a
			ld	e,a
			ld	d,0
			ld	hl,(dc_src)
			add	hl,de
			ex	de,hl
			pop	hl
			ld	a,(cb_m2)
			ld	b,a
.c:			ld	a,(de)
			ld	(hl),a
			inc	de
			inc	hl
			dec	b
			jp	nz,.c
			ret
cb_m2:		db	0
dc_hl:		dw	0
dc_tab:		dw	0
dc_a:		db	0
dc_n:		db	0
dc_src:		dw	0
dc_f0:		db	0
dc_f1:		db	0
			INCLUDE	"render_pl_x.asm"
; запись want/disp HL (L = low disp + 8*слот) -> DE = заголовок видимого блока: блок (+6) или, при бите 7 (+0), буфер
; отражения слота; HL не меняется
vis_hdr:	ld	a,(hl)
			push	hl
			or	a
			jp	m,.m
			ld	de,6
			add	hl,de
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			pop	hl
			ret
.m:			ld	a,l
			sub	low disp
			and	0x18
			rrca
			rrca
			rrca
			ld	e,a
			ld	d,0
			ld	hl,mb_tab
			add	hl,de
			add	hl,de
			ld	e,(hl)
			inc	hl
			ld	d,(hl)
			pop	hl
			ret
mb_tab:		dw	mbuf, mbuf + SPR_MAXB, mbuf + 2 * SPR_MAXB
; запись disp HL с битом 7 (+0): блок (+6) отражается в буфер слота, если там ещё не он (mb_src); заголовок:
; vx' = w - vx - vw (w — ширина описателя), vw, vy, vh; столбец j буфера = столбец vw-1-j блока, биты наоборот
mirror_blk:	ld	a,(hl)
			or	a
			ret	p
			ld	a,l
			sub	low disp
			and	0x18
			rrca
			rrca
			ld	(mb_s2),a			; 2*слот
			push	hl
			ld	de,4
			add	hl,de
			ld	e,(hl)				; описатель -> w
			inc	hl
			ld	d,(hl)
			ld	a,(de)
			ld	(mb_w),a
			inc	hl
			ld	e,(hl)				; блок
			inc	hl
			ld	d,(hl)
			pop	hl
			ld	a,(mb_s2)
			ld	c,a
			ld	b,0
			ld	hl,mb_src
			add	hl,bc
			ld	a,(hl)				; уже отражён?
			cp	e
			jp	nz,.go
			inc	hl
			ld	a,(hl)
			cp	d
			ret	z
			dec	hl
.go:		ld	(hl),e
			inc	hl
			ld	(hl),d
			ld	hl,mb_tab
			add	hl,bc
			ld	c,(hl)
			inc	hl
			ld	b,(hl)				; BC = буфер
			ld	a,(de)				; vx
			ld	l,a
			inc	de
			ld	a,(de)				; vw
			ld	(mb_vw),a
			add	a,l
			ld	l,a
			ld	a,(mb_w)
			sub	l
			ld	(bc),a				; vx' = w - vx - vw
			inc	bc
			ld	a,(mb_vw)
			ld	(bc),a
			inc	bc
			inc	de
			ld	a,(de)				; vy
			ld	(bc),a
			inc	bc
			inc	de
			ld	a,(de)				; vh -> байт в столбце 2vh
			ld	(bc),a
			inc	bc
			inc	de
			add	a,a
			ld	(mb_n),a
			push	bc					; данные буфера
			ex	de,hl				; HL = столбец 0 блока
			ld	e,a
			ld	d,0					; DE = n (байт в столбце)
			ld	a,(mb_vw)
.c0:		dec	a					; HL = последний столбец
			jp	z,.c1
			add	hl,de
			jp	.c0
.c1:		push	hl
			ld	h,d
			ld	l,e
			add	hl,hl
			ld	b,h
			ld	c,l
			add	hl,hl
			add	hl,bc				; 6n
			ex	de,hl
			ld	hl,mb_end			; вход в развёртку: mb_end - 6n
			ld	a,l
			sub	e
			ld	l,a
			ld	a,h
			sbc	a,d
			ld	h,a
			ld	(.j+1),hl
			pop	de					; DE = столбец-источник (с последнего)
			pop	bc					; BC = буфер (подряд)
.col:		ld	h,high rev8t
			push	de
.j:			call	0
			pop	de
			ld	a,(mb_n)			; предыдущий столбец источника
			ld	l,a
			ld	a,e
			sub	l
			ld	e,a
			ld	a,d
			sbc	a,0
			ld	d,a
			ld	a,(mb_vw)
			dec	a
			ld	(mb_vw),a
			jp	nz,.col
			ret
; развёртка копии столбца с обращением битов: DE -> BC, H = страница rev8t (6 однобайтовых команд на байт)
mb_seq:		REPT	SPR_MAXL
			ld	a,(de)
			inc	de
			ld	l,a
			ld	a,(hl)
			ld	(bc),a
			inc	bc
			ENDR
mb_end:		ret
mb_s2:		db	0
mb_w:		db	0
mb_vw:		db	0
mb_n:		db	0
mb_de:		dw	0
mb_src:		dw	0, 0, 0
ro_x:		db	0
ro_y:		db	0
ro_yo:		db	0
rc_ok:		db	0
rc_r0:		db	0
rc_r1:		db	0
rc_c0:		db	0
rc_c1:		db	0
so_ok:		db	0
so_r0:		db	0
so_r1:		db	0
so_c0:		db	0
so_c1:		db	0
	ASSERT	rc_c1 == rc_r0 + 3 && ac1 == ar0 + 3 && so_c1 == so_r0 + 3 && ar1 == ar0 + 1 && ac0 == ar0 + 2

; ---- вода (DE47 / DF11): HL = адрес экрана ZX 40xx.., B = столбцов, C = строк; FE9C бит 7 — вниз ----
; на ZX сдвигает точки прямо на экране (тень не трогает) — здесь тоже: плоскости, где чернила != бумага
plat_water:
			push	hl
			push	bc
			ld	hl,disp				; прямоугольники показанных персонажей: там вода не крутится (на ZX
			ld	de,wr_rects			; их каждый проход перекрывает копия из тени)
			ld	b,3
.rr:		push	bc
			push	de
			push	hl
			call	rect_of
			pop	hl
			pop	de
			ld	a,(rc_ok)
			ld	(de),a
			inc	de
			push	hl
			ld	hl,rc_r0
			call	cp4
			pop	hl
			ld	bc,8
			add	hl,bc
			pop	bc
			dec	b
			jp	nz,.rr
			pop	bc
			pop	hl
			ld	a,h					; строка = (H & 18) | (L >> 5), столбец = L & 1F
			and	0x18
			ld	d,a
			ld	a,l
			rlca
			rlca
			rlca
			and	7
			or	d
			ld	d,a
			ld	a,l
			and	0x1F
			ld	e,a
			ld	a,(zv_FE9C)			; бит 7 — вниз
			rlca
			sbc	a,a
			ld	(wt_dn),a
			ld	hl,-12				; SP внутри wrot: .r, .c — по 2 push, вызовы water_cell и wrot
			add	hl,sp
			ld	(wt_sp),hl
.r:			push	bc
			push	de
.c:			push	bc
			push	de
			call	water_cell
			pop	de
			pop	bc
			inc	e
			dec	b
			jp	nz,.c
			pop	de
			pop	bc
			inc	d
			dec	c
			jp	nz,.r
			ret
water_cell:	ld	a,d
			cp	24
			ret	nc
			ld	hl,wr_rects
			ld	b,3
.ck:		ld	a,(hl)				; есть, r0 <= D <= r1, c0 <= E <= c1 — пропустить
			inc	hl
			or	a
			jp	z,.cn
			ld	a,d
			cp	(hl)
			jp	c,.cn
			inc	hl
			ld	a,(hl)
			cp	d
			jp	c,.cn1
			inc	hl
			ld	a,e
			cp	(hl)
			jp	c,.cn2
			inc	hl
			ld	a,(hl)
			cp	e
			ret	nc
			dec	hl
.cn2:		dec	hl
.cn1:		dec	hl
.cn:		ld	a,l
			and	0xFF
			inc	hl
			inc	hl
			inc	hl
			inc	hl
			dec	b
			jp	nz,.ck
.go:		ld	h,e					; как cell_setup, без точек тайла: cs_r = D, cs_c = E (соседние байты)
			ld	l,d
			ld	(cs_r),hl
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	a,l
			or	e
			ld	l,a
			call	cell_setup.am		; HL = экран (синяя), A = атрибут
			ld	b,a					; плоскости, где чернила != бумага: бит 0 E000, 1 C000, 2 A000
			rrca
			rrca
			rrca
			xor	b
			and	7
			ret	z
			ld	(wt_m),a
			ld	(wt_p),hl
			rrca
			call	c,wrot
			ld	hl,(wt_p)
			ld	a,h
			sub	0x20
			ld	h,a
			ld	a,(wt_m)
			and	2
			call	nz,wrot
			ld	hl,(wt_p)
			ld	a,h
			sub	0x40
			ld	h,a
			ld	a,(wt_m)
			and	4
			call	nz,wrot				; (только вызовом: SP внутри wrot — wt_sp)
			ret
; 8 байт клетки с HL (строка 0, ниже — младшие адреса) — на 2 строки вверх (new[k] = old[k+2]) или вниз:
; это круговой сдвиг четырёх слов — через SP (pop x3, ex (sp),hl, push x3) под коротким DI
wrot:		ld	a,l
			sub	7
			ld	l,a					; слово строк 7, 6 (w0)
			ld	a,(wt_dn)
			or	a
			di
			ld	sp,hl
			jp	nz,.d
			pop	bc					; вверх: w3 <- w2, w2 <- w1, w1 <- w0, w0 <- w3
			pop	de
			pop	hl
			ex	(sp),hl
			push	de
			push	bc
			push	hl
			jp	.x
.d:			pop	hl					; вниз: w0 <- w1, w1 <- w2, w2 <- w3, w3 <- w0
			pop	bc
			pop	de
			ex	(sp),hl
			push	hl
			push	de
			push	bc
.x:			ld	hl,(wt_sp)
			ld	sp,hl
			ei
			ret
wt_sp:		dw	0
wt_p:		dw	0
wt_m:		db	0
wt_dn:		db	0

; ---- стены (DC27): атрибуты FA5D.. (строки 18..22, столбцы 29, 30) = L/H (0 — не видно, 86 — мигают) ----
plat_walls:	ld	de,amap+18*32+29
			ld	b,5
.l:			ld	a,l
			ld	(de),a
			inc	de
			ld	a,h
			ld	(de),a
			ld	a,e
			add	a,31
			ld	e,a
			ld	a,d
			adc	a,0
			ld	d,a
			dec	b
			jp	nz,.l
walls_paint:
			ld	hl,0x121D
			ld	bc,0x0502
			jp	repaint_rc

; ---- оружие (D98D) — только комната 18: колдун исчезает по точкам (finale.asm wiz_fade, владелец 07.11) ----
wf_on:		db	0

; ---- шапка: строка 0 — FEB2 (атрибут 38), строка 1 — hdr1_src (атрибут hdr1) ----
plat_header:
			ld	h,0xA0				; вне поля — чёрный (номер 1: только E000): строки 0..23, 40..47 (бывшая
.g:			ld	a,h					; строка 1 ZX — шапка поднята), 224..255 (решение владельца 05.11)
			cp	0xE0
			sbc	a,a
			cpl						; E000..FFFF -> FF, иначе 0
			ld	l,255
			REPT	24
			ld	(hl),a
			dec	l
			ENDR
			ld	l,SCR_Y0-8
			REPT	8
			ld	(hl),a
			dec	l
			ENDR
			inc	h					; 224..255 не трогаем: там логотип (lg_band, logo.asm)
			jp	nz,.g
			ld	hl,zv_FEB2
			ld	b,0
			ld	c,0x0C				; счёт: зелёный на чёрном, как CPC (было 38 — чёрный на белом)
			call	text_row
			ld	hl,zv_FED2
			ld	(hdr1_src),hl
hdr1_draw:	ld	hl,(hdr1_src)
			ld	a,(hdr1)			; надписи: бумага чёрная (1), чернила 0/1 -> зелёный (4)
			and	0xC7
			or	0x08
			ld	c,a
			and	6
			jp	nz,.k
			ld	a,c
			and	0xF8
			or	4
			ld	c,a
.k:			ld	b,1
			jp	text_row
; CACE: надпись HL в строке 1 с атрибутом C (на ZX — и копия экрана)
plat_msg:	ld	(hdr1_src),hl
			ld	a,c
			ld	(hdr1),a
			call	hdr1_draw
			jp	plat_screen
hdr1_src:	dw	zv_FED2
hdr1:		db	0x38
; 32 символа HL в строку B (0 или 1), атрибут C; рисуются только сменившиеся (тень hs_ch, hs_at;
; мигание и титул сбрасывают тень: hs_at = FF)
hs_ch		equ	0x5C10				; 64 байта (ОЗУ 5C05..5CFF, 07.11)
hs_at:		db	0xFF,0xFF
text_row:	push	hl
			ld	hl,hs_at
			ld	a,b
			or	a
			jp	z,.r0
			inc	hl
.r0:		ld	a,(flash_ph)		; мигающий атрибут в другой фазе — тоже «другой»
			rrca
			and	c
			and	0x80
			xor	c
			cp	(hl)
			ld	(hl),a
			ld	a,0
			jp	z,.same
			ld	a,1
.same:		ld	(tr_all),a
			ld	a,b					; тень строки: hs_ch + 32*B
			rrca
			rrca
			rrca
			ld	e,a
			ld	d,0
			ld	hl,hs_ch
			add	hl,de
			ld	(tr_sh),hl
			pop	hl
			ld	e,0
.l:			push	hl
			ld	a,(hl)
			ld	hl,(tr_sh)
			cp	(hl)
			ld	(hl),a
			inc	hl
			ld	(tr_sh),hl
			jp	nz,.dr
			ld	a,(tr_all)
			or	a
			jp	z,.nx
			dec	hl
			ld	a,(hl)
.dr:		push	bc
			push	de
			ld	d,b
			call	char_cell
			pop	de
			pop	bc
.nx:		pop	hl
			inc	hl
			inc	e
			ld	a,e
			cp	32
			jp	nz,.l
			ret
tr_all:		db	0
tr_sh:		dw	0
; символ A в клетку D (строка шапки 0/1 — рисуется на 8 строк выше: 24..39 Вектора), E (столбец), атрибут C
char_cell:	push	de
			sub	32
			ld	l,a
			ld	h,0
			add	hl,hl
			add	hl,hl
			add	hl,hl
			ld	de,FONT
			add	hl,de
			ex	de,hl				; DE = точки
			pop	hl					; H = строка, L = столбец
			ld	a,l
			add	a,0xE0
			ld	b,a
			ld	a,h
			dec	a					; шапка на строку выше экрана ZX (решение владельца 05.11)
			add	a,a
			add	a,a
			add	a,a
			cpl
			add	a,SCR_Y0+1
			ld	l,a
			ld	h,b
			ld	a,c
			call	attr_fix
			jp	plain_cell

; ---- мигание (FLASH ZX): прерывание раз в 16 кадров меняет фазу; перерисовать мигающее ----
flash_ph:	db	0
flash_dirty: db	0
flash_redraw:
			ld	a,(flash_dirty)
			or	a
			ret	z
			xor	a
			ld	(flash_dirty),a
			ld	a,(hdr1)
			or	a
			call	m,hdr1_draw
			ld	a,(amap+18*32+29)
			or	a
			ret	p
			jp	walls_paint

; ---- палитра ----
; цвет ZX i (яркий) -> %BBGGGRRR; номер i и i+8 одинаковы (плоскость 8000 — данные)
; игра — цвета CPC (решение владельца 05.11): 0 серый фон, 1 (синий ZX) — чёрный персонажей, 5 (голубой ZX) — фиолетовый
; титул и меню в цветах CPC (05.11): 0 (чернила) — тёмно-синий, 1 — синий (бумага выделения, логотип), 2 — красный,
; 7 (бумага) — серый
pal_title:	db	0x80,0x80,0x07,0xC7,0x38,0xF8,0x3F,0xA4, 0x80,0x80,0x07,0xC7,0x38,0xF8,0x3F,0xA4
pal_black:	ds	16
pal_ptr:	dw	pal_black
pal_load:	db	3
border:		db	0
; HL = палитра: загрузит прерывание (3 кадра подряд — вдруг промах мимо обратного хода)
pal_set:	ld	(pal_ptr),hl
			ld	a,3
			ld	(pal_load),a
			ret
pal_set_wait:
			call	pal_set
			ei
			halt
			ret

; ---- очистка трёх плоскостей (под DI, через SP) ----
clear_screen:
			di
			ld	hl,0
			add	hl,sp
			ld	(.ssp+1),hl
			ld	sp,0
			ld	de,0
.l:			REPT	32
			push	de
			ENDR
			ld	hl,0
			add	hl,sp
			ld	a,h
			cp	0xA0
			jp	nz,.l
			ld	a,l					; до самого A000 (шаг 64)
			or	a
			jp	nz,.l
.ssp:		ld	sp,0
			ei
			ret
