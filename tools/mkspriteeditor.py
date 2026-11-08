"""Редактор кадров персонажей (владелец 08.11: «дай редактор спрайтов») — tools/sprite_editor.html: Брюс, Ниндзя, Ямо.
Кадры CPC, которые показывает игра (cpcspr.MAP, входные/подмены mkvecdata.py TRANS/TEXIT/SOVR), исходные и с правками
владельца (cpcspr.EDIT / FACE). Текст «FRAME <кадр CPC> = [...]» из редактора вносится в cpcspr.EDIT (FACE — face3/face4).
   python3 -I tools/mkspriteeditor.py"""
import os, sys, json, re
sys.path.insert(0, os.path.dirname(__file__))
import cpcspr as c
ROOT = os.path.join(os.path.dirname(__file__), '..')
P = os.path.join(ROOT, 'tools/sprite_editor.html')
html = open(P, encoding='utf-8').read()
a = html.index('const DATA = ') + len('const DATA = '); b = html.index(';\n', a)
old = {d['key']: d for d in json.loads(html[a:b])}            # подписи кадров Брюса — как были
txt = lambda rows: [''.join({'Y': 'o', 'K': '#', None: '.'}[v] for v in r) for r in rows]
NINJA = {14: 'Стойка', 15: 'Удар палкой 1', 16: 'Удар палкой 2', 17: 'Падает / получил удар', 18: 'Перед ударом', 19: 'Лежит'}
YAMO = {20: 'Стойка', 21: 'Ходьба 1', 22: 'Ходьба 2', 25: 'Лестница, падение (в игре — зеркально)', 26: 'Удар', 27: 'Кадр ZX 7',
        28: 'Перед ударом ногой, получил удар', 29: 'Удар ногой', 30: 'Кадр ZX 11–13', 32: 'Удар рукой'}
data = []
for key in [k for k, d in old.items() if not k.startswith('face') and d.get('who', 'bruce') == 'bruce']:
    f = old[key]['cpc']; d = {'key': key, 'who': 'bruce', 'label': 'Брюс: ' + old[key]['label'].replace('Брюс: ', ''), 'cpc': f,
                              'orig': txt(c.cpc_frame(f, raw=True))}
    cur = txt(c.cpc_frame(f))
    if cur != d['orig']: d['cur'] = cur
    data.append(d)
for who, name, frames in (('ninja', 'Ниндзя', NINJA), ('yamo', 'Ямо', YAMO)):
    for f, lab in frames.items():
        d = {'key': str(f), 'who': who, 'label': '%s: %s' % (name, lab), 'cpc': f, 'orig': txt(c.cpc_frame(f, raw=True))}
        cur = txt(c.cpc_frame(f))
        if cur != d['orig']: d['cur'] = cur
        data.append(d)
for f in (3, 4):
    data.append({'key': 'face%d' % f, 'who': 'bruce', 'label': 'Брюс: финал, %s с лицом' % ('прыжок вверх' if f == 3 else 'присед'),
                 'cpc': f, 'orig': txt(c.cpc_frame(f, raw=True)), 'cur': txt(c.cpc_frame(f, face=True))})
html = html[:a] + json.dumps(data, ensure_ascii=False) + html[b:]
if 'function C(k, v)' not in html:                # цвет точки «o» — по персонажу: Брюс жёлтый, Ямо зелёный, Ниндзя чёрный
    html = html.replace("ROOM = '#0000aa', KEY = 'brucelee-sprite-v2';",
                        "WHO = { bruce: '#ffff00', yamo: '#00c800', ninja: '#000000' }, ROOM = '#0000aa', KEY = 'brucelee-sprite-v2';\n"
                        "function C(k, v) { return v === 'o' ? WHO[byKey[k].who] || COL.o : COL[v]; }")
    html = html.replace('ctx.fillStyle = COL[v]', 'ctx.fillStyle = C(sel, v)').replace('cx.fillStyle = COL[v]', 'cx.fillStyle = C(k, v)')
html = re.sub(r'<title>[^<]*</title>', '<title>Спрайты Bruce Lee</title>', html, count=1)
open(P, 'w', encoding='utf-8').write(html)
print('tools/sprite_editor.html: кадров %d (Брюс %d, Ниндзя %d, Ямо %d)' % (len(data), sum(d['who'] == 'bruce' for d in data),
      sum(d['who'] == 'ninja' for d in data), sum(d['who'] == 'yamo' for d in data)))
