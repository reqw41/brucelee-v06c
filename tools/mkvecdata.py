#!/usr/bin/env python3
"""Данные Bruce Lee для i8080 (docs/VEC_LAYOUT.md) из эталонного образа build/zx_tap.bin.

  python3 -I tools/mkvecdata.py   -> src/i8080/gen/zxdata.asm, src/i8080/gen/zxequ.asm

- Данные ZX 5B00..9FFF остаются по своим адресам (INCBIN в main.asm), указатели внутри них не правятся.
- Острова из C000..DFFF и переменные/тексты FB00..FEFF переносятся: метки Z_xxxx; для каждого адреса
  острова — EQU zc_xxxx (zv_xxxx для FB00..FEFF), чтобы код i8080 писал адреса ZX.
- Указатели в островах заменяются метками: обработчики состояний и комнат -> h_xxxx / r_xxxx (код i8080),
  описатели спрайтов -> zc_xxxx.
- Спрайты A000..BFFF (точки и маски) -> gen/spr.bin (8 КБ, Z_SPR, выровнен на 256): фрагмент f стороны d
  (0 вправо, 1 влево) — 16 байт с Z_SPR + d*0x1000 + f*16: пары (маска, точки) по строкам 0..7;
  gen/sprempty.bin — 64 байта, бит (d*256+f) = фрагмент пуст (маска FF, точек нет).
- Шрифт CPC, символы 32..95 -> gen/font.bin (512 байт; '#' — «П», '@' — ©).
"""
import os
ROOT = os.path.join(os.path.dirname(__file__), '..')
img = bytearray(open(os.path.join(ROOT, 'build/zx_tap.bin'), 'rb').read())
w16 = lambda a: img[a] | img[a + 1] << 8

# колдун комнаты 18 (tools/mkroom18tiles.py -> build/room18_tiles.json, 06.11): запекаемые узоры и цвета — прямо в
# образ (отсюда и пустые тайлы 5B00), карта комнаты 18 — в её поток ниже; заёмные номера — запас r18 (tilefix.asm):
# узоры, цвета, номера, флаг 0 — вместе с логотипом (5B50, 432) одним ZX0 на месте логотипа -> gen/logo18.zx0
import json, subprocess
R18 = json.load(open(os.path.join(ROOT, 'build/room18_tiles.json')))
r18 = ['; Создано tools/mkvecdata.py: колдун комнаты 18 (build/room18_tiles.json) — запечённые узоры и цвета']
for t, b in sorted((int(k), v) for k, v in R18['bake'].items()):
    img[0x9800 + t * 8:0x9800 + t * 8 + 8] = bytes(b['pat']); img[0x6300 + t] = b['attr']
    r18 += ['\t\t\tORG\t0x%04X' % (0x9800 + t * 8), '\t\tDB\t' + ','.join('0x%02X' % x for x in b['pat']),
            '\t\t\tORG\t0x%04X' % (0x6300 + t), '\t\tDB\t0x%02X' % b['attr']]
# значки инь-янь (тайлы 71..74, комнаты 10, 12..15, 19; владелец 07.11): жёлтые на фоне комнаты — чернила 6, бумага 0
for t in range(0x71, 0x75):
    img[0x6300 + t] = (img[0x6300 + t] & 0xC0) | 6
    r18 += ['\t\t\tORG\t0x%04X' % (0x6300 + t), '\t\tDB\t0x%02X' % img[0x6300 + t]]
bw = R18['borrow']
r18 += ['R18_N\tequ\t%d\t; заёмных номеров' % len(bw), 'WIZ_BLANK\tequ\t0x%02X\t; пустой твёрдый тайл (исчезновение колдуна)' % R18['blank']]
wm = ['; Создано tools/mkvecdata.py: клетки колдуна (ряды 0..10, столбцы 9..22 карты комнаты 18), по 2 байта на ряд, бит — столбец',
      'wiz_mask:'] + ['\t\tDB\t0x%02X,0x%02X' % (sum(b << i for i, b in enumerate(row[:8])), sum(b << i for i, b in enumerate(row[8:]))) for row in R18['wizmask']]
open(os.path.join(ROOT, 'src/i8080/gen/wizmask.asm'), 'w').write('\n'.join(wm) + '\n')
open(os.path.join(ROOT, 'src/i8080/gen/room18.asm'), 'w').write('\n'.join(r18) + '\n')
blob = bytes(img[0x5B50:0x5D00]) + b''.join(bytes(b['pat']) for b in bw) + bytes(b['attr'] for b in bw) + bytes(b['t'] for b in bw) + b'\0'
open(os.path.join(ROOT, 'build/logo18.bin'), 'wb').write(blob)
subprocess.run([os.path.join(ROOT, 'tools/zx0/zx0'), '-f', '-c', os.path.join(ROOT, 'build/logo18.bin'), os.path.join(ROOT, 'src/i8080/gen/logo18.zx0')], check=True, capture_output=True)
print('логотип + запас колдуна: %d -> %d Б (место 432)' % (len(blob), os.path.getsize(os.path.join(ROOT, 'src/i8080/gen/logo18.zx0'))))

# острова (начало, конец не включая)
ISLANDS = [(0xC0E5, 0xC121), (0xC96B, 0xC99B), (0xCB1C, 0xCD9B), (0xD018, 0xD023), (0xD7AC, 0xD824), (0xDA51, 0xDA63),
           (0xDAF9, 0xDAFF), (0xDBA4, 0xDBB0), (0xDCBE, 0xDCEE), (0xDD07, 0xDD0D)]
STRUCTS = [0xCB1C, 0xCBBE, 0xCCA5]
ptr = {}                         # адрес слова -> метка
for s in STRUCTS:
    for k in (0x12, 0x14):
        ptr[s + k] = 'zc_%04X' % w16(s + k)
    for i in range(22):
        e = s + 0x16 + 4 * i
        ptr[e] = 'zc_%04X' % w16(e)
        ptr[e + 2] = 'h_%04X' % w16(e + 2)
for a in range(0xD7AC, 0xD824, 2):
    ptr[a] = 'r_%04X' % w16(a)

out = ['; Создано tools/mkvecdata.py из build/zx_tap.bin — не править руками.', '']
handlers = set()
for lo, hi in ISLANDS:
    out.append('Z_%04X:' % lo)
    a = lo
    while a < hi:
        if a in ptr:
            out.append('\t\tDW\t%s\t\t; %04X' % (ptr[a], a)); handlers.add(ptr[a]); a += 2; continue
        n = 0
        while a + n < hi and a + n not in ptr and n < 16: n += 1
        out.append('\t\tDB\t' + ','.join('0x%02X' % b for b in img[a:a + n]) + '\t; %04X' % a)
        a += n
    out.append('')
open(os.path.join(ROOT, 'src/i8080/gen/zxdata.asm'), 'w').write('\n'.join(out) + '\n')

# переменные и тексты FB00..FEFF: начальные значения
# FD00..FDFF — таблица IM 2 ZX (на Векторе не нужна): не переносится, FE00.. идут сразу за FCFF
VAR_PAGES = [a for a in range(0xFB00, 0xFF00, 16) if not 0xFD00 <= a < 0xFE00]
vaddr = lambda a: a - 0xFB00 - (0x100 if a >= 0xFE00 else 0)
vars_ = ['; Создано tools/mkvecdata.py — переменные и тексты ZX FB00..FCFF, FE00..FEFF (FD — таблица IM 2 — нет).', 'Z_FB00:']
for a in VAR_PAGES:
    vars_.append('\t\tDB\t' + ','.join('0x%02X' % b for b in img[a:a + 16]) + '\t; %04X' % a)
open(os.path.join(ROOT, 'src/i8080/gen/zxvars.asm'), 'w').write('\n'.join(vars_) + '\n')

equ = ['; Создано tools/mkvecdata.py: адреса ZX -> адреса Вектора.']
for lo, hi in ISLANDS:
    for a in range(lo, hi): equ.append('zc_%04X\tequ\tZ_%04X + 0x%X' % (a, lo, a - lo))
for a in range(0xFB00, 0xFF00):
    if not 0xFD00 <= a < 0xFE00: equ.append('zv_%04X\tequ\tZ_FB00 + 0x%X' % (a, vaddr(a)))
open(os.path.join(ROOT, 'src/i8080/gen/zxequ.asm'), 'w').write('\n'.join(equ) + '\n')
# адреса описателей спрайтов, на которые ссылаются структуры, — тоже zc_ (они внутри острова CB1C)
miss = sorted(h for h in handlers if h.startswith('zc_') and not any(lo <= int(h[3:], 16) < hi for lo, hi in ISLANDS))
print('островов %d, указателей %d, обработчиков %d%s' % (len(ISLANDS), len(ptr), len({h for h in handlers if h[0] in 'hr'}),
      ', вне островов: ' + ' '.join(miss) if miss else ''))
print('нужны метки:', ' '.join(sorted({h for h in handlers if h[0] in 'hr'})))

# спрайты: пары (маска, точки) по 16 байт на фрагмент
spr = bytearray(0x2000); emp = bytearray(64)
for d in (0, 1):
    for f in range(256):
        a = 0xA000 + d * 0x800 + f * 8
        for k in range(8):
            spr[d * 0x1000 + f * 16 + 2 * k] = img[a + 0x1000 + k]
            spr[d * 0x1000 + f * 16 + 2 * k + 1] = img[a + k]
        if all(x == 0 for x in img[a:a + 8]) and all(x == 0xFF for x in img[a + 0x1000:a + 0x1008]):
            n = d * 256 + f; emp[n >> 3] |= 1 << (n & 7)
open(os.path.join(ROOT, 'src/i8080/gen/spr.bin'), 'wb').write(spr)
open(os.path.join(ROOT, 'src/i8080/gen/sprempty.bin'), 'wb').write(emp)
# шрифт символов 32..127 — шрифт прошивки CPC (решение владельца 05.11: как на стартовом экране CPC;
# orig/cpc/os.rom — ПЗУ ОС CPC 6128, шрифт с 0x3800, не в git); раньше — ПЗУ ZX 3D00
rom = open(os.path.join(ROOT, 'orig/cpc/os.rom'), 'rb').read()
# (07.11, владелец: «оставь только нужный шрифт») — символы 32..95: тексты игры (титул, шапка, пауза, надписи) — только
# они (46 разных, проверено прогоном и по строкам); строчные и {|}~ DEL убраны (256 байт: 9540..963F свободны).
# Свои значки — на месте неиспользуемых: '#' — «П» (джойстик «П» на титуле), '@' — © (у ZX 7F; глиф © CPC 164)
font = bytearray(rom[0x3800 + 32 * 8:0x3800 + 96 * 8])
H, T = rom[0x3800 + ord('H') * 8:0x3800 + ord('H') * 8 + 8], rom[0x3800 + ord('T') * 8:0x3800 + ord('T') * 8 + 8]
side = H[1]                              # «П» — из «H» CPC: верх как у «T», без перекладины
font[(ord('#') - 32) * 8:(ord('#') - 31) * 8] = bytes([T[0]] + [side if r < 7 else H[7] for r in range(1, 8)])
font[(ord('@') - 32) * 8:(ord('@') - 31) * 8] = rom[0x3800 + 164 * 8:0x3800 + 165 * 8]
assert len(font) == 512
open(os.path.join(ROOT, 'src/i8080/gen/font.bin'), 'wb').write(bytes(font))

# операции вывода по атрибуту (src/vec/render.asm): для плоскости p (0 синяя E000, 1 красная C000, 2 зелёная A000)
# op = I + 2*PP (I — бит чернил, PP — бит бумаги); байт = op0 | op1<<2 | op2<<4
ot = ['; Создано tools/mkvecdata.py: операции вывода по атрибуту (биты 0..5).', 'optab:']
vals = []
for a in range(64):
    v = 0
    for p in range(3): v |= (((a >> p) & 1) | (((a >> (p + 3)) & 1) << 1)) << (2 * p)
    vals.append(v)
for i in range(0, 64, 16): ot.append('\t\tDB\t' + ','.join('0x%02X' % x for x in vals[i:i + 16]))
bl = lambda v: sum(((0 if (v >> 2 * p) & 3 == 1 else 3 if (v >> 2 * p) & 3 == 2 else (v >> 2 * p) & 3) << 2 * p) for p in range(3))
ot.append('optab_blank:\t; то же для пустого тайла: точки -> 0, ~точки -> FF')
for i in range(0, 64, 16): ot.append('\t\tDB\t' + ','.join('0x%02X' % bl(x) for x in vals[i:i + 16]))
open(os.path.join(ROOT, 'src/i8080/gen/optab.asm'), 'w').write('\n'.join(ot) + '\n')

# пустые тайлы (все точки 0) набора 9800 — бит n (256 бит, 32 байта) -> gen/tileblank.bin (Вектор: 5B00)
tb = bytearray(32)
for n in range(256):
    if not any(img[0x9800 + n * 8:0x9800 + n * 8 + 8]): tb[n >> 3] |= 1 << (n & 7)
open(os.path.join(ROOT, 'src/i8080/gen/tileblank.bin'), 'wb').write(tb)
print('пустых тайлов', sum(bin(x).count('1') for x in tb))


# комнаты: поток тайлов (RLE после заголовка 0x40) -> ZX0 (classic) на том же месте; room_load распаковывает его
# в карту 6040 (704 байта). Остаток потока свободен: дыры ROOMHOLE_n (адрес, длина) -> gen/roomz.asm
import subprocess
GEN = os.path.join(ROOT, 'src/i8080/gen'); os.makedirs(os.path.join(GEN, 'roomz'), exist_ok=True)
rz = ['; Создано tools/mkvecdata.py: потоки комнат в ZX0 на месте RLE (после INCBIN данных ZX).']
holes = []
for n in range(20):
    ra = w16(0x6400 + 2 * n); h = ra + 0x40; m = bytearray()
    while img[h]:
        a = img[h]
        if a & 0x80: c = a & 0x7F; m += img[h + 1:h + 1 + c]; h += 1 + c
        else: m += bytes([img[h + 1]]) * a; h += 2
    assert len(m) == 704
    if n == 18: m = bytearray(R18['map'])
    raw = os.path.join(GEN, 'roomz/r%02d.raw' % n); zf = os.path.join(GEN, 'roomz/r%02d.zx0' % n)
    open(raw, 'wb').write(m)
    subprocess.run([os.path.join(ROOT, 'tools/zx0/zx0'), '-f', '-c', raw, zf], check=True, capture_output=True)
    z = os.path.getsize(zf); s0, e0 = ra + 0x40, h + 1
    rz += ['\t\t\tORG\t0x%04X' % s0, '\t\t\tINCBIN\t"roomz/r%02d.zx0"\t; комната %d: RLE %d -> %d' % (n, n, e0 - s0, z)]
    holes.append((s0 + z, e0 - s0 - z))
for i, (a, l) in enumerate(holes): rz.append('ROOMHOLE_%d\tequ\t0x%04X\t; %d байт\nROOMHOLE_%d_END\tequ\t0x%04X' % (i, a, l, i, a + l))
open(os.path.join(GEN, 'roomz.asm'), 'w').write('\n'.join(rz) + '\n')
open(os.path.join(ROOT, 'build/roomz_spans.json'), 'w').write(repr([[w16(0x6400 + 2 * n) + 0x40, a + l] for n, (a, l) in enumerate(holes)]).replace('(', '[').replace(')', ']'))
print('комнаты ZX0: дыр %d, свободно %d' % (len(holes), sum(l for _, l in holes)))

# спрайты (решение владельца 05.11.2026): рисунок — кадры CPC (tools/cpcspr.py, общий Atari-рисунок MSX/CPC), цвета
# CPC: Брюс — жёлтый (6) + чёрный (1), Ямо — зелёный (4) + чёрный, Ниндзя — чёрный; ритм анимации и столкновения — ZX.
# Видимый блок кадра (описатель, сторона): заголовок (vx, vw, vy, vh) — рамка содержимого внутри рамки описателя
# (столбцы, строки), затем столбцы по vh строк, в строке 2 байта: Y (точки своего цвета), K (чёрные). Одинаковые
# блоки — один раз. Блок столкновений (pix_collide): точки ZX, байт на строку, столбцами по 8h строк; сторона 1 —
# только у кадров, где она не зеркало стороны 0 (иначе pix_collide зеркалит сам). Блоки лежат внизу (Z_SPRC,
# gen/sprcol.bin, до SPR_LOW байт) и в дырах потоков комнат (gen/sprhole.asm).
# gen/sprtab.asm: spr_lo (младшие байты описателей), spr_k (0 Ниндзя, 1 Ямо, 2 Брюс), spr_ptr (видимые: стороны 0, 1),
# spr_col (столкновения: сторона 0, сторона 1 или 0 — зеркало). build/sprmap.json — точки ZX на Векторе (run80).
import sys, json
sys.path.insert(0, os.path.dirname(__file__))
import cpcspr
SPR_LOW = 4300
# код вывода в дырах (main.asm, hcodeN): бюджет байт на дыру (занято + запас 16); ASSERT в main.asm — по CODEEND_n,
# хвост дыры за бюджетом — спрайтам. Вырос код и сработал ASSERT — поднять бюджет здесь.
CODE_BUDGET = {3: 227, 4: 100, 7: 207, 9: 262, 10: 399, 11: 234, 12: 437, 13: 235, 14: 295, 19: 350,
               8: 38, 15: 32, 2: 12, 18: 13}   # 2, 8, 15 — звуки CPC (tools/mkcpcsnd.py HOLE); 8 — и ai_cpc3 (10)
CODE_HOLES = set(CODE_BUDGET)
own = {}
for k, st in enumerate(STRUCTS):
    for i in range(22): own.setdefault(w16(st + 0x16 + 4 * i), set()).add(k)
descs = sorted(own)
assert len({d & 255 for d in descs}) == len(descs) and all(len(v) == 1 for v in own.values())
kind = {d: next(iter(own[d])) for d in descs}
rev8 = lambda b: int('{:08b}'.format(b)[::-1], 2)
FRAMEOF = {}                             # ключ блока -> кадр CPC (build/sprframes.json, для сверки анимации)
def vblock(d, side, f, snap=True):
    """видимый блок: заголовок (vx, vw, vy, vh; vx, vy со знаком — кадр может выходить за рамку ZX), столбцы по 2 байта"""
    pix = cpcspr.place(img, d, side, f, snap)
    cx = [X >> 3 for X, _ in pix]; ry = [Y for _, Y in pix]
    vx, vw, vy, vh = min(cx), max(cx) - min(cx) + 1, min(ry), max(ry) - min(ry) + 1
    b = bytearray((vx & 255, vw, vy & 255, vh))
    for j in range(vx, vx + vw):
        for y in range(vy, vy + vh):
            b.append(sum(0x80 >> q for q in range(8) if pix.get((8 * j + q, y))))          # S — все точки
            b.append(sum(0x80 >> q for q in range(8) if pix.get((8 * j + q, y)) == 'K'))   # K — чёрные (Y = S xor K)
    key = ('v', bytes(b), img[d]); blocks.setdefault(key, (bytes(b), [])); FRAMEOF[key] = f
    if f in cpcspr.FACE and side == 0:   # лицо в финале: тот же блок с лицом -> куски XOR (рамка та же)
        fp = cpcspr.place(img, d, side, f, snap, True)
        b2 = bytearray(b[:4])
        for j in range(vx, vx + vw):
            for y in range(vy, vy + vh):
                b2.append(sum(0x80 >> q for q in range(8) if fp.get((8 * j + q, y))))
                b2.append(sum(0x80 >> q for q in range(8) if fp.get((8 * j + q, y)) == 'K'))
        assert not [q for q in fp if (q[0] >> 3) < vx or (q[0] >> 3) >= vx + vw or q[1] < vy or q[1] >= vy + vh], 'лицо: за рамкой кадра'
        dif = [k for k in range(len(b)) if b[k] != b2[k]]; runs = []
        for k in dif:                    # куски: подряд, разрыв до 3 байт — внутри куска (XOR 0)
            if runs and k - runs[-1][1] <= 4: runs[-1][1] = k
            else: runs.append([k, k])
        FACEM[key] = [(a, [b[k] ^ b2[k] for k in range(a, e + 1)]) for a, e in runs]
    return key   # ширина — для отражения
FACEM = {}
blocks = {}                              # ключ -> (байты, [(zx, off)])
vis = {}; col = {}; walk = {}
# ходьба (05.11): ZX чередует две позы (d1 на x, d2 на x+1 — шаг на клетку раз в две смены), CPC — три кадра с малым
# шагом. Фаза цикла CPC = x mod 3 (взгляд влево — (-x) mod 3): d1 -> c0, c2, c1; d2 -> c2, c1, c0 при m = 0, 1, 2.
CYC = {2: (1, 33, 2), 1: (21, 22, 34, 35), 0: (15, 16, 36)}                    # Брюс, Ямо, Ниндзя — по памяти
WALKV = {}
# цикл из 4 кадров (Ямо): фаза = чётность x: d1 -> c0 (x чётный), c2; d2 -> c3, c1
for k, c in CYC.items():
    if len(c) == 3: WALKV[k, 1] = (c[0], c[2], c[1]); WALKV[k, 2] = (c[2], c[1], c[0])
    else: WALKV[k, 1] = (c[0], c[2], c[0]); WALKV[k, 2] = (c[3], c[1], c[3])
WMOD = {k: len(c) if len(c) == 3 else 2 for k, c in CYC.items()}
# точная привязка (сдвиг не кратен 8) у кадров в движении: ZX чередует их со сдвигом по клетке, полу-шаг в 4 точки
# держится рисунком (прыжок Брюса — 8/9, удар ногой — 3/4; Ямо: удар ногой 3/4, прыжок 7/8) — иначе фигура скачет по 8
EXACT = {(2, 8), (2, 9)}
for d in descs:
    wd, ht = img[d], img[d + 1]; n = sorted(x for x in descs if kind[x] == kind[d]).index(d)
    # видимые — только сторона 0 (вправо); сторону 1 render.asm отражает в буфер персонажа при смене кадра (mirror_blk)
    if (kind[d], n) not in WALKV: vis[d, 0] = vis[d, 1] = vblock(d, 1 if (kind[d], n) in cpcspr.MIRR else 0, cpcspr.MAP[kind[d]][n], (kind[d], n) not in EXACT)
    else:                                # ходьба: варианты по фазе (у стороны 1 — те же блоки, фаза своя)
        for mm, f in enumerate(WALKV[kind[d], n]): walk[d, 0, mm] = walk[d, 1, mm] = vblock(d, 0, f, False)
        vis[d, 0] = vis[d, 1] = walk[d, 0, 0]
    mirror = all(img[0xA800 + img[d + 2 + r * wd + (wd - 1 - j)] * 8 + k] == rev8(img[0xA000 + img[d + 2 + r * wd + j] * 8 + k])
                 for j in range(wd) for r in range(ht) for k in range(8))
    for side in ((0,) if mirror else (0, 1)):   # столкновения
        b = bytearray(); zm = []
        for j in range(wd):
            for r in range(ht):
                a = 0xA000 + side * 0x800 + img[d + 2 + r * wd + j] * 8
                for k in range(8): zm.append((a + k, len(b))); b.append(img[a + k])
        key = ('c', d, side); blocks[key] = (bytes(b), zm); col[d, side] = key
# входные кадры (05.11, по логам CPC): первые TR_N показов действия — промежуточный кадр CPC (render.asm tr_step)
# группа действия (кадр ZX -> (группа, входной кадр CPC или None)); выход: кадр ZX после группы -> (группа, кадр CPC)
TRANS = {(2, 8): (1, 5), (2, 9): (1, 5), (2, 3): (2, 7), (2, 4): (2, 7), (0, 5): (3, 18), (1, 3): (4, 28), (1, 4): (4, 28),
         (2, 12): (5, None), (2, 13): (5, None), (2, 14): (5, None)}           # лестница / руки вверх
TEXIT = {(2, 0): (5, 4)}                 # из лестницы и прыжка вверх в стойку — присед CPC 4 (как CPC внизу лианы)
# подмена по состоянию логики (у ZX тот же кадр, что у стойки): (вид, состояние, кадр ZX, кадр CPC)
# по таблицам состояний CPC (05.11): падение (ZX s17 ~ CPC s5) — Ниндзя 17, Ямо 25; удар по нему (ZX s19, s20 ~ CPC s20) —
# Ниндзя 17, Ямо 28
SOVR = [(0, 17, 0, 17), (1, 17, 11, 25), (0, 19, 0, 17), (0, 20, 0, 17), (1, 19, 10, 28), (1, 20, 10, 28)]
sov = []
for k, st, n, f in SOVR:
    d = sorted(x for x in descs if kind[x] == k)[n]; sov.append((k, st, vblock(d, 1 if (k, f) == (1, 25) else 0, f)))   # Ямо 25 — лицом влево
trb = {}; trx = {}
for d in descs:
    n = sorted(x for x in descs if kind[x] == kind[d]).index(d)
    if (kind[d], n) in TRANS:
        g, f = TRANS[kind[d], n]; trb[d] = (g, vblock(d, 0, f, (kind[d], n) not in EXACT) if f is not None else None)
    if (kind[d], n) in TEXIT:
        g, f = TEXIT[kind[d], n]; trx[d] = (g, vblock(d, 0, f))
free = [[i, a, l] for i, (a, l) in enumerate(holes) if i not in CODE_HOLES] + \
       [[i, a + CODE_BUDGET[i], l - CODE_BUDGET[i]] for i, (a, l) in enumerate(holes) if i in CODE_HOLES]
assert all(h[2] >= 0 for h in free)
# 92F1..9338 (хвост бывшей картинки GAME OVER и звук ZX, свободно с 06.11) — как дыра 20 (колдун 18 удлинил поток комнаты 18)
XHOLE = (0x92F1, 0x9339 - 0x92F1); holes.append(XHOLE); free.append([len(holes) - 1, XHOLE[0], XHOLE[1]])
low = bytearray(); hole = {}; where = {}
for key, (b, zm) in sorted(blocks.items(), key=lambda t: -len(t[1][0])):
    if len(low) + len(b) <= SPR_LOW:
        where[key] = ('Z_SPRC', len(low)); low += b; continue
    for h in sorted(free, key=lambda h: h[2]):
        if h[2] >= len(b):
            off = h[1] - holes[h[0]][0] + len(hole.get(h[0], b''))
            where[key] = ('ROOMHOLE_%d' % h[0], off)
            hole.setdefault(h[0], bytearray()).extend(b); h[2] -= len(b); break
    else: raise SystemExit('спрайты: нет места для блока %d байт (внизу %d)' % (len(b), len(low)))
open(os.path.join(GEN, 'sprcol.bin'), 'wb').write(bytes(low))
if os.environ.get('HOLES'): print('остаток дыр:', sorted((h[0], h[2]) for h in free if h[2]))
# лицо Брюса в финале (cpcspr.FACE): куски блоков — адрес (DW), длина, XOR; таблица — по блокам в остатки дыр (после
# спрайтов), часть кончается DW 1, DW продолжение; последняя — DW 0
parts = []
for key, runs in FACEM.items():
    base, off = where[key]
    parts.append(['\t\tDW\t%s+%d\n\t\tDB\t%d,%s' % (base, off + o, len(xs), ','.join('0x%02X' % x for x in xs)) for o, xs in runs])
fparts = []
runs_ = [(l, 3 + int(l.split('DB\t')[1].split(',')[0])) for ln in parts for l in ln]   # куски по одному
runs_.sort(key=lambda r: -r[1])
while runs_:                             # в самую свободную дыру — сколько влезет (+4 на хвост части)
    fh = max(free, key=lambda h: h[2]); room = fh[2] - 4; take = []
    for r in list(runs_):
        if r[1] <= room: take.append(r); runs_.remove(r); room -= r[1]
    assert take, 'лицо: нет дыры под кусок'
    sz = sum(r[1] for r in take) + 4
    at = CODE_BUDGET.get(fh[0], 0) + len(hole.get(fh[0], b'')) + (fh[3] if len(fh) > 3 else 0)
    if len(fh) > 3: fh[3] += sz
    else: fh.append(sz)
    fh[2] -= sz; n = len(fparts)
    fparts.append([n, fh[0], at, [r[0] for r in take], sz])
    print('лицо Брюса: часть %d — %d байт, дыра %d' % (n, sz, fh[0]))
for k, (n, hi, at, ln, sz) in enumerate(fparts):
    lab = 'face_tab' if n == 0 else 'face_tab%d' % n
    tail = '\t\tDW\t1, face_tab%d' % (n + 1) if n + 1 < len(fparts) else '\t\tDW\t0'
    fparts[k] = ['\t\t\tORG\tROOMHOLE_%d + %d' % (hi, at), lab + ':\t\t\t; лицо Брюса в финале (cpcspr.FACE): адрес, длина, XOR (face_set, finale.asm)'] + ln + [tail, '\t\t\tASSERT\t$ <= ROOMHOLE_%d_END' % hi]
hs = ['; Создано tools/mkvecdata.py: блоки спрайтов в дырах потоков комнат (после roomz.asm).',
      'ROOMHOLE_%d\tequ\t0x%04X\t; не комната: 92F1..9338\nROOMHOLE_%d_END\tequ\t0x%04X' % (len(holes) - 1, XHOLE[0], len(holes) - 1, XHOLE[0] + XHOLE[1])]
for i, b in sorted(hole.items()):
    hs.append('\t\t\tORG\tROOMHOLE_%d + %d' % (i, CODE_BUDGET.get(i, 0)))
    for q in range(0, len(b), 16): hs.append('\t\t\tDB\t' + ','.join('0x%02X' % x for x in b[q:q + 16]))
    hs.append('\t\t\tASSERT\t$ <= ROOMHOLE_%d_END' % i)
for fp_ in fparts: hs += fp_
hs += ['CODEEND_%d\tequ\tROOMHOLE_%d + %d' % (i, i, n) for i, n in sorted(CODE_BUDGET.items())]
open(os.path.join(GEN, 'sprhole.asm'), 'w').write('\n'.join(hs) + '\n')
W = lambda key: '%s+%d' % where[key]
t = ['; Создано tools/mkvecdata.py: описатели кадров -> блоки (Z_SPRC и дыры комнат).', 'SPR_N\tequ\t%d' % len(descs), 'spr_lo:']
for i in range(0, len(descs), 12): t.append('\t\tDB\t' + ','.join('low zc_%04X' % d for d in descs[i:i + 12]))
t.append('spr_k:')
for i in range(0, len(descs), 12): t.append('\t\tDB\t' + ','.join('%d' % kind[d] for d in descs[i:i + 12]))
t.append('spr_ptr:')
for d in descs: t.append('\t\tDW\t%s, %s' % (W(vis[d, 0]), W(vis[d, 1])))
wd_ = sorted({d for d, _, _ in walk})
t.append('WK_N\tequ\t%d' % len(wd_)); t.append('wk_lo:')
t.append('\t\tDB\t' + ','.join('low zc_%04X' % d for d in wd_) if wd_ else '\t\tDB\t0')
t.append('wk_mod:')
t.append('\t\tDB\t' + ','.join(str(WMOD[kind[d]]) for d in wd_) if wd_ else '\t\tDB\t0')
t.append('wk_ptr:')
for d in wd_: t.append('\t\tDW\t' + ', '.join(W(walk[d, sd, mm]) for sd in (0, 1) for mm in range(3)))
vb = [blocks[k][0] for k in {b for _, _, b in sov} | set(vis.values()) | set(walk.values()) | {v for _, v in trb.values() if v} | {v for _, v in trx.values()}]
t.append('SPR_MAXB\tequ\t%d\t; наибольший видимый блок (буфер отражения)' % max(len(x) for x in vb))
t.append('SPR_MAXL\tequ\t%d\t; наибольший столбец, байт (2vh)' % max(2 * x[3] for x in vb))
t.append('spr_trx:\t; на описатель 8 байт: группа (0 — нет), группа выхода (0 — нет), входной блок, блок выхода, 0')
for d in descs:
    g, eb = (trb[d][0], W(trb[d][1]) if trb[d][1] else '0') if d in trb else (0, '0')
    xg, xb = (trx[d][0], W(trx[d][1])) if d in trx else (0, '0')
    t.append('\t\tDB\t%d, %d\n\t\tDW\t%s, %s, 0' % (g, xg, eb, xb))
t.append('spr_sov:\t; подмена по состоянию: запись (0 Ниндзя, 1 Ямо, 2 Брюс), состояние, блок; FF — конец')
for k, st, b in sov: t.append('\t\tDB\t%d, %d\n\t\tDW\t%s' % (k, st, W(b)))
t.append('\t\tDB\t0xFF')
t.append('spr_col:')
for d in descs: t.append('\t\tDW\t%s, %s' % (W(col[d, 0]), W(col[d, 1]) if (d, 1) in col else '0'))
open(os.path.join(GEN, 'sprtab.asm'), 'w').write('\n'.join(t) + '\n')
mp = []
for key, (b, zm) in blocks.items():
    base, off = where[key]
    for zx, o in zm: mp.append([zx, base, off + o])
open(os.path.join(ROOT, 'build/sprmap.json'), 'w').write(json.dumps(mp))
open(os.path.join(ROOT, 'build/sprframes.json'), 'w').write(json.dumps([[where[k][0], where[k][1], f] for k, f in FRAMEOF.items()]))
print('спрайты: внизу %d байт, в дырах %d (%s); видимых блоков %d, столкновений %d' % (len(low), sum(len(b) for b in hole.values()),
      ','.join(str(i) for i in sorted(hole)), len({vis[k] for k in vis}), len(col)))
