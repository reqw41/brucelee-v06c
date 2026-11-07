#!/usr/bin/env python3
# Лист раскраски Брюса (tools/bruce_zones.py) для согласования: все кадры, сторона 0 (вправо) сверху, 1 — снизу;
# точки — цвета ZX палитры игры, дырки маски — чёрные, фон — тёмно-серый.  python3 -I tools/bruce_sheet.py [out.png]
import os, sys
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
import bruce_zones as BZ
ROOT = os.path.join(os.path.dirname(__file__), '..')
img = open(os.path.join(ROOT, 'build/zx_tap.bin'), 'rb').read()
w16 = lambda a: img[a] | img[a + 1] << 8
descs = sorted({w16(0xCCA5 + 0x16 + 4 * i) for i in range(22)})
RGB = {0: (0, 0, 0), 2: (215, 0, 0), 6: (215, 215, 0), 7: (215, 215, 215)}
S, PAD = 6, 6
W = sum(img[d] * 8 * S + PAD * S for d in descs); H = 2 * (24 * S + 14) + 4
im = Image.new('RGB', (W, H), (48, 48, 56)); dr = ImageDraw.Draw(im); x0 = 0
for n, d in enumerate(descs):
    wd, ht = img[d], img[d + 1]
    for side in (0, 1):
        y0 = side * (24 * S + 14) + 12
        for j in range(wd):
            for r in range(ht):
                f = img[d + 2 + r * wd + j]; a = 0xA000 + side * 0x800 + f * 8
                for k in range(8):
                    m, px = img[a + 0x1000 + k], img[a + k]
                    for b in range(8):
                        x, y = j * 8 + b, r * 8 + k
                        if (px >> (7 - b)) & 1:
                            xs = wd * 8 - 1 - x if side and n not in BZ.NO_MIRROR else x
                            c = RGB[BZ.colour(n, xs, y, wd * 8)]
                        elif not (m >> (7 - b)) & 1: c = (0, 0, 0)
                        else: continue
                        dr.rectangle([x0 + x * S, y0 + y * S, x0 + x * S + S - 1, y0 + y * S + S - 1], fill=c)
        dr.text((x0, side * (24 * S + 14)), str(n), fill=(160, 200, 255))
    x0 += wd * 8 * S + PAD * S
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'build/bruce/colors.png')
os.makedirs(os.path.dirname(out), exist_ok=True); im.save(out); print(out, im.size)
