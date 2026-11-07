;  cheat2.asm: продолжение tw_keys (cheat.asm) — Ф1 (ряд 1, 08) и Ф3 (ряд 1, 20) вместе
tw_cheat:	ld	a,(vec_kbmat+1)
			and	0x28
			cp	0x28
			ret	nz
			xor	a					; NOP вместо DEC H: жизни не убывают
			ld	(bruce_died.live),a
			jp	go_1p
