#!/usr/bin/env python3
# Карта спрайтов: для каждого кадра ZX (описатели персонажа по возрастанию адреса) — сам кадр ZX, кадр(ы) CPC, который
# показываем мы (как в рамке ZX; у ходьбы — варианты по фазе), и ситуация, в которой ZX его показывает.
#   python3 -I tools/sprite_map.py [build/cpc/sprite_map.png]
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import cpcspr as C
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.join(os.path.dirname(__file__), '..')
z = open(os.path.join(ROOT, 'build/zx_tap.bin'), 'rb').read(); w16 = lambda a: z[a] | z[a + 1] << 8
F = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 13); FB = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Bold.ttf', 18)
S = 4; BG = (128, 128, 128); COL = {0: None, 1: (0, 220, 0), 2: (255, 230, 0)}
WALK = {2: {1: (1, 2, 33), 2: (2, 33, 1)}, 0: {1: (15, 36, 16), 2: (36, 16, 15)}, 1: {1: (21, 34), 2: (35, 22)}}
DESC = {
 2: ['стоит (после лестницы — 4)', 'ходьба, поза 1', 'ходьба, поза 2', 'удар ногой (вход 7)', 'удар ногой (вход 7)', 'сбит, лежит',
     'сбит, скользит', 'лёг (вниз)', 'прыжок (вход 5)', 'прыжок (вход 5)', 'удар рукой', 'присед (верх лестницы)',
     'спуск, руки вверх', 'подъём', 'подъём, вис', 'по Брюсу попали'],
 0: ['стоит (падение, удар по нему — 17)', 'ходьба, поза 1', 'ходьба, поза 2', 'сбит (стоит, как CPC)', 'сбит (стоит, как CPC)', 'удар палкой (вход 18)'],
 1: ['стоит', 'ходьба, поза 1', 'ходьба, поза 2', 'удар ногой (вход 28)', 'удар ногой (вход 28)', 'сбит, лежит', 'сбит, лежит',
     'прыжок', 'прыжок вперёд', 'удар рукой', 'стоит лицом', 'к лестнице, спуск, падение', 'подъём (спиной)', 'подъём (спиной)']}
NAME = {2: 'Брюс (ZX CCA5, CPC 61E5)', 0: 'Ниндзя (ZX CB1C, CPC 5E13)', 1: 'Ямо (ZX CBBE, CPC 5FFA)'}
def zx_img(d):
    wd, ht = z[d], z[d + 1]; im = Image.new('RGB', (wd * 8 * S, ht * 8 * S), BG); dr = ImageDraw.Draw(im)
    for j in range(wd):
        for r in range(ht):
            a = 0xA000 + z[d + 2 + r * wd + j] * 8
            for k in range(8):
                m, px = z[a + 0x1000 + k], z[a + k]
                for b in range(8):
                    c = (0, 0, 0) if px >> (7 - b) & 1 else ((100, 100, 110) if not m >> (7 - b) & 1 else None)
                    if c: x, y = j * 8 + b, r * 8 + k; dr.rectangle([x * S, y * S, x * S + S - 1, y * S + S - 1], fill=c)
    return im
def our_img(d, k, f, snap, mir=False):
    wd, ht = z[d], z[d + 1]; pix = C.place(z, d, 1 if mir else 0, f, snap)
    xs = [p[0] for p in pix] + [0, wd * 8 - 1]; ys = [p[1] for p in pix] + [0, ht * 8 - 1]
    x0, y0 = min(xs), min(ys); W, H = max(xs) - x0 + 1, max(ys) - y0 + 1
    im = Image.new('RGB', (W * S, H * S), (90, 90, 96)); dr = ImageDraw.Draw(im)
    dr.rectangle([(-x0) * S, (-y0) * S, (wd * 8 - x0) * S - 1, (ht * 8 - y0) * S - 1], fill=BG)   # рамка ZX
    for (x, y), v in pix.items():
        c = (0, 0, 0) if v == 'K' else COL[k]
        dr.rectangle([(x - x0) * S, (y - y0) * S, (x - x0) * S + S - 1, (y - y0) * S + S - 1], fill=c)
    return im
blocks = []
for k, st in ((2, 0xCCA5), (0, 0xCB1C), (1, 0xCBBE)):
    ds = sorted({w16(st + 0x16 + 4 * i) for i in range(22)})
    cells = []
    for n, d in enumerate(ds):
        if n in WALK[k]: ims = [(f, our_img(d, k, f, False)) for f in WALK[k][n]]
        else: f = C.MAP[k][n]; ims = [(str(f) + ("'" if (k, n) in C.MIRR else ''), our_img(d, k, f, True, (k, n) in C.MIRR))]
        cells.append((n, d, zx_img(d), ims))
    blocks.append((k, cells))
PAD = 14; out = []
for k, cells in blocks:
    rowW, colImgs = [], []
    H = max(c[2].height for c in cells) + max(max(i.height for _, i in c[3]) for c in cells) + 80
    tot = sum(max(c[2].width, sum(i.width + 4 for _, i in c[3])) + PAD for c in cells)
    # переносим по 8 кадров в ряд
    rows = [cells[i:i + 8] for i in range(0, len(cells), 8)]
    for ri, rc in enumerate(rows):
        Wr = sum(max(c[2].width, sum(i.width + 4 for _, i in c[3]), 130) + PAD for c in rc) + 20
        im = Image.new('RGB', (Wr, H + (30 if ri == 0 else 0)), (40, 40, 46)); dr = ImageDraw.Draw(im); y0 = 0
        if ri == 0: dr.text((10, 4), NAME[k], fill=(255, 255, 255), font=FB); y0 = 30
        x = 10
        for n, d, zi, ims in rc:
            cw = max(zi.width, sum(i.width + 4 for _, i in ims), 130)
            dr.text((x, y0), 'ZX %d (%04X)' % (n, d), fill=(255, 220, 120), font=F)
            im.paste(zi, (x, y0 + 16))
            yy = y0 + 20 + max(c[2].height for c in cells)
            dr.text((x, yy), 'CPC ' + ' / '.join(str(f) for f, _ in ims), fill=(140, 220, 255), font=F)
            xx = x
            for f, oi in ims: im.paste(oi, (xx, yy + 16)); xx += oi.width + 4
            dr.text((x, H + y0 - 22), DESC[k][n], fill=(230, 230, 230), font=F)
            x += cw + PAD
        out.append(im)
Wd = max(i.width for i in out); Ht = sum(i.height + 6 for i in out)
sheet = Image.new('RGB', (Wd, Ht), (30, 30, 34)); y = 0
for i in out: sheet.paste(i, (0, y)); y += i.height + 6
dst = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'build/cpc/sprite_map.png')
sheet.save(dst); print(dst, sheet.size)
