; sound_h19.asm: часть sound.asm в дыре 19.
; ждать A кадров (по прерыванию)
snd_frames:	ld	hl,snd_fr
			add	a,(hl)
.w:			cp	(hl)
			jp	nz,.w
			ret

; появление Ямо (D2EB, CPC 70C3)
plat_appear:
			ld	hl,sfx_appear
			jp	snd_sfx
