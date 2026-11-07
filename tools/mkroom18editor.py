"""Редактор рисунка колдуна комнаты 18 (владелец 07.11: «дай редактор, я подрисую») — tools/room18_editor.html.
Вшивает нынешний рисунок области колдуна (build/room18_src.png — то, что собирает mkroom18tiles.py: столбцы карты 9..22,
ряды 0..10) и для сравнения превью (docs/tasks/room18_art/current_preview.png). Текст из редактора кладётся в
docs/tasks/room18_art/edit.txt — mkroom18tiles.py берёт область оттуда.
   python3 -I tools/mkroom18editor.py   (после ./build.sh — нужен build/room18_src.png)"""
import os, json
from PIL import Image
ROOT = os.path.join(os.path.dirname(__file__), '..')
CH = {(0, 0, 0): '.', (255, 0, 170): 'm', (255, 0, 0): 'r', (0, 0, 255): 'b', (0, 255, 0): 'g', (255, 255, 0): 'y'}
def rows(path, h):
    p = Image.open(path).convert('RGB').load()
    return [''.join(CH.get(p[x, y], '.') for x in range(256)) for y in range(h)]
src = rows(os.path.join(ROOT, 'build/room18_src.png'), 104)
prev = rows(os.path.join(ROOT, 'docs/tasks/room18_art/current_preview.png'), 104)
html = open(os.path.join(ROOT, 'tools/room18_editor.tpl.html'), encoding='utf-8').read()
html = html.replace('/*DATA*/', 'const SRC = %s;\nconst PREV = %s;' % (json.dumps(src), json.dumps(prev)))
open(os.path.join(ROOT, 'tools/room18_editor.html'), 'w', encoding='utf-8').write(html)
print('tools/room18_editor.html')
