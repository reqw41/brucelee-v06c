;  wizcpc2.asm: начало выстрела колдуна (wizcpc.asm) — на месте глифов «;<=>?» шрифта (не используются)
wiz_new:	ld	hl,0x0810			; ряд 8, столбец 16 — как у ZX
			ld	(zv_FE17),hl
			ld	a,(zc_CCAB)			; столбец Брюса -> направление 0..4 (* 2): границы — середины точек падения
			ld	hl,wiz_thr			; огня (ряд 21: столбцы 3, 9.5, 16, 22.5, 29)
			ld	c,0
.t:			cp	(hl)
			jp	c,.d
			inc	hl
			inc	c
			inc	c
			jp	.t
.d:			ld	a,c
			ld	(wiz_dir),a
			ld	a,1
			ld	(zv_FE3C),a
			ret
wiz_thr:	db	6, 13, 19, 26, 0xFF
