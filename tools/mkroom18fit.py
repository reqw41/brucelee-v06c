"""Подгонка колдуна комнаты 18 под ограничения тайлов (docs/tasks/ROOM18_ART_CONSTRAINTS.md), 06.11.
Источник — превью (колдун 8x8-клетками), база — нынешняя комната. Колдун сжимается по высоте так, чтобы голова легла на
твёрдые ряды 3..4, а рога — на твёрдые клетки ряда 2 (столбцы 14 и 18); затем: в клетке 2 цвета, проходимые клетки —
готовые виды (чёрная, малиновая, малиновая с полосой, как в базе) + до NEW новых, твёрдые — не больше MAXS разных.
   python3 -I tools/mkroom18fit.py источник.png выход.png"""
import sys, os
from PIL import Image
ROOT = os.path.join(os.path.dirname(__file__), '..')
SRC = Image.open(sys.argv[1]).convert('RGB'); OUT = sys.argv[2]
BASE = Image.open(os.path.join(ROOT, 'docs/tasks/room18_art/base_256x176.png')).convert('RGB')
CLS = open(os.path.join(ROOT, 'docs/tasks/room18_art/classes.txt')).read().split()
NEW = int(os.environ.get('NEW', 8)); MAXS = int(os.environ.get('MAXS', 70))
Y0S, Y1S, Y0T = int(os.environ.get('Y0S', 0)), int(os.environ.get('Y1S', 72)), int(os.environ.get('Y0T', 18))
X0, X1 = 72, 184
s, b = SRC.load(), BASE.load()
img = BASE.copy(); p = img.load()
BG0 = Image.open(os.path.join(ROOT, 'docs/tasks/room18_art/open_fence_bg.png')).convert('RGB').load()
# 1) маска колдуна в источнике: красные/синие/зелёные точки и связанные с ними малиновые (заливка), кроме колонн
#    перил (по строке PILY вне красного) и перекладины (строки, где вне колдуна почти всё малиновое)
R, BL, G, MG = (255, 0, 0), (0, 0, 255), (0, 255, 0), (255, 0, 170)
PILY = int(os.environ.get('PILY', 20))
core = {(x, y) for y in range(0, 88) for x in range(X0, X1) if s[x, y] in (R, BL, G) and (y < 64 or BG0[x, y] != s[x, y])}
comps = []; seen = set()                          # связные куски (8 соседей); колдун — крупные
for q0 in core:
    if q0 in seen: continue
    comp = [q0]; seen.add(q0); st = [q0]
    while st:
        x, y = st.pop()
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q in core and q not in seen: seen.add(q); comp.append(q); st.append(q)
    comps.append(comp)
big = max(len(c) for c in comps)
core = {q for c in comps if len(c) >= big * 0.05 for q in c}
Y1S = max(y for _, y in core) + 1                 # низ колдуна — граница сжатия
pilpx = set()                                     # точки колонн перил: вертикальные малиновые отрезки от 30 точек
for x in range(X0, X1):
    y = 0
    while y < 88:
        if s[x, y] == MG:
            y1 = y
            while y1 < 88 and s[x, y1] == MG: y1 += 1
            if y1 - y >= 30: pilpx |= {(x, yy) for yy in range(y, y1)}
            y = y1
        else: y += 1
pil = set()
rail = set()
mask = set(core); st = list(core)
while st:
    x, y = st.pop()
    for dx, dy in ((a, c) for a in range(-2, 3) for c in range(-2, 3) if a or c):   # щель до 2 точек (контур)
        q = (x + dx, y + dy)
        if q in mask or not (X0 <= q[0] < X1 and 0 <= q[1] < Y1S): continue
        if s[q] != MG or q in pilpx or q[1] in rail: continue
        mask.add(q); st.append(q)
# фон области: перила раскрыты за колдуном (docs/tasks/room18_art/open_fence_bg.png)
BG = Image.open(os.path.join(ROOT, 'docs/tasks/room18_art/open_fence_bg.png')).convert('RGB').load()
PLAT = int(os.environ.get('PLAT', 64))           # с этой строки — площадка как в нынешней комнате
for x in range(X0, X1):
    for y in range(0, 88): p[x, y] = BG[x, y] if y < PLAT else b[x, y]
# под старым колдуном ZX на площадке — его основание: продолжить узор пола (перспектива: левая половина — узором
# слева, правая — справа; период 16 в строках 64..71, 24 в 72..87)
HX0, HX1 = 88, 168
for y in range(PLAT, 88):
    per = 16 if y < 72 else 24
    for x in range(HX0, 128):
        sx = x
        while sx >= HX0: sx -= per
        p[x, y] = b[sx, y]
    for x in range(128, HX1):
        sx = x
        while sx < HX1: sx += per
        p[x, y] = b[sx, y]
# сжатие по высоте только колдуна: источник y Y0S..Y1S -> Y0T..Y1S
for x in range(X0, X1):
    for y in range(Y0T, Y1S):
        sy = Y0S + (y - Y0T) * (Y1S - Y0S) // (Y1S - Y0T)
        if (x, sy) in mask: p[x, y] = s[x, sy]
if os.environ.get('DBG'): img.save(os.environ['DBG'])
# 2) клетки: 2 цвета
cell = lambda im, c, r: [im[c * 8 + x, r * 8 + y] for y in range(8) for x in range(8)]
def put(c, r, v):
    for i, col in enumerate(v): p[c * 8 + i % 8, r * 8 + i // 8] = col
d2 = lambda a, c: sum((x - y) ** 2 for x, y in zip(a, c))
def two(v):
    cols = sorted(set(v), key=lambda c: -v.count(c))
    if len(cols) <= 2: return v
    best = None
    for i in range(len(cols)):
        for j in range(i + 1, len(cols)):
            e = sum(min(d2(q, cols[i]), d2(q, cols[j])) for q in v)
            if best is None or e < best[0]: best = (e, cols[i], cols[j])
    _, a, c = best
    return [a if d2(q, a) <= d2(q, c) else c for q in v]
cells = {}
for r in range(11):
    for c in range(9, 23):
        v = two(cell(p, c, r)); cells[r, c] = v
diff = lambda u, v: sum(1 for x, y in zip(u, v) if x != y)
key = lambda v: tuple(v)
# 3) проходимые: готовые виды + до NEW новых (по важности — сколько точек колдуна в клетке)
K, M = (0, 0, 0), (255, 0, 170)
ready = [[K] * 64, [M] * 64, cell(b, 26 % 32, 0)]  # 26-й вид возьмём из базы ниже
ready = [[K] * 64, [M] * 64]
for r in range(22):
    for c in range(32):
        v = cell(b, c, r)
        if set(v) == {K, M} and key(v) not in map(key, ready) and all(v[i] == M for i in range(16, 64)): ready.append(v)
pas = [(r, c) for (r, c) in cells if CLS[r][c - 9] == '.']
imp = lambda v: sum(1 for q in v if q not in (K, M))
views = {}
for k in pas:
    v = cells[k]
    if min(diff(v, rv) for rv in ready) == 0: continue
    views.setdefault(key(v), []).append(k)
chosen = sorted(views, key=lambda kv: -sum(imp(list(kv)) for _ in views[kv]))[:NEW]
allowed = ready + [list(kv) for kv in chosen]
for k in pas:
    v = cells[k]; cells[k] = min(allowed, key=lambda a: diff(v, a))
# 4) твёрдые: слить до MAXS видов (ближайшие пары, одинаковые цвета)
sol = [(r, c) for (r, c) in cells if CLS[r][c - 9] == '#']
while True:
    vs = {}
    for k in sol: vs.setdefault(key(cells[k]), []).append(k)
    if len(vs) <= MAXS: break
    ks = list(vs); best = None
    for i in range(len(ks)):
        for j in range(i + 1, len(ks)):
            if set(ks[i]) != set(ks[j]): continue
            e = diff(ks[i], ks[j]) * min(len(vs[ks[i]]), len(vs[ks[j]]))
            if best is None or e < best[0]: best = (e, i, j)
    if best is None: break
    _, i, j = best; a, bb = ks[i], ks[j]
    keep, drop = (a, bb) if len(vs[a]) >= len(vs[bb]) else (bb, a)
    for k in vs[drop]: cells[k] = list(keep)
for k, v in cells.items(): put(k[1], k[0], v)
img.save(OUT); img.resize((1024, 704), Image.NEAREST).save(OUT.replace('.png', '_x4.png'))
print('готово:', OUT)
