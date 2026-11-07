"""Цвета тайлов колдуна AB..EF (они есть только в комнате 18) — при сборке прямо в таблицу 6300 (06.11): как правки
tile_fix для комнаты 18 (контур 7 -> красный 2, красные детали 2 -> синие 5, клетки CB..CD, D3..D4 — 0x55), но один
раз, без возврата исходных при каждом входе (экономия ~85 байт внизу).   -> src/i8080/gen/room18attr.asm"""
import os
ROOT = os.path.join(os.path.dirname(__file__), '..')
z = open(os.path.join(ROOT, 'build/zx_tap.bin'), 'rb').read()
out = []
for t in range(0xAB, 0xF0):
    a = z[0x6300 + t]
    if a & 7 == 2: a = (a & 0xF8) | 5
    elif a & 7 == 7: a = (a & 0xF8) | 2
    if t in (0xCB, 0xCC, 0xCD, 0xD3, 0xD4): a = 0x55
    out.append(a)
open(os.path.join(ROOT, 'src/i8080/gen/room18attr.asm'), 'w').write(
    '; Создано tools/mkroom18attr.py: цвета тайлов колдуна AB..EF (только комната 18)\n\t\t\tORG\t0x63AB\n\t\tDB\t'
    + ','.join('0x%02X' % a for a in out) + '\n')
