"""Карта экранов Bruce Lee для Вектора (владелец 07.11, по образцу ataricompendium.com/archives/maps/a48/brucelee.html):
все 20 комнат одной картинкой, разложены по переходам ZX (таблица выходов 6012 описателя комнаты), между соседними —
перемычки на высоте/столбце входа. Снимки — tools/vecmap.js (build/map/full_NN.png, поле — строки 32..207).
   node tools/vecmap.js && python3 -I tools/mkmap.py  -> docs/brucelee_map.png"""
import os
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.join(os.path.dirname(__file__), '..')
img = open(os.path.join(ROOT, 'build/zx_tap.bin'), 'rb').read()
w16 = lambda a: img[a] | img[a + 1] << 8
EX = {}
for n in range(20):
    h = w16(0x6400 + 2 * n); hd = img[h:h + 0x40]
    EX[n] = [(e,) + tuple(hd[0x12 + 3 * e:0x15 + 3 * e]) for e in range(9) if hd[0x12 + 3 * e] != 0xFF]
# раскладка (столбец, ряд): улица 0-1-2-9 и замок 10-11; двери 1, 2, 3 комнаты 11 — вниз в 12, 13, 14; 14 -> 15 вниз,
# 15-16-17, 17 -> 18 вверх, 18-19; подземелья 3..8 — под 1 и 2 (по автораскладке из выходов)
POS = {0: (0, 0), 1: (1, 0), 2: (2, 0), 9: (3, 0), 10: (4, 0), 11: (5, 0),
       3: (0, 1), 4: (1, 1), 5: (2, 1), 12: (4, 1), 13: (5, 1), 14: (6, 1), 18: (8, 1), 19: (9, 1),
       6: (0, 2), 7: (1, 2), 8: (2, 2), 15: (6, 2), 16: (7, 2), 17: (8, 2)}
FW, FH, GAP, M, TOP = 256, 176, 24, 24, 72
cols = max(c for c, r in POS.values()) + 1; rows = max(r for c, r in POS.values()) + 1
W, H = M * 2 + cols * FW + (cols - 1) * GAP, TOP + M + rows * FH + (rows - 1) * GAP
out = Image.new('RGB', (W, H), (0, 0, 0)); dr = ImageDraw.Draw(out)
xy = lambda n: (M + POS[n][0] * (FW + GAP), TOP + POS[n][1] * (FH + GAP))
for n in range(20):
    out.paste(Image.open(os.path.join(ROOT, f'build/map/full_{n:02d}.png')).convert('RGB').crop((0, 32, 256, 32 + FH)), xy(n))
WH = (255, 255, 255)
for a in range(20):
    for e, b, x, y in EX[a]:
        if b not in POS or (a, b) == (14, 0): continue
        (ca, ra), (cb, rb) = POS[a], POS[b]; ax, ay = xy(a); bx, by = xy(b)
        if rb == ra and cb == ca + 1:      # вправо: перемычка на высоте входа в B
            yy = by + y * 8 + 4; dr.line([(ax + FW, yy), (bx - 1, yy)], fill=WH, width=3)
        elif rb == ra + 1 and cb == ca:    # вниз: на столбце входа
            xx = bx + x * 8 + 4; dr.line([(xx, ay + FH), (xx, by - 1)], fill=WH, width=3)
        elif rb == ra - 1 and cb == ca:    # вверх
            xx = bx + x * 8 + 4; dr.line([(xx, by + FH), (xx, ay - 1)], fill=WH, width=3)
FONT = '/System/Library/Fonts/Supplemental/Arial.ttf'
F1, F2 = ImageFont.truetype(FONT, 15), ImageFont.truetype(FONT, 18)
for n in range(20):                    # номера комнат
    x0, y0 = xy(n); dr.rectangle([x0, y0, x0 + 24, y0 + 18], fill=(0, 0, 0)); dr.text((x0 + 4, y0 + 1), str(n), fill=(255, 255, 0), font=F1)
logo = Image.open(os.path.join(ROOT, 'build/map/full_00.png')).convert('RGB').crop((40, 224, 216, 252))
out.paste(logo, (M, 20))
dr.text((M + 200, 24), 'Вектор-06Ц — карта экранов: 20 комнат (логика ZX, графика CPC). Номера — комнаты игры, линии — переходы;'
        ' двери 1, 2, 3 комнаты 11 ведут в 12, 13, 14.', fill=(210, 210, 210), font=F2)
out.save(os.path.join(ROOT, 'docs/brucelee_map.png'))
print('docs/brucelee_map.png', out.size)
