"""Колдун комнаты 18 из исходного рисунка (docs/tasks/room18_art/current_preview.png) — тайлами без зеркала (06.11).
Клетки области колдуна (столбцы 9..22, ряды 0..10), отличные от нынешней комнаты, выравниваются по готовым тайлам
игры того же класса (до TOL точек — твёрдые, TOLP — проходимые; цвет готового тайла из других комнат — только его же),
остальные — новые узоры:
  - твёрдые — в номера, которые есть только в комнате 18 (все их клетки перерисованы), и в свободные — при сборке
    прямо в набор 9800 и таблицу 6300 («запекаются»);
  - проходимые — в свободные (запекаются), затем «заём» номеров 20..3F, которых нет в комнате 18: на время комнаты 18
    их узор и цвет меняются местами с запасом (tilefix.asm: r18_swap), при выходе — обратно.
Класс клетки (>= 40 твёрдая, 18..1F пол, иначе проходимая) не меняется — логика ZX та же.
Вход — build/zx_tap.bin, docs/tasks/room18_art/usage.json (номера по комнатам с учётом записей логики).
   python3 -I tools/mkroom18tiles.py [--preview]  -> build/room18_tiles.json (план для mkvecdata.py),
                                                   build/room18_tiles.png (предпросмотр)"""
import os, sys, json
from PIL import Image
ROOT = os.path.join(os.path.dirname(__file__), '..')
img = open(os.path.join(ROOT, 'build/zx_tap.bin'), 'rb').read()
w16 = lambda a: img[a] | img[a + 1] << 8
def rmap(n):                                     # карта комнаты n (704) из потока RLE ZX
    h = w16(0x6400 + 2 * n) + 0x40; m = bytearray()
    while img[h]:
        a = img[h]
        if a & 0x80: c = a & 0x7F; m += img[h + 1:h + 1 + c]; h += 1 + c
        else: m += bytes([img[h + 1]]) * a; h += 2
    return list(m)
mp = rmap(18)
pat = list(img[0x9800:0xA000])
attr = [img[0x6300 + t] for t in range(256)]
for t in range(0xAB, 0xF0):                      # цвета колдуна ZX в комнате 18 — как tools/mkroom18attr.py
    a = attr[t]
    if a & 7 == 2: a = (a & 0xF8) | 5
    elif a & 7 == 7: a = (a & 0xF8) | 2
    if t in (0xCB, 0xCC, 0xCD, 0xD3, 0xD4): a = 0x55
    attr[t] = a
for t in (0x18, 0x19): attr[t] = 0x46            # tile_fix: лестницы (FE) — жёлтые
U = json.load(open(os.path.join(ROOT, 'docs/tasks/room18_art/usage.json')))
used = {int(k): set(v) for k, v in U['usedBy'].items()}
dyn = set(U['dyn'])
B = Image.open(os.path.join(ROOT, 'docs/tasks/room18_art/base_256x176.png')).convert('RGB').load()
# колдун из превью по точкам (владелец 07.11: в превью перила по старому варианту — «лишние столбы»): его цвета
# (красный, синий, зелёный) и малиновые/чёрные точки не дальше WD от них (рога, наплечники, контур); остальное в области
# колдуна — фон без колдуна (open_fence_bg.png), вне области — нынешняя комната. В клетке больше двух цветов — лишние
# точки -> самый частый цвет клетки
WIZ = {(255, 0, 0), (0, 0, 255), (0, 255, 0)}; WD = int(os.environ.get('WD', 3)); POSTS = os.environ.get('POSTS', '1') == '1'
_P = Image.open(os.path.join(ROOT, 'docs/tasks/room18_art/current_preview.png')).convert('RGB')
_B = Image.open(os.path.join(ROOT, 'docs/tasks/room18_art/base_256x176.png')).convert('RGB')
_F = Image.open(os.path.join(ROOT, 'docs/tasks/room18_art/open_fence_bg.png')).convert('RGB')   # перила без колдуна
_p, _f = _P.load(), _F.load()
_wz = {(x, y) for y in range(88) for x in range(72, 184) if _p[x, y] in WIZ}
_C = _B.copy(); _c = _C.load()
for y in range(88):
    for x in range(72, 184):
        near = _p[x, y] in WIZ or (_p[x, y] in ((255, 0, 170), (0, 0, 0)) and any((x + dx, y + dy) in _wz for dx in range(-WD, WD + 1) for dy in range(-WD, WD + 1)))
        # столбы, за которые колдун держится, и перекладины к ним (владелец 07.11: «столбы и перекладины недорисованы») —
        # из превью целиком: столбики x 72..75, 87..92, 163..168, 180..183 и перекладины на уровне рук (строки 24..27)
        if POSTS and (any(a <= x <= b for a, b in ((72, 75), (87, 92), (163, 168), (180, 183))) and 16 <= y < 64 or
                      24 <= y <= 27 and (x < 81 or x > 175)): near = True
        _c[x, y] = _p[x, y] if near else _f[x, y]
# правка владельца из редактора (tools/room18_editor.html -> docs/tasks/room18_art/edit.txt): область целиком
_E = os.path.join(ROOT, 'docs/tasks/room18_art/edit.txt')
if os.path.exists(_E):
    _l = [l.strip() for l in open(_E, encoding='utf-8') if l.strip()]
    _h = _l[0].split(); assert _h[0] == 'ROOM18', 'edit.txt: заголовок'
    ex, ey, ew, eh = map(int, _h[1:]); _l = _l[1:]; assert len(_l) == eh and all(len(l) == ew for l in _l), 'edit.txt: размер'
    _RGB = {'.': (0, 0, 0), 'm': (255, 0, 170), 'r': (255, 0, 0), 'b': (0, 0, 255), 'g': (0, 255, 0), 'y': (255, 255, 0)}
    for y in range(eh):
        for x in range(ew): _c[ex + x, ey + y] = _RGB[_l[y][x]]
for r in range(11):
    for c in range(9, 23):
        cell = [_c[c * 8 + x, r * 8 + y] for y in range(8) for x in range(8)]
        keep = sorted(set(cell), key=lambda q: -cell.count(q))[:2]
        for y in range(8):
            for x in range(8):
                if _c[c * 8 + x, r * 8 + y] not in keep: _c[c * 8 + x, r * 8 + y] = keep[0]
_C.save(os.path.join(ROOT, 'build/room18_src.png'))
P = _C.load()
TOL = int(os.environ.get('TOL', 4)); TOLP = int(os.environ.get('TOLP', TOL))
cls = lambda t: 2 if t >= 0x40 else 1 if 0x18 <= t < 0x20 else 0
in18 = set(mp)
# не трогать и не брать: предметы и эффекты (< 18, у логики свои проверки), динамические других комнат. Путь шара
# колдуна (D0, DA, E3, EB, A5, 27) — можно: фон за шаром tile_redraw берёт из копии карты 5D00. Тайлы tile_fix (22..24,
# 30 — комната 19) занимать можно: tile_fix возвращает заём до своих правок и занимает снова после
SPECIAL = set(range(0x18)) | (dyn - in18) | {0xD5}   # D5: его узор (9EA8) — искра шара колдуна (room.asm, LD HL,9EA8)
RESERVED = set(range(0xE4, 0xE8))      # узоры E4..E7 (9F20..9F3F) — код русской сборки (main.asm, 08.11): не занимать
SPECIAL |= RESERVED
IDX = {(0, 0, 0): 0, (255, 0, 170): 7, (255, 0, 0): 2, (0, 0, 255): 5, (0, 255, 0): 4, (255, 255, 0): 6}
hd = lambda a, b: sum(bin(x ^ y).count('1') for x, y in zip(a, b))
def view(c, r):                                  # (узор: 1 = чернила, чернила, бумага) в номерах палитры
    v = [IDX[P[c * 8 + x, r * 8 + y]] for y in range(8) for x in range(8)]
    s = sorted(set(v)); ink, paper = s[0], s[-1]
    rows = tuple(sum((1 if v[y * 8 + x] == ink else 0) << (7 - x) for x in range(8)) for y in range(8))
    if ink == paper: rows = (0,) * 8
    return rows, ink, paper
BOX = [(r, c) for r in range(11) for c in range(9, 23)]
chg = [(r, c) for (r, c) in BOX if any(P[c * 8 + x, r * 8 + y] != B[c * 8 + x, r * 8 + y] for y in range(8) for x in range(8))]
keepcells = set(range(704)) - {r * 32 + c for r, c in chg}
fixattr = {mp[i]: attr[mp[i]] & 0x3F for i in keepcells}        # номера на неизменных клетках — цвет занят
newmap = list(mp); newattr = dict(fixattr); newpat = {}
freeS = [t for t in range(0x40, 256) if t not in used and t not in SPECIAL]
only18 = sorted(t for t in in18 if used.get(t) == {18} and t not in SPECIAL and t not in fixattr)
freeP = [t for t in range(0x20, 0x40) if t not in used and t not in SPECIAL]
borrowP = [t for t in range(0x20, 0x40) if t in used and t not in in18 and t not in SPECIAL and any(pat[t * 8:t * 8 + 8])]
poolS = [t for t in only18 if cls(t) == 2] + freeS; poolP = [t for t in only18 if cls(t) == 0] + freeP; borrowed = []
own = lambda t: used.get(t, set()) <= {18}       # цвет номера можно менять: он только в комнате 18 (или свободен)
lib = {k: [t for t in range(256) if cls(t) == k and t not in SPECIAL and t not in poolS and t not in poolP] for k in range(3)}
stat = {'готовый': 0, 'новый': 0, 'заём': 0}; byview = {}
order = sorted(chg, key=lambda k: (abs(k[1] - 15.5) + k[0]))
for (r, c) in order:
    k = cls(mp[r * 32 + c]); rows, ink, paper = view(c, r)
    a = (paper << 3) | ink
    key = (k, rows, a)
    if key in byview: newmap[r * 32 + c] = byview[key]; continue
    best = None                                  # готовый тайл того же класса: узор (или инверсия) в пределах допуска
    for t in lib[k]:
        tp = newpat.get(t, tuple(pat[t * 8:t * 8 + 8]))
        for inv in (0, 1):
            e = hd(rows, tuple((x ^ 0xFF) if inv else x for x in tp))
            want = ((ink << 3) | paper) if inv else a
            cur = newattr.get(t, attr[t] & 0x3F if not own(t) else None)
            if cur is not None and cur != want: continue
            if best is None or e < best[0]: best = (e, t, want, inv)
    if best and best[0] <= (TOL if k else TOLP):
        _, t, want, inv = best; newmap[r * 32 + c] = t; newattr[t] = want; byview[key] = t; stat['готовый'] += 1; continue
    pool = poolS if k == 2 else poolP
    if pool: t = pool.pop(0); stat['новый'] += 1
    elif k == 0 and [u for u in borrowP if u not in newattr]:
        t = [u for u in borrowP if u not in newattr][0]; borrowP.remove(t); borrowed.append(t); stat['заём'] += 1
        for kk in range(3):
            if t in lib[kk]: lib[kk].remove(t)
    else: sys.exit('нет номера для клетки %d,%d класса %d' % (r, c, k))
    newmap[r * 32 + c] = t; newattr[t] = a; newpat[t] = rows; byview[key] = t
assert all(cls(newmap[i]) == cls(mp[i]) for i in range(704))
# пустой твёрдый тайл (узор 0, цвет фона): после исчезновения колдуна (wiz_fade) — в копию карты 5D00 на его твёрдые клетки,
# чтобы шар (tile_redraw берёт номер из 5D00) не возвращал колдуна; класс клетки тот же
blank = poolS.pop(0); newpat[blank] = (0,) * 8; newattr[blank] = 0
# пустые тайлы (5B00) — по ZX: заёмные номера берутся только непустые (borrowP), их бит «пусто» = 0 — вывод обычный,
# верен и для пустого нового узора
# цвета номеров, которые меняются: свои (только 18 / свободные) — запекаются; чужие должны совпасть
bake = {}
for t, a in newattr.items():
    if t in borrowed: continue
    if (attr[t] & 0x3F) != a or t in newpat:
        assert own(t), ('цвет чужого номера', hex(t))
        bake[t] = a | (attr[t] & 0xC0)
bake[blank] = 0                          # пустой: чернила и бумага — фон (0), без яркости
plan = {'map': newmap, 'blank': blank,
        'bake': {t: {'attr': bake.get(t, attr[t]), 'pat': list(newpat.get(t, pat[t * 8:t * 8 + 8]))} for t in sorted(set(bake) | (set(newpat) - set(borrowed)))},
        'borrow': [{'t': t, 'attr': newattr[t] | (attr[t] & 0xC0), 'pat': list(newpat[t])} for t in borrowed]}
# клетки колдуна (рисунок не как фон без колдуна): исчезновение по точкам при подборе оружия (finale.asm wiz_fade)
_Fp = _F.load()                            # столбы колдуна (POSTS) исчезают вместе с ним — в фоне без колдуна их нет
plan['wizmask'] = [[1 if any(_c[c * 8 + x, r * 8 + y] != _Fp[c * 8 + x, r * 8 + y] for y in range(8) for x in range(8)) else 0
                    for c in range(9, 23)] for r in range(11)]
# одинаковые новые узоры (узор и цвет) — один номер (владелец 07.11: «оптимизируем экран колдуна»); оставляется
# запечённый (заём стоит 9 байт запаса в блобе логотипа); номера, которые пишет логика (dyn), не трогаются.
# MERGE=k — объединять и узоры, отличающиеся не больше чем на k точек (по умолчанию 0 — только одинаковые)
MERGE = int(os.environ.get('MERGE', 0))
_new = {int(t): (b['attr'], tuple(b['pat'])) for t, b in plan['bake'].items()}
_new.update({b['t']: (b['attr'], tuple(b['pat'])) for b in plan['borrow']})
_inmap = set(plan['map'][r * 32 + c] for r in range(11) for c in range(9, 23))
_cand = sorted((t for t in _new if (t in _inmap or t == blank) and t not in dyn),
               key=lambda t: (t != blank, t in {b['t'] for b in plan['borrow']}, t))   # пустой твёрдый — первым
_same = lambda x, y: (x & 0xBF) == (y & 0xBF)   # яркость (40) не выводится (attr_fix), логика цвета не читает
_to = {}
for i, a in enumerate(_cand):
    if a in _to: continue
    for b in _cand[i + 1:]:
        if b not in _to and _same(_new[a][0], _new[b][0]) and hd(_new[a][1], _new[b][1]) <= MERGE and cls(b) == cls(a): _to[b] = a   # класс клетки (твёрдая, пол, проходимая) — тот же
if _to:
    plan['map'] = [_to.get(t, t) if (i % 32) in range(9, 23) and i < 11 * 32 else t for i, t in enumerate(plan['map'])]
    plan['borrow'] = [b for b in plan['borrow'] if b['t'] not in _to]
    for t in _to: plan['bake'].pop(t, None)
assert not RESERVED & (set(plan['map']) | {int(t) for t in plan['bake']} | {b['t'] for b in plan['borrow']} | {blank}), 'занят зарезервированный номер'
_bad = [(i // 32, i % 32) for i in range(11 * 32) if cls(plan['map'][i]) != cls(mp[i])]
assert not _bad, 'класс клетки не как у ZX (логика): %s' % _bad[:5]
print('объединено одинаковых узоров: %d (%s)' % (len(_to), ', '.join('%02X->%02X' % kv for kv in sorted(_to.items()))))
# мигающий фонарик (владелец 07.11): номер 3 палитры комнаты 18 мигает (hi9540.asm wiz_lamp). Его тайлы — того же
# красного (07), что и номер 2: 8C, 97, A5, A6 (только комната 18) — запекаются с 2, 96 (ещё и в 19, там 3 — сокровища)
# и фонарик 14 (жёлтый 6 -> 3) — заём на время комнаты 18
L3 = lambda a: (a & 0xC0) | ((2 if (a >> 3) & 7 == 3 else (a >> 3) & 7) << 3) | (2 if a & 7 == 3 else a & 7)
for t in (0x8C, 0x97, 0xA5, 0xA6):
    b = plan['bake'].get(t) or {'attr': attr[t], 'pat': pat[t * 8:t * 8 + 8]}
    plan['bake'][t] = {'attr': L3(b['attr']), 'pat': list(b['pat'])}
assert all(b['t'] not in (0x96, 0x14) for b in plan['borrow'])
plan['borrow'] += [{'t': 0x96, 'attr': L3(attr[0x96]), 'pat': list(pat[0x96 * 8:0x97 * 8])},
                   {'t': 0x14, 'attr': (attr[0x14] & 0xF8) | 3, 'pat': list(pat[0x14 * 8:0x15 * 8])}]
json.dump(plan, open(os.path.join(ROOT, 'build/room18_tiles.json'), 'w'))
diff = 0
if '--preview' in sys.argv or True:
    pal = [0, 0, 7, 7, 56, 192, 63, 135]   # как в превью (фон 0 — чёрный), сверка с рисунком по номерам
    rgb = lambda c: ((c & 7) * 255 // 7, ((c >> 3) & 7) * 255 // 7, ((c >> 6) & 3) * 255 // 3)
    im = Image.new('RGB', (256, 176)); px = im.load()
    for r in range(22):
        for c in range(32):
            t = newmap[r * 32 + c]; rows = newpat.get(t, tuple(pat[t * 8:t * 8 + 8])); a = newattr.get(t, attr[t] & 0x3F)
            ink, paper = a & 7, (a >> 3) & 7
            for y in range(8):
                for x in range(8): px[c * 8 + x, r * 8 + y] = rgb(pal[ink]) if (rows[y] >> (7 - x)) & 1 else rgb(pal[paper])
    im.save(os.path.join(ROOT, 'build/room18_tiles.png'))
    diff = sum(1 for (r, c) in chg for y in range(8) for x in range(8) if px[c * 8 + x, r * 8 + y] != P[c * 8 + x, r * 8 + y])
print(f'комната 18: клеток меняется {len(chg)}; готовыми тайлами {stat["готовый"]}, новых узоров {stat["новый"]} '
      f'(запекается {len(plan["bake"])} номеров), заём {len(borrowed)}; отличие от рисунка {diff} точек')
