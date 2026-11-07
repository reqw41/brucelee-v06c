"""Проверка рисунка колдуна комнаты 18 по docs/tasks/ROOM18_ART_CONSTRAINTS.md:
   python3 -I tools/room18_check.py рисунок.png [база.png]"""
import sys, os
from PIL import Image
ROOT = os.path.join(os.path.dirname(__file__), '..')
A = Image.open(sys.argv[1]).convert('RGB'); B = Image.open(sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'docs/tasks/room18_art/base_256x176.png')).convert('RGB')
assert A.size == (256, 176), A.size
cls = open(os.path.join(ROOT, 'docs/tasks/room18_art/classes.txt')).read().split()
PAL = {(0, 0, 0), (255, 0, 170), (255, 0, 0), (0, 0, 255), (0, 255, 0), (255, 255, 0)}
a, b = A.load(), B.load()
cell = lambda im, c, r: tuple(im[c * 8 + x, r * 8 + y] for y in range(8) for x in range(8))
def canon(v):                                    # вид клетки: (узор по меньшему цвету, цвета)
    s = sorted(set(v)); return (tuple(1 if p == s[0] else 0 for p in v), tuple(s))
out = sum(1 for y in range(176) for x in range(256) if not (72 <= x < 184 and y < 88) and a[x, y] != b[x, y])
badpal = {a[x, y] for y in range(176) for x in range(256)} - PAL
many = 0; solid = set(); pas = set()
reuse = {canon(cell(b, c, r)) for r in range(22) for c in range(32)}   # готовые виды комнаты
base_pas = {canon(tuple([(0, 0, 0)] * 64)), canon(tuple([(255, 0, 170)] * 64))}
for r in range(11):
    for c in range(9, 23):
        v = cell(a, c, r)
        if len(set(v)) > 2: many += 1
        k = canon(v)
        if cls[r][c - 9] == '#': solid.add(k)
        else:
            if k not in reuse: pas.add(k)
print(f'пикселей вне области, отличных от базы: {out}; цвета вне палитры: {len(badpal)}; клеток > 2 цветов: {many}')
print(f'разных твёрдых клеток: {len(solid)} (≤ 70); новых проходимых: {len(pas)} (≤ 8)')
ok = out == 0 and not badpal and many == 0 and len(solid) <= 70 and len(pas) <= 8
print('ИТОГ:', 'укладывается' if ok else 'НЕ укладывается'); sys.exit(0 if ok else 1)
