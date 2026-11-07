; sound_h18.asm: часть sound.asm в дыре 18 (CODE_BUDGET).
; шаг Брюса (CEE9): шорох CPC 8C09 (аппаратная огибающая 1,3 мс) — перепад спикера сразу, голос ВИ53 не занимает
; (иначе шаги обрывали звук фонарика на том же голосе)
plat_click:	push	af
			ld	a,(spk_lv)
			xor	1
			ld	(spk_lv),a
			out	(0x00),a
			pop	af
			ret
