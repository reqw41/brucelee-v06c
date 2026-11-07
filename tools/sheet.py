#!/usr/bin/env python3
"""Лист снимков: tools/sheet.py <каталог> <выход.png> [столбцов] — все *.ppm/*.png каталога по порядку, с подписью."""
import sys, glob, os
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]; cols = int(sys.argv[3]) if len(sys.argv) > 3 else 5
fs = sorted(glob.glob(os.path.join(d, '*.ppm')) + glob.glob(os.path.join(d, '*.png')))
ims = [Image.open(f).convert('RGB') for f in fs]
w, h = ims[0].size; rows = (len(ims) + cols - 1) // cols
sh = Image.new('RGB', (w * cols, (h + 12) * rows), (40, 40, 40)); dr = ImageDraw.Draw(sh)
for i, (f, im) in enumerate(zip(fs, ims)):
    x, y = (i % cols) * w, (i // cols) * (h + 12); sh.paste(im, (x, y + 12)); dr.text((x + 2, y), os.path.basename(f), fill=(255, 255, 0))
sh.save(out)
