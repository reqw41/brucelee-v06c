#!/usr/bin/env python3
"""Образ ROM Bruce Lee с заставкой: картинка загрузки ZX (лента BUGFIX, блок SCREEN$) — 16 цветов, 4 плоскости.

    python3 -I tools/mksplash.py      -> rom/BruceLee-v06c.r0m, rom/BruceLee-v06c.c00 (64 КБ с 0x0000), превью

Раскладка образа (src/vec/splash.asm): 0000 код заставки; 0100.. игра build/vec/brucelee.bin (0000..9FFF),
сжатая ZX0 (classic); 8000..FFFF — картинка (плоскости 8000 бит 3, A000 бит 2, C000 бит 1, E000 бит 0; строка
ZX y -> строка Вектора 32 + y). После клавиши палитра гаснет, сжатая игра переносится в A000.., распаковщик —
в F800, игра распаковывается в 0000..9FFF и запускается с 0000 (как без заставки).
Цвета: сочетание (цвет ZX, яркость) -> свой номер палитры; FLASH не мигает.
"""
import glob, os, subprocess, sys
RU = sys.argv[1:] == ['ru']                        # русская версия: build/vec/brucelee_ru.bin -> rom/BruceLee-v06c-ru.*
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
B = os.path.join(ROOT, 'build/vec/splash'); os.makedirs(B, exist_ok=True)
scr = open(glob.glob(os.path.join(ROOT, 'build/tape/bugfix/03_*.bin'))[0], 'rb').read()
assert len(scr) == 6912


def vec(c, br):                                   # цвет ZX -> %BBGGGRRR (обычный ~ 205/255, яркий — полный)
    if c == 0: return 0
    hi, hb = (7, 3) if br else (5, 2)
    return ((hb if c & 1 else 0) << 6) | ((hi if c & 4 else 0) << 3) | (hi if c & 2 else 0)


def rgb(v): return ((v & 7) * 255 // 7, ((v >> 3) & 7) * 255 // 7, ((v >> 6) & 3) * 255 // 3)


# решение владельца 05.11: картина раскрашена цветами титула CPC (orig/cpc/title_cpc.png — титул CPC, снятый с модели,
# 640x400), рисунок ZX: в каждой клетке 8x8 картины чернила и бумага — самые частые цвета CPC под их точками;
# надпись «spectrum version by» -> «vector-06c» / «version by» в две строки (шрифт ПЗУ ZX, 6 точек на знак)
scr = bytearray(scr)
def zxa(x, y): return ((y & 0xC0) << 5) | ((y & 7) << 8) | ((y & 0x38) << 2) | (x >> 3)
rom = open(os.path.join(ROOT, 'ref/48.rom'), 'rb').read()
for cx in range(1, 12): scr[6144 + 17 * 32 + cx] = scr[6144 + 19 * 32 + cx]   # ряд 17 — те же цвета, что у надписи
for row, txt in ((17, 'vector-06c'), (19, 'version by')):             # две строки: в одну 6-точечным шрифтом не влезает
    X0 = 8 + (88 - 6 * len(txt)) // 2
    for y in range(row * 8, row * 8 + 8):
        for cx in range(1, 12): scr[zxa(cx * 8, y)] = 0
    for i, ch in enumerate(txt):
        g = rom[0x3D00 + (ord(ch) - 32) * 8:0x3D00 + (ord(ch) - 32) * 8 + 8]
        for r in range(8):
            for b in range(6):
                if (g[r] >> (6 - b)) & 1:
                    x, y = X0 + 6 * i + b, row * 8 + r
                    scr[zxa(x, y)] |= 0x80 >> (x & 7)
cpc = Image.open(os.path.join(ROOT, 'orig/cpc/title_cpc.png')).convert('RGB')
cp = cpc.load(); cw, ch_ = cpc.size
C0, C1, R0, R1 = 276, 638, 84, 365          # картина CPC: кадр, при котором контуры ZX лучше всего ложатся на перепады CPC
Z0, Z1, Q0, Q1 = 13 * 8, 30 * 8, 5 * 8, 23 * 8                          # картина ZX (клетки 13..29, ряды 5..22)
def q8(c): return {0: 0, 128: 4, 255: 7}.get(c, c * 7 // 255)
def cvec(r, g, b): return ({0: 0, 128: 2, 255: 3}.get(b, b * 3 // 255) << 6) | (q8(g) << 3) | q8(r)
from collections import Counter
pixv = [[None] * 256 for _ in range(192)]
for y in range(192):
    for x in range(256):
        at = scr[6144 + (y >> 3) * 32 + (x >> 3)]
        c = at & 7 if (scr[zxa(x, y)] >> (7 - (x & 7))) & 1 else (at >> 3) & 7
        pixv[y][x] = vec(c, (at >> 6) & 1 if c else 0)
for cy in range(Q0 // 8, Q1 // 8):
    for cx in range(Z0 // 8, Z1 // 8):
        ci, cpp = Counter(), Counter()
        for y in range(cy * 8, cy * 8 + 8):
            for x in range(cx * 8, cx * 8 + 8):
                X = C0 + (x + 0.5 - Z0) * (C1 - C0) / (Z1 - Z0); Y = R0 + (y + 0.5 - Q0) * (R1 - R0) / (Q1 - Q0)
                v = cvec(*cp[int(X), int(Y)])
                (ci if (scr[zxa(x, y)] >> (7 - (x & 7))) & 1 else cpp)[v] += 1
        vi = ci.most_common(1)[0][0] if ci else None; vp = cpp.most_common(1)[0][0] if cpp else None
        if vi == vp and ci and cpp:                                     # не слить чернила с бумагой
            alt = [v for v, _ in (ci.most_common() if sum(ci.values()) < sum(cpp.values()) else cpp.most_common()) if v != vi]
            if alt:
                if sum(ci.values()) < sum(cpp.values()): vi = alt[0]
                else: vp = alt[0]
        for y in range(cy * 8, cy * 8 + 8):
            for x in range(cx * 8, cx * 8 + 8):
                on = (scr[zxa(x, y)] >> (7 - (x & 7))) & 1
                v = vi if on else vp
                if v is not None: pixv[y][x] = v
cnt = Counter(v for row in pixv for v in row)
pal = [v for v, _ in cnt.most_common()]
while len(pal) > 16:                                                    # редкие — в ближайший
    v = pal.pop(); near = min(pal, key=lambda u: sum((a - b) ** 2 for a, b in zip(rgb(u), rgb(v))))
    for row in pixv:
        for i, u in enumerate(row):
            if u == v: row[i] = near
if 0 in pal: pal.remove(0); pal.insert(0, 0)
idx = {v: i for i, v in enumerate(pal)}
pix = [[idx[v] for v in row] for row in pixv]
combos = {i: i for i in range(len(pal))}
pal16 = [0] * 16
for i, v in enumerate(pal): pal16[i] = v
pal = pal16
Y0 = 32                                           # строка Вектора первой строки картинки
ART = os.path.join(ROOT, 'orig/splash_art.png')   # решение владельца 06.11: своя картина на весь экран (не в git)
if os.path.exists(ART):
    art = Image.open(ART).convert('RGB').resize((256, 256), Image.LANCZOS)
    def vq(c): r, g, b = c; return (round(r * 7 / 255), round(g * 7 / 255), round(b * 3 / 255))
    q = art.quantize(colors=14, method=Image.Quantize.MEDIANCUT); qp = q.getpalette()[:42]; cols = []
    for i in range(14):
        c = vq(tuple(qp[3 * i:3 * i + 3]))
        if c not in cols: cols.append(c)
    for c in ((2, 6, 0), (6, 1, 0), (4, 7, 1)):     # зелёный, красный, светло-зелёный — медианный подбор их теряет
        if len(cols) < 16 and c not in cols: cols.append(c)
    if (0, 0, 0) in cols: cols.remove((0, 0, 0))
    cols = [(0, 0, 0)] + cols[:15]                    # номер 0 — чёрный: это и цвет бордюра (splash.asm, порт 02 = 0)
    P = Image.new('P', (1, 1)); flat = [v for R, G, B in cols for v in (R * 255 // 7, G * 255 // 7, B * 255 // 3)]
    P.putpalette(flat + [0] * (768 - len(flat)))
    # растр: Флойд-Стейнберг с половиной ошибки и взвешенным расстоянием (полный перенос ошибки сыпал зелёные точки
    # в кожу и фиолетовое — владелец 06.11)
    prgb = [(R * 255 / 7, G * 255 / 7, B * 255 / 3) for R, G, B in cols]
    src = [[list(art.getpixel((x, y))) for x in range(256)] for y in range(256)]
    greens = {i for i, (r, g, b) in enumerate(prgb) if g > r + 40 and g > b + 40}   # зелёные — только по зелёному
    def near(c, okg=True):
        best, bi = None, 0
        for i, (r, g, b) in enumerate(prgb):
            if not okg and i in greens: continue
            dr, dg, db = c[0] - r, c[1] - g, c[2] - b; rm = (c[0] + r) / 2
            d = (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db
            if best is None or d < best: best, bi = d, i
        return bi
    K = 0.5
    pix = [[0] * 256 for _ in range(256)]
    for y in range(256):
        for x in range(256):
            o = art.getpixel((x, y)); okg = o[1] > o[0] + 24 and o[1] > o[2] + 24   # точка картинки зелёная
            c = src[y][x]; i = near(c, okg); pix[y][x] = i
            e = [(c[k] - prgb[i][k]) * K for k in range(3)]
            for dx, dy, w in ((1, 0, 7), (-1, 1, 3), (0, 1, 5), (1, 1, 1)):
                X, Y = x + dx, y + dy
                if 0 <= X < 256 and Y < 256:
                    for k in range(3): src[Y][X][k] += e[k] * w / 16
    pal = [(B << 6) | (G << 3) | R for R, G, B in cols] + [0] * (16 - len(cols)); combos = {i: i for i in range(len(cols))}
    Y0 = 0
ZXS = os.path.join(ROOT, 'build/tape/bugfix/03_Bruce_Lee\u00aa.bin')   # загрузочный экран ZX (SCREEN$ ленты BUGFIX)
if os.path.exists(ART) and os.path.exists(ZXS):
    # решение владельца 06.11 (позже): раскладка и логотипы загрузочного экрана ZX (BRUCE LEE, Datasoft) в цветах CPC
    # (красный, жёлтый, полоски серые), справа в рамке картины ZX — своя картина целиком; внизу слева вместо
    # «spectrum version by / ocean» — «VECTOR-06C VERSION» шрифтом CPC. ZX 256x192 -> строки Вектора 32..223.
    zs = open(ZXS, 'rb').read()
    def zxa(x, y): return ((y & 0xC0) << 5) | ((y & 7) << 8) | ((y & 0x38) << 2) | (x >> 3)
    CPCC = {0: (0, 0, 0), 2: (7, 0, 0), 6: (7, 7, 0), 7: (4, 4, 2)}   # цвет ZX -> CPC (3-3-2): чёрный, красный, жёлтый, серый
    cols = [(0, 0, 0), (7, 0, 0), (7, 7, 0), (4, 4, 2)]
    PX0, PX1, PY0, PY1 = 104, 240, 40, 184          # рамка картины ZX (клетки 13..29, ряды 5..22)
    W, H = PX1 - PX0, PY1 - PY0
    art = Image.open(ART).convert('RGB').resize((W, H), Image.LANCZOS)   # целиком (по высоте ~1,06: точка Вектора шире)
    def vq(col): r, g, b = col; return (round(r * 7 / 255), round(g * 7 / 255), round(b * 3 / 255))
    def back(q): R, G, B_ = q; return (R * 255 // 7, G * 255 // 7, B_ * 255 // 3)
    q = art.quantize(colors=32, method=Image.Quantize.MEDIANCUT); qp = q.getpalette()[:96]
    cand = [vq(tuple(qp[3 * i:3 * i + 3])) for i in range(32)]
    dd = lambda a_, b_: sum((x - y) ** 2 for x, y in zip(back(a_), back(b_)))
    cnt = {}
    for c_ in art.getdata(): k = vq(c_); cnt[k] = cnt.get(k, 0) + 1
    while len(cols) < 16:                              # самые далёкие (с учётом частоты) от уже взятых
        rest = [x for x in set(cand) | set(cnt) if x not in cols]
        cols.append(max(rest, key=lambda x: min(dd(x, y) for y in cols) * (cnt.get(x, 0) + 50) ** 0.5))
    prgb = [back(x) for x in cols]
    Y0 = 32
    pix = [[0] * 256 for _ in range(192)]
    for y in range(192):
        for x in range(256):
            if PX0 <= x < PX1 and PY0 <= y < PY1: continue
            if x < 96 and y >= 120: continue           # «spectrum version by» и ocean — убрать
            at = zs[6144 + (y >> 3) * 32 + (x >> 3)]; o = (zs[zxa(x, y)] >> (7 - (x & 7))) & 1
            c_ = at & 7 if o else (at >> 3) & 7
            pix[y][x] = cols.index(CPCC.get(c_, (0, 0, 0)))
    src = [[list(art.getpixel((x, y))) for x in range(W)] for y in range(H)]
    for y in range(H):                                 # Флойд-Стейнберг с половиной ошибки
        for x in range(W):
            c_ = src[y][x]; i = min(range(16), key=lambda k: sum((c_[t] - prgb[k][t]) ** 2 for t in range(3)))
            pix[PY0 + y][PX0 + x] = i
            e = [(c_[t] - prgb[i][t]) * 0.5 for t in range(3)]
            for dx, dy, w in ((1, 0, 7), (-1, 1, 3), (0, 1, 5), (1, 1, 1)):
                X, Y = x + dx, y + dy
                if 0 <= X < W and Y < H:
                    for t in range(3): src[Y][X][t] += e[t] * w / 16
    font = open(os.path.join(ROOT, 'orig/cpc/os.rom'), 'rb').read()[0x3800:]
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from cyr8 import CYR, LAT
    def glyph(ch, r):                       # русская буква — cyr8.py (или латинская того же вида), иначе — шрифт CPC
        if ch in CYR: return int(CYR[ch][r].replace('#', '1').replace('.', '0'), 2)
        return font[ord(LAT.get(ch, ch)) * 8 + r]
    for row, txt in (((140, 'ВЕРСИЯ ДЛЯ'), (156, 'ВЕКТОРА-06Ц')) if RU else ((140, 'VECTOR-06C'), (156, 'VERSION'))):
        tx = 8 + (88 - 8 * len(txt)) // 2
        for i, ch in enumerate(txt):
            for r in range(8):
                g = glyph(ch, r)
                for bb in range(8):
                    if (g >> (7 - bb)) & 1: pix[row + r][tx + 8 * i + bb] = 2   # жёлтый
    pal = [(B_ << 6) | (G << 3) | R for R, G, B_ in cols]; combos = {i: i for i in range(16)}
planes = bytearray(0x8000)
for y in range(len(pix)):
    for x in range(256):
        i = pix[y][x]
        for p, bit in enumerate((8, 4, 2, 1)):
            if i & bit: planes[p * 0x2000 + (x >> 3) * 256 + 255 - (Y0 + y)] |= 0x80 >> (x & 7)
open(os.path.join(B, 'screen.bin'), 'wb').write(planes)
open(os.path.join(B, 'palette.bin'), 'wb').write(bytes(pal))
im = Image.new('RGB', (256, 256))
for y in range(len(pix)):
    for x in range(256): im.putpixel((x, Y0 + y), rgb(pal[pix[y][x]]))
im.save(os.path.join(ROOT, 'build/vec/splash_preview_ru.png' if RU else 'build/vec/splash_preview.png'))

game = open(os.path.join(ROOT, 'build/vec/brucelee_ru.bin' if RU else 'build/vec/brucelee.bin'), 'rb').read()
assert len(game) == 0xA000
open(os.path.join(B, 'game.raw'), 'wb').write(game)
subprocess.run([os.path.join(ROOT, 'tools/zx0/zx0'), '-f', '-c', os.path.join(B, 'game.raw'), os.path.join(B, 'game.zx0')],
               check=True, capture_output=True)
n = os.path.getsize(os.path.join(B, 'game.zx0'))
r = subprocess.run([os.path.join(ROOT, 'tools/sjasmplus'), '--nologo', '--i8080', '--sym=' + os.path.join(B, 'splash.sym'),
                    '-I' + B, os.path.join(ROOT, 'src/vec/splash.asm')], cwd=B, capture_output=True, text=True)
if r.returncode: print(r.stdout, r.stderr); raise SystemExit(1)
rom = open(os.path.join(B, 'splash.rom'), 'rb').read()
assert len(rom) == 0x10000
os.makedirs(os.path.join(ROOT, 'rom'), exist_ok=True)
# без заставки, с 0x0100 (08.11): .rom для эмуляторов и для CP/M (переименовать в .COM) — src/vec/boot0100.asm
r = subprocess.run([os.path.join(ROOT, 'tools/sjasmplus'), '--nologo', '--i8080', '-I' + B, os.path.join(ROOT, 'src/vec/boot0100.asm')],
                   cwd=B, capture_output=True, text=True)
if r.returncode: print(r.stdout, r.stderr); raise SystemExit(1)
COM = 'rom/BruceLee-v06c-ru.rom' if RU else 'rom/BruceLee-v06c.rom'
open(os.path.join(ROOT, COM), 'wb').write(open(os.path.join(B, 'boot0100.bin'), 'rb').read())
NAME = 'rom/BruceLee-v06c-ru.' if RU else 'rom/BruceLee-v06c.'
for ext in ('r0m', 'c00'): open(os.path.join(ROOT, NAME + ext), 'wb').write(rom)
print(f'цветов заставки {len(combos)}, игра {len(game)} -> {n} Б (ZX0), {NAME}r0m/.c00; без заставки {COM} ({os.path.getsize(os.path.join(ROOT, COM))} Б)')
