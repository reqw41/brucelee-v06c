"""Прослушка звуков CPC как на AY (1 МГц): блоки SOUND из BRUCE.N02 через модель tools/mkcpcsnd.py (громкость по
огибающей, уход тона, шум) -> WAV.   python3 -I tools/cpcay_wav.py DIR [имя ...]"""
import os, sys, struct, wave, random
src = open(os.path.join(os.path.dirname(__file__), 'mkcpcsnd.py')).read().replace('\nmain()\n', '\n')
g = {'__file__': os.path.join(os.path.dirname(__file__), 'mkcpcsnd.py')}; exec(src, g)
VOL = [0, 0.0137, 0.0205, 0.0291, 0.0423, 0.0618, 0.0847, 0.1369, 0.1691, 0.2647, 0.3527, 0.4499, 0.5704, 0.6873, 0.8482, 1.0]
R = 44100


def render(steps):
    """steps: по 1/100 с (период тона или 0, громкость 0..15, период шума или 0) -> сэмплы"""
    out = []; tph = 0.0; nph = 0.0; lfsr = 1; nbit = 1
    for p, v, n in steps:
        for _ in range(R // 100):
            t = 1
            if p:
                tph += 1e6 / 16 / p / R; t = 1 if (tph % 1) < 0.5 else 0
            if n:
                nph += 1e6 / 16 / n / R
                while nph >= 1:
                    nph -= 1; nbit = lfsr & 1; lfsr = (lfsr >> 1) ^ (0x12000 if nbit else 0)
            on = (t if p else 1) & (nbit if n else 1)
            out.append(VOL[v] * (1 if on else -1) * 0.6 if (p or n) else 0)
    return out


def save(path, smp):
    with wave.open(path, 'w') as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(R)
        f.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 30000)) for x in smp))


d = sys.argv[1]; os.makedirs(d, exist_ok=True); names = sys.argv[2:] or [n for n, _ in g['SFX']]
for name, a in g['SFX']:
    if name not in names: continue
    b, w = g['b'], g['w']
    st, ampn, tonen = b(a), b(a + 1), b(a + 2); per, nz, vol, dur = w(a + 3), b(a + 5), b(a + 6), w(a + 7)
    s, hw = g['sound'](per, ampn, tonen, nz, vol, dur)
    save(os.path.join(d, 'cpc_' + name + '.wav'), render(s + [(0, 0, 0)] * 20))
    print(name, 'канал', st & 7, 'период', per, 'шум', nz, 'огибающие', ampn, tonen, 'длина', len(s) / 100, 'с')
