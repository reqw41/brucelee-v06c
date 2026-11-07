"""Русская версия Bruce Lee (владелец 07.11): шрифт и тексты -> src/i8080/gen/ (font_ru.bin, ru_*.asm).
Шрифт — тот же CPC 32..95: русские буквы, похожие на латинские (А В Е К М Н О Р С Т Х), — латинские глифы; остальные
нарисованы в стиле CPC и раскладываются (place) по местам шрифта, которые тексты не используют (DATASOFT — латиницей); «П» — '#', © — '@' (как в английской). Глифы, занятые кодом (" $ % & ( ) + / ; < = > ? [ \\ ] ^ _), не
трогаются. Тексты подобраны так, чтобы уложиться в байты английских строк (main.asm: области FB00, FC17, FC8D, 9200).
   python3 -I tools/mkru.py"""
import os
ROOT = os.path.join(os.path.dirname(__file__), '..')
GEN = os.path.join(ROOT, 'src/i8080/gen')
font = bytearray(open(os.path.join(GEN, 'font.bin'), 'rb').read())

import sys
sys.path.insert(0, os.path.dirname(__file__))
from cyr8 import CYR, LAT
SLOT = dict(LAT, **{'П': '#', '©': '@'})
CODE = set('();<=>?[\\]^_')                    # глифы, занятые кодом в русской сборке ($%& + / " — код вынесен, main.asm)
def enc(s):
    bad = {c for c in s if c not in SLOT and (c in CYR or not (' ' <= c <= '_'))}
    assert not bad, 'нет в русском шрифте: %r (%s)' % (''.join(sorted(bad)), s)
    return [ord(SLOT.get(c, c)) for c in s]
def db(s): return '\t\tDB\t' + ','.join('0x%02X' % b for b in enc(s)) if s else ''
cen = lambda s: (32 - len(s)) // 2
def place(texts):                        # свои русские буквы — на места шрифта, которые тексты не используют сами
    lit = {SLOT.get(c, c) for t in texts for c in t if c not in CYR} | set('0123456789')   # цифры — очки
    need = sorted({c for t in texts for c in t if c in CYR}, key='БГДЖЗИЙЛУФЦЧШЩЪЫЬЭЮЯ'.index)
    pool = [chr(i) for i in range(33, 96) if chr(i) not in CODE and chr(i) not in lit]
    assert len(need) <= len(pool), 'не хватает мест в шрифте: русских букв %d, свободно %d (%s)' % (len(need), len(pool), ''.join(pool))
    for c, k in zip(need, pool):
        SLOT[c] = k
        o = (ord(k) - 32) * 8
        font[o:o + 8] = bytes(int(r.replace('#', '1').replace('.', '0'), 2) for r in CYR[c])
    open(os.path.join(GEN, 'font_ru.bin'), 'wb').write(bytes(font))
    return len(lit) + len(need), len(pool) - len(need)

# титул: (метка, ряд, текст) — ряды как у английского; строка старта — под полем (ряд 24, char_cell)
TITLE_A = [('ru_t0', 0, 'DATASOFT ПРЕДСТАВЛЯЕТ'), ('ru_vv1', 14, 'ВЕРСИЯ ДЛЯ ВЕКТОРА © 2026'),
           ('ru_vv2', 15, 'Б.ЛИХАЧЕВ И Н.ЗИМИН'), ('ru_ct1', 17, 'КЛАВИАТУРА - СТРЕЛКИ И ПРОБЕЛ'),
           ('ru_ct3', 19, '2 ИГРОКА - ЯМО НА ДЖОЙСТИКЕ П 1')]
START = 'НАЖМИТЕ 1 ИЛИ 2 ДЛЯ СТАРТА'
TITLE_B = [('ru_c0', 6, '© 1984 БРЮС ЛИ'), ('ru_c1', 7, 'ВСЕ ПРАВА СОХРАНЕНЫ'), ('ru_c2', 8, 'С СОГЛАСИЯ ZIV INTERNATIONAL'),
           ('ru_c3', 10, 'АВТОР РОН ДЖ. ФОРТЬЕ'), ('ru_c4', 12, 'ИГРА И ГРАФИКА © 1984 DATASOFT')]
TITLE_C = [('ru_ct2', 18, 'ИЛИ ДЖОЙСТИК П'), ('ru_tm', 21, 'ТОВАРНЫЙ ЗНАК ЛИНДЫ ЛИ')]
PAUSE = 'ПАУЗА - НАЖМИТЕ ВК'
GAME_OVER = 'ИГРА ОКОНЧЕНА'
WIN = [(4, 'ПОЗДРАВЛЯЕМ!'), (6, ''), (6, 'ЗЛОЙ КОЛДУН ПОВЕРЖЕН!'), (6, 'ЗОЛОТО И ТАЙНА БЕССМЕРТИЯ'), (6, 'ТЕПЕРЬ ВАШИ!')]
HEADER = 'И1 000000 РЕКОРД 000000 ЖИЗНИ 04'   # FEB2..FED1: номер игрока — FEB3, очки — FEB5, рекорд — FEC3, жизни — FED0
assert len(HEADER) == 32 and HEADER[3:9] == HEADER[17:23] == '000000' and HEADER[30:] == '04'

allt = [t for _, _, t in TITLE_A + TITLE_B + TITLE_C] + [START, PAUSE, GAME_OVER, HEADER] + [t for _, t in WIN]
nglyph, spare = place(allt)
HDR = '; Создано tools/mkru.py — не править руками.\n'
def lines(L): return ''.join('%s:\n%s\n' % (lab, db(t)) for lab, row, t in L)
open(os.path.join(GEN, 'ru_a.asm'), 'w').write(HDR + lines(TITLE_A) + 'ru_st1:\n%s\n' % db(START))
open(os.path.join(GEN, 'ru_b.asm'), 'w').write(HDR + lines(TITLE_B))
open(os.path.join(GEN, 'ru_c.asm'), 'w').write(HDR + lines(TITLE_C) +
    'pause_txt:\n%s\n' % db(PAUSE.center(32)) +
    'go_txt:\t\tDB\t%d, 10 + 1, 6, 0, 6\n%s\n\t\tDB\t0, 6, 0, 0xFF\n' % (len(GAME_OVER) + 2, db(GAME_OVER)))
w = max(len(t) for c, t in WIN) + 4
open(os.path.join(GEN, 'ru_win.asm'), 'w').write(HDR + 'win_txt:\tDB\t%d, %d + 1\n\t\tDB\t6, 0\n' % (w, (22 - len(WIN) - 2) // 2) +
    ''.join('\t\tDB\t%d\n%s\n\t\tDB\t0\n' % (c, db(t)) if t else '\t\tDB\t%d, 0\n' % c for c, t in WIN) + '\t\tDB\t6, 0, 0xFF\n')
# таблица t_lines (hi9540.asm): источник, позиция, длина; строка FB00 — t_init (title.asm), старт — под полем
tab = [(lab, row * 32 + cen(t), len(t)) for lab, row, t in TITLE_B + TITLE_A[1:] + TITLE_C]
open(os.path.join(GEN, 'ru_tab.asm'), 'w').write(HDR + ''.join('\t\t\tdw\t%s, 0x%04X\n\t\t\tdb\t%d\n' % e for e in tab) +
    'RU_T0_P\tequ\t%d\nRU_T0_N\tequ\t%d\n' % (cen(TITLE_A[0][2]), len(TITLE_A[0][2])))
open(os.path.join(GEN, 'ru_eq.asm'), 'w').write(HDR + 'ST1_C0\tequ\t%d\nST1_C1\tequ\t%d\n' % (cen(START), cen(START) + len(START)))
open(os.path.join(GEN, 'ru_hdr.asm'), 'w').write(HDR + db(HEADER) + '\n')
print('русская версия: знаков в шрифте %d, запас %d; байт: титул FB00 %d, FC17 %d, FC8D %d, финал %d' % (
    nglyph, spare, sum(len(t) for _, _, t in TITLE_A) + len(START), sum(len(t) for _, _, t in TITLE_B),
    sum(len(t) for _, _, t in TITLE_C) + 32 + len(GAME_OVER) + 9, 2 + sum(len(t) + 2 for _, t in WIN) + 3))
