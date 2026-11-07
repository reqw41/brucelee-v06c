; sound_h4.asm: часть sound.asm в дыре 4.
; ---- музыка титула: вкл. (с начала) / выкл. (в дыре 4: tools/mkvecdata.py CODE_BUDGET) ----
snd_music_on:
			ld	hl,mus_v1
			ld	de,mus_v2
			jp	snd_play
snd_music_off:
			xor	a
			ld	(mus_on),a
			ret
