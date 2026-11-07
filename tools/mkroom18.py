"""Комната 18 по рисунку владельца (orig/room18_art.png, 256 x 180, раскладка ZX, вид CPC; 06.11): клетки 8 x 8 ->
два цвета из палитры комнаты; узоры тайлов, которые есть только в комнате 18, переопределяются на месте, для
общих клеток — новые номера того же класса (твёрдый >= 40, пол 18..1F, проходимый), свободные во всех комнатах.
Вход: build/room18.json (выгрузка с модели), выход: build/room18_preview.png, build/room18_plan.json. ЭКСПЕРИМЕНТ
(06.11): в сборку не входит — номеров тайлов и памяти не хватает (docs/JOURNAL.md)."""
import os, sys, json
from PIL import Image
ROOT = os.path.join(os.path.dirname(__file__), '..')
J = json.load(open(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'build/room18.json')))
PAL = {0: 0x00, 1: 0x00, 2: 0x07, 3: 0x80, 4: 0x38, 5: 0x46, 6: 0x3F, 7: 0x87}   # номер -> %BBGGGRRR
rgb = lambda c: ((c & 7) * 255 // 7, ((c >> 3) & 7) * 255 // 7, ((c >> 6) & 3) * 255 // 3)
PRGB = {k: rgb(v) for k, v in PAL.items()}
art = Image.open(os.path.join(ROOT, 'orig/room18_art.png')).convert('RGB').resize((256, 176), Image.NEAREST)
px = art.load()
d2 = lambda a, b: sum((x - y) ** 2 for x, y in zip(a, b))
IDX = [0, 2, 3, 4, 5, 6, 7]                     # 1 = 0 (оба чёрные) — берём 0
def fit(cx, cy):
    cells = [px[cx * 8 + x, cy * 8 + y] for y in range(8) for x in range(8)]
    best = None
    for i in range(len(IDX)):
        for j in range(i, len(IDX)):
            a, b = IDX[i], IDX[j]; e = 0; bits = []
            for p in cells:
                da, db = d2(p, PRGB[a]), d2(p, PRGB[b])
                bits.append(1 if da < db else 0); e += min(da, db)
            if best is None or e < best[0]: best = (e, a, b, bits)
    e, ink, paper, bits = best
    if not any(bits): ink = paper                # всё бумага
    if all(bits): paper = ink
    pat = [sum(bits[y * 8 + x] << (7 - x) for x in range(8)) for y in range(8)]
    if ink == paper: pat = [0] * 8               # однотонная — точки 0, цвет — бумага
    return tuple(pat), (0x40 | paper << 3 | ink)
mp, attr, pat = J['map'], J['attr'], J['pat']
cls = lambda t: 2 if t >= 0x40 else 1 if 0x18 <= t < 0x20 else 0
cur = lambda t: (tuple(pat[t * 8:t * 8 + 8]), attr[t])
def norm(c):                                     # одинаковый вид — одинаковый ключ (однотонные: только цвет бумаги)
    p, a = c; ink, paper = a & 7, (a >> 3) & 7
    if not any(p): return ((0,) * 8, paper)
    if all(x == 255 for x in p): return ((0,) * 8, ink)
    return (p, a & 0x3F)
new = {}
for r in range(22):
    for c in range(32):
        new[r, c] = fit(c, r)
used_other = {int(k) for k, v in J['usedBy'].items() if any(x != 18 for x in v)}
dyn = set(J['dyn'])
only18 = sorted({mp[i] for i in range(704)} - used_other - dyn)
free = [t for t in range(0x20, 256) if str(t) not in J['usedBy'] and t not in dyn]
# клетки, где вид меняется
ROWS = int(os.environ.get('ROWS', 12)); THR = int(os.environ.get('THR', 10))
def look(v):                                     # 64 точки в номерах палитры
    p, a = v; ink, paper = a & 7, (a >> 3) & 7
    f = lambda i: 0 if i == 1 else i
    return [f(ink) if (p[y] >> (7 - x)) & 1 else f(paper) for y in range(8) for x in range(8)]
def differs(k):
    a, b = look(new[k]), look(cur(mp[k[0] * 32 + k[1]]))
    return sum(1 for x, y in zip(a, b) if x != y) > THR
chg = {k: v for k, v in new.items() if k[0] < ROWS and differs(k)}
if os.environ.get('INPLACE'):                    # только узоры тайлов комнаты 18 на их местах, без новых номеров
    used_other0 = {int(k) for k, v in J['usedBy'].items() if any(x != 18 for x in v)}
    o18 = {mp[i] for i in range(704)} - used_other0 - set(J['dyn'])
    chg = {k: v for k, v in chg.items() if mp[k[0] * 32 + k[1]] in o18}
for k in list(new):                              # остальное — как сейчас
    if k not in chg: new[k] = cur(mp[k[0] * 32 + k[1]])
print('клеток всего 704, меняется', len(chg))
# назначение номеров: клетка берёт (1) уже назначенный вид в пределах TOL точек, (2) любой готовый тайл того же
# класса (не динамический) с узором в пределах TOL (или инверсией) — цвета в комнате 18 свои, (3) новый узор в номере
# из пула (свободные во всех комнатах + только комнаты 18, не оставленные), (4) иначе — ближайший доступный
TOL = int(os.environ.get('TOL', 6))
bitsof = lambda p: [(p[y] >> (7 - x)) & 1 for y in range(8) for x in range(8)]
hd = lambda a, b: sum(1 for x, y in zip(a, b) if x != y)
pool = {0: [t for t in free if cls(t) == 0], 1: [t for t in free if cls(t) == 1], 2: [t for t in free if cls(t) == 2]}
for t in only18:                                 # номер только комнаты 18, все клетки которого перерисовываются, — в пул
    if all((i // 32, i % 32) in chg for i in range(704) if mp[i] == t): pool[cls(t)].append(t)
idattr = {}                                      # номер -> атрибут в комнате 18 (одна запись в таблице 6300)
for i in range(704):
    t = mp[i]
    if (i // 32, i % 32) not in chg: idattr.setdefault(t, attr[t])
defs = {}; newmap = list(mp); short = 0
def assign_existing(o, v):
    vb = bitsof(v[0]); ink, paper = v[1] & 7, (v[1] >> 3) & 7
    best = None
    for t in range(256):
        if cls(t) != cls(o) or t in dyn or t in pool[cls(t)]: continue
        tb = bitsof(defs[t][0]) if t in defs else bitsof(pat[t * 8:t * 8 + 8])
        for inv in (0, 1):
            e = hd(vb, [b ^ inv for b in tb])
            want = (0x40 | (ink << 3 | paper) if inv else v[1])
            if t in idattr and idattr[t] & 0x3F != want & 0x3F: continue
            if best is None or e < best[0]: best = (e, t, want)
    return best
order = sorted(chg, key=lambda k: (abs(k[1] - 15.5) + abs(k[0] - 5)))      # от центра (колдун) к краям
if os.environ.get('INPLACE'):                    # узор на месте: номер тот же, карта та же
    for k in order:
        t = mp[k[0] * 32 + k[1]]
        if t not in defs: defs[t] = chg[k]; idattr[t] = chg[k][1]
    order = []
for k in order:
    o = mp[k[0] * 32 + k[1]]; v = chg[k]
    b = assign_existing(o, v)
    if b and b[0] <= TOL:
        newmap[k[0] * 32 + k[1]] = b[1]; idattr[b[1]] = b[2]; continue
    if pool[cls(o)]:
        t = pool[cls(o)].pop(0); defs[t] = v; idattr[t] = v[1]; newmap[k[0] * 32 + k[1]] = t; continue
    short += 1
    if b: newmap[k[0] * 32 + k[1]] = b[1]; idattr[b[1]] = b[2]
for t in only18:                                 # освободились ли номера комнаты 18 (не используются в новой карте)
    pass
print('новых узоров', len(defs), ', приблизительно (нет номеров)', short, ', осталось в пуле', {k: len(v) for k, v in pool.items()})
patch = [(i, newmap[i]) for i in range(704) if newmap[i] != mp[i]]
print('смена номеров в карте:', len(patch))
# предпросмотр
pv = Image.new('RGB', (256, 176))
for r in range(22):
    for c in range(32):
        t = newmap[r * 32 + c]; p = defs[t][0] if t in defs else tuple(pat[t * 8:t * 8 + 8]); a = idattr.get(t, attr[t])
        ink, paper = PRGB[a & 7], PRGB[(a >> 3) & 7]
        for y in range(8):
            for x in range(8): pv.putpixel((c * 8 + x, r * 8 + y), ink if (p[y] >> (7 - x)) & 1 else paper)
pv.save(os.path.join(ROOT, 'build/room18_preview.png'))
json.dump({'defs': {t: list(v[0]) for t, v in defs.items()}, 'attr': {t: a for t, a in idattr.items()}, 'patch': patch}, open(os.path.join(ROOT, 'build/room18_plan.json'), 'w'))
