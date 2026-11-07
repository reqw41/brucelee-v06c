; Платформа для сверки (tools/run80.js): ввод и случайность — из очередей эталона через особые порты,
; звук и щелчки — записи в порты; вывод — пустой.
;   IN E0 — следующее чтение порта ZX (очередь in), IN E1 — ld a,r (очередь r)
;   OUT E2,id — звук; OUT E3 — щелчок шагов; OUT E4 — «не моделируется» (меню, пауза, конец игры)
SND_JINGLE	equ	1
SND_DIE		equ	2
SND_KEY		equ	3
SND_HIT		equ	4

plat_keys:	IN	A,(0xE0)			; 7FFE
			RRA
			JP	C,.c135
			IN	A,(0xE0)			; FEFE
			RRA
			JP	C,.c135
			LD	A,1					; BREAK — рестарт
			RET
.c135:		IN	A,(0xE0)			; BFFE
			RRA
			LD	A,2					; ENTER — пауза
			RET	NC
			IN	A,(0xE0)			; 7FFE
			AND	2
			LD	A,4					; SYMBOL SHIFT — звук
			RET	Z
			XOR	A
			RET
plat_menu_keys:
plat_game_over:
			OUT	(0xE4),A
			RET
plat_rand:	IN	A,(0xE1)
			RET
plat_sound:	OUT	(0xE2),A
			RET
plat_click:	OUT	(0xE3),A
			RET
plat_state:
plat_appear:
plat_halts:
plat_show1:
plat_rl_begin:
plat_wait:
plat_rect:
plat_tile:
plat_water:
plat_room:
plat_walls:
plat_weapon:
plat_header:
plat_screen:
plat_show:
plat_erase:
plat_draw:
plat_win_msg:
			RET
