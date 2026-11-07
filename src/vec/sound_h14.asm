; sound_h14.asm: часть sound.asm в дыре 14.
timer_init:	ld	a,0x34				; счётчик 0: режим 2, делитель FFFF (0 на MiSTer не стартует)
			out	(0x08),a
			ld	a,0xFF
			out	(0x0B),a
			out	(0x0B),a
			ret
snd_silence:
			ld	a,0x70				; счётчик 1: режим 0 без счёта — выход стоит
			out	(0x08),a
			ld	a,0xB0				; счётчик 2: так же
			out	(0x08),a
			ret

