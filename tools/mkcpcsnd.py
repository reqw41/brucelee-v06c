#!/usr/bin/env python3
"""Музыка и звуки Bruce Lee из CPC-версии (решение владельца 06.11.2026) для ВИ53 Вектора (src/vec/sound.asm).

  python3 -I tools/mkcpcsnd.py [--wav DIR]  -> src/i8080/gen/sound.asm  (--wav: прослушка модели в DIR/*.wav)

CPC (orig/cpc/BRUCE.N02, грузится в 1500): звук через очередь прошивки (SOUND QUEUE BCAA), огибающие
громкости 1..12 (8C24, по 16 байт, ENV) и тона 1..3 (8CE4, ENT).
  музыка: 8C00 -> 8D14, мелодия 8ED2: запись 2 байта: b0 & 3 — канал (3 -> C), (b0 >> 2) & 3F — номер периода
          в таблице 8E72 (DW, период AY 1 МГц); b1 & 0F — огибающая громкости (длина ноты = её длина),
          (b1 >> 1) & 38 — встреча с каналом (8 — A, 16 — B). Конец — канал 0. Играет только на титуле
          (7E3B, после включения и после GAME OVER) и по кругу в меню (8012); в игре музыки нет.
  звуки: 8C09.. — блоки SOUND по 9 байт с 8DF1 (статус, ENV, ENT, период, шум, громкость, длительность).
Вектор: ВИ53 1,5 МГц, делитель = 24 * период AY. Громкости у ВИ53 нет: нота звучит, пока громкость огибающей
не ниже порога (THR). Шум — случайные биты на выход счётчика голоса ВИ53 (режим 0; 06.11, раньше — спикер) в простое ожидания кадра
(sound.asm snd_idle, nz_bit), очень короткая
аппаратная огибающая (шаги) — щелчок спикера. Музыка: CPC A -> счётчик 1, B -> счётчик 2. Время — кадры 50 Гц (прерывание).
Выход: snd_divs (DW делители, номер с 1); mus_v1/mus_v2: DB код, кадров (0 — пауза, FF — конец);
sfx_*: DB голос (1/2), затем по кадру DB код: 0 — тишина, 1..N — тон, 0x80|k — шум уровня k (snd_noise),
0xC0 — щелчок, FF — конец.
"""
import os, sys
ROOT = os.path.join(os.path.dirname(__file__), '..')
N02 = open(os.path.join(ROOT, 'orig/cpc/BRUCE.N02'), 'rb').read()[128:]
b = lambda a: N02[a - 0x1500]
w = lambda a: b(a) | b(a + 1) << 8
s8 = lambda v: v - 256 if v & 128 else v
nb = lambda n: 384 * n                  # (прослушка модели) база делителя для шума N
nd = lambda n: max(1, round((48 * n - 192) / 20))   # задержка петли шума (sound.asm nz_bit -> счётчик ВИ53; замер 06.11: 192 + 20*d тактов)
nc = lambda n: max(1, round(9000 / (192 + 20 * nd(n))))   # бит во вспышке прерывания (~9000 тактов = 3 мс)
THR = 4                                  # громкость (0..15), с которой нота слышна на ВИ53


def env_amp(n, vol0=0):
    """ENV n -> список громкостей по 1/100 с (аппаратная огибающая AY — по её форме)."""
    if n == 0: return None
    a = 0x8C24 + 16 * (n - 1); cnt = b(a) & 0x7F; a += 1; v = vol0; out = []
    for _ in range(cnt):
        c, s, p = b(a), b(a + 1), b(a + 2); a += 3
        if c & 0x80:                     # аппаратная: форма c & 0F, период s | p << 8; время берёт следующая секция
            shape, per = c & 15, s | p << 8
            T = 256 * per / 1e6 * 100   # длина цикла в 1/100 с
            out.append(('hw', shape, T)); continue
        if c == 0:
            v = s & 15; out += [v] * (p or 256)
        else:
            for _ in range(c):
                v = (v + s8(s)) & 15; out += [v] * (p or 256)
    return out


def env_tone(n):
    if n == 0: return None
    a = 0x8CE4 + 16 * (n - 1); hdr = b(a); a += 1; off = 0; out = []
    for _ in range(hdr & 0x7F):
        c, s, p = b(a), b(a + 1), b(a + 2); a += 3
        if c == 0:
            off = s8(s); out += [off] * (p or 256)
        else:
            for _ in range(c):
                off += s8(s); out += [off] * (p or 256)
    return out, bool(hdr & 0x80)


def hw_level(shape, T, t):
    """Громкость аппаратной огибающей AY в момент t (1/100 с от начала)."""
    k = t / T if T else 99
    if shape in (0, 1, 2, 3, 9): return 0 if k >= 1 else round(15 * (1 - k))
    if shape in (4, 5, 6, 7, 15): return 0 if k >= 1 else round(15 * k)
    if shape == 13: return 15 if k >= 1 else round(15 * k)
    if shape == 11: return 15 if k >= 1 else round(15 * (1 - k))
    return round(15 * (k % 1))


def sound(per, ampn, tonen, noise, vol, dur):
    """Блок SOUND -> список по 1/100 с: (период или 0, громкость, шум или 0)."""
    amp = env_amp(ampn)
    hw = None
    if amp and isinstance(amp[0], tuple):
        hw = amp[0]; rest = amp[1:]; amp = None; L = len(rest)
    else:
        L = len(amp) if amp else 0
    if dur == 0: n = L
    elif dur & 0x8000: n = L * (0x10000 - dur)
    else: n = dur
    te = env_tone(tonen)
    out = []
    for t in range(n):
        if hw: v = hw_level(hw[1], hw[2], t)
        elif amp: v = amp[t % len(amp)] if dur & 0x8000 else (amp[t] if t < len(amp) else amp[-1])
        else: v = vol
        p = per
        if te and per and max(abs(x) for x in te[0]) >= per * 0.05:   # уход тона меньше 5 % (гул 35–40 Гц) не берём
            seq, rep = te
            o = seq[t % len(seq)] if rep else (seq[t] if t < len(seq) else (seq[-1] if seq else 0))
            p = per + o if per else 0
        out.append((p, v, noise))
    return out, hw


# ---- музыка: очереди каналов A, B с встречами ----
def music():
    a = 0x8ED2; q = {1: [], 2: [], 4: []}
    while b(a) & 3:
        c = b(a) & 3; c = 4 if c == 3 else c
        per = w(0x8E72 + 2 * ((b(a) >> 2) & 0x3F))
        rv = (b(a + 1) >> 1) & 0x38; env = b(a + 1) & 15
        q[c].append((per, env, rv)); a += 2
    tl = {1: [], 2: []}; pos = {1: 0, 2: 0}; t = {1: 0, 2: 0}
    while pos[1] < len(q[1]) or pos[2] < len(q[2]):
        for c in (1, 2):                 # встреча: канал ждёт, пока другой не дойдёт до своей встречи с ним
            if pos[c] >= len(q[c]): continue
            per, env, rv = q[c][pos[c]]
            o = 2 if c == 1 else 1
            if rv & (8 if o == 1 else 16):
                if pos[o] >= len(q[o]) or not (q[o][pos[o]][2] & (8 if c == 1 else 16)): continue
                T = max(t[1], t[2])
                for k in (1, 2):
                    if t[k] < T: tl[k].append((0, T - t[k], 0)); t[k] = T
                for k in (1, 2):
                    pp, ee, _ = q[k][pos[k]]; s, _ = sound(pp, ee, 0, 0, 0, 0)
                    tl[k].append((pp, len(s), sum(1 for x in s if x[1] >= THR))); t[k] += len(s); pos[k] += 1
                break
            s, _ = sound(per, env, 0, 0, 0, 0)
            tl[c].append((per, len(s), sum(1 for x in s if x[1] >= THR))); t[c] += len(s); pos[c] += 1
            break
        else:
            raise SystemExit('музыка: встреча не сходится')
    return tl, t


SFX = [('sfx_step', 0x8DF1), ('sfx_whoosh', 0x8E0F), ('sfx_kick', 0x8E1E), ('sfx_lamp', 0x8E2D),
       ('sfx_appear', 0x8E3C), ('sfx_win', 0x8E4B), ('sfx_die', 0x8E5A), ('sfx_ninja', 0x8E69)]
USED = {n for n, _ in SFX} - {'sfx_step'}   # шаг — щелчок спикера прямо (sound_h18.asm)
HOLE = {'sfx_win': 15, 'sfx_die': 8, 'sfx_kick': 2}   # в дырах комнат (mkvecdata.py CODE_BUDGET 15: 32, 8: 28, 2: 12)
HI = {'sfx_step', 'sfx_whoosh', 'sfx_lamp', 'sfx_lamp2', 'sfx_appear', 'sfx_ninja'}   # и snd_noise — SND_HI (9640..968F, низ стека)
VOICE = {1: 1, 2: 2, 4: 2}               # канал CPC -> голос Вектора (B и C — оба на счётчик 2)


def main():
    divs = []
    def di(per):
        d = min(0xFFFE, 24 * per)
        if d not in divs: divs.append(d)
        return divs.index(d) + 1
    tl, tt = music()
    mus = {}
    for c in (1, 2):
        ent = []; acc = 0.0; fr = 0
        for per, L, on in tl[c]:                       # 1/100 с -> кадры 50 Гц накоплением (без ухода)
            for code, n in ((di(per) if per and on else 0, on if per else L), (0, L - on if per else 0)):
                if n <= 0: continue
                acc += n / 2; k = round(acc) - fr; fr += k
                if k <= 0: continue
                if ent and ent[-1][0] == code and ent[-1][1] + k <= 255: ent[-1][1] += k
                else:
                    while k > 255: ent.append([code, 255]); k -= 255
                    ent.append([code, k])
        pk = []                                         # нота + кадр паузы -> код | 0x80
        for e in ent:
            if e[0] == 0 and e[1] == 1 and pk and 0 < pk[-1][0] < 0x80: pk[-1][0] |= 0x80
            else: pk.append(list(e))
        mus[c] = pk
    # GAME OVER (владелец 06.11, вариант Б — у CPC мелодии нет): нисходящий проигрыш «соль, фа#, фа, ми» с басом
    # на две октавы ниже, ноты 12, 12, 12, 40 кадров; один раз — по FF повтор с go_end (тишина)
    def near(f):                         # делитель ВИ53 для частоты f: есть в таблице с точностью 1 % — он
        d = round(1.5e6 / f)
        for k, x in enumerate(divs):
            if abs(x - d) <= d / 100: return k + 1
        divs.append(d); return len(divs)
    hz = lambda m: 440 * 2 ** ((m - 69) / 12)
    go = {1: [], 2: []}
    for m1, n in ((67, 12), (66, 12), (65, 12), (64, 40)):
        for c, mm in ((1, m1), (2, m1 - 24)):
            k = near(hz(mm)); go[c].append((k | 0x80, n - 1) if n < 40 else (k, n))
    noise = []
    sfx = []
    for name, a in SFX:
        if name not in USED: continue
        st, ampn, tonen = b(a), b(a + 1), b(a + 2)
        per, nz, vol, dur = w(a + 3), b(a + 5), b(a + 6), w(a + 7)
        s, hw = sound(per, ampn, tonen, nz, vol, dur)
        ch = st & 7; v = VOICE[1 if ch & 1 else 2 if ch & 2 else 4]
        fr = []
        if name == 'sfx_ninja': pass      # свой звук ниже (делители тона CPC не нужны)
        elif hw and hw[2] < 2 and nz:      # аппаратная огибающая короче 1/50 с — щелчок
            fr = [0xC0]
        else:
            for i in range(0, len(s), 2):
                p, vv, n = max(s[i:i + 2], key=lambda x: x[1])
                if vv < THR: fr.append(0)
                elif p: fr.append(di(p))
                elif n:
                    if n not in noise: noise.append(n)
                    fr.append(0x80 | noise.index(n))
                else: fr.append(0)
            while fr and fr[-1] == 0: fr.pop()
        sfx.append((name, v, fr, len(s)))
        if name == 'sfx_ninja':          # удар Ниндзя (владелец 06.11, вариант 2 «взмах меча»): шум от высокого к низкому,
            fr = []                      # 7 кадров (у CPC — тон 322 -> 381 Гц, «бууп»)
            for n in (2, 3, 4, 6, 8, 11, 14):
                if n not in noise: noise.append(n)
                fr.append(0x80 | noise.index(n))
            sfx[-1] = (name, v, fr, len(s))
        if name == 'sfx_lamp':           # фонарик: у CPC тон 70 дрожит +5/-4 каждые 1/100 с и затухает (13/100 с).
            hi, lo = di(per + 5), di(per - 4)   # покадрово дрожь пропадает (ровный писк) — голоса 1 и 2 вместе 3 кадра
            sfx[-1] = (name, 2, [lo, lo, lo, hi, lo, hi, lo], len(s))   # (биения ~114 Гц), затем трель одним голосом
            sfx.append(('sfx_lamp2', 1, [hi, hi, hi], len(s)))
    assert len(divs) < 0x80
    L = ['; Создано tools/mkcpcsnd.py из orig/cpc/BRUCE.N02 — не править руками.',
         '; snd_divs: делители ВИ53 (номер с 1); mus_v1/2: DB код (бит 7 — потом кадр паузы), кадров (0 — пауза, FF — конец);',
         '; sfx_*: DB голос, затем по кадру код (0 — тишина, 1.. — тон, 80|k — шум snd_noise, C0 — щелчок, FF — конец)',
         'snd_divs:']
    for i in range(0, len(divs), 8): L.append('\t\tDW\t' + ','.join('0x%04X' % d for d in divs[i:i + 8]))
    for c in (1, 2):
        e = mus[c]
        L.append('mus_v%d:\t; %d записей, %.2f с' % (c, len(e), sum(x[1] for x in e) / 50))
        for i in range(0, len(e), 12): L.append('\t\tDB\t' + ', '.join('%d,%d' % tuple(x) for x in e[i:i + 12]))
        L.append('\t\tDB\t0xFF')
    for c in (1, 2):
        L.append('go_v%d:\t; GAME OVER' % c)
        L.append('\t\tDB\t' + ', '.join('%d,%d' % x for x in go[c]) + ', 0xFF')
    L += ['go_end:\t; GAME OVER: после проигрыша — тишина по кругу', '\t\tDB\t0,255, 0xFF']
    H = ['; Создано tools/mkcpcsnd.py: звуки в дырах потоков комнат (бюджет — tools/mkvecdata.py CODE_BUDGET).']
    Q = ['; Создано tools/mkcpcsnd.py: звуки в SND_HI (9640.., под стеком; стек занимает до 60 байт из 112)',
         '\t\t\tORG\tSND_HI',
         'snd_noise:\t; шум AY N (бит раз в 48*N тактов 3 МГц) -> задержка nz_bit, число бит вспышки в прерывании',
         '\t\tDB\t' + ','.join('%d,%d' % (nd(n), nc(n)) for n in noise)]
    for name, v, fr, n in sfx:
        body = ['%s:\t; голос %d, %d кадров (CPC %.2f с)' % (name, v, len(fr), n / 100),
                '\t\tDB\t' + ', '.join(['%d' % v] + ['0x%02X' % x for x in fr] + ['0xFF'])]
        if name in HOLE:
            H += ['\t\t\tORG\tROOMHOLE_%d' % HOLE[name]] + body + ['\t\t\tASSERT\t$ <= CODEEND_%d' % HOLE[name]]
        elif name in HI: Q += body
        else: L += body
    open(os.path.join(ROOT, 'src/i8080/gen/sound.asm'), 'w').write('\n'.join(L) + '\n')
    open(os.path.join(ROOT, 'src/i8080/gen/soundhole.asm'), 'w').write('\n'.join(H) + '\n')
    Q.append('\t\t\tASSERT\t$ <= SND_HI_END')
    open(os.path.join(ROOT, 'src/i8080/gen/soundhi.asm'), 'w').write('\n'.join(Q) + '\n')
    print('музыка %.2f/%.2f с (CPC 1/100: %d/%d), делителей %d, шумов %d' %
          (sum(x[1] + (x[0] >> 7) for x in mus[1]) / 50, sum(x[1] + (x[0] >> 7) for x in mus[2]) / 50, tt[1], tt[2], len(divs), len(noise)))
    for name, v, fr, n in sfx: print(' ', name, v, len(fr), fr[:12])
    if '--wav' in sys.argv: wav(sys.argv[sys.argv.index('--wav') + 1], divs, noise, mus, sfx)


def wav(d, divs, noise, mus, sfx):
    """Прослушка модели ВИ53: меандры двух голосов, шум — случайный делитель на кадр."""
    import wave, struct, random
    os.makedirs(d, exist_ok=True); R = 22050; FR = R // 50
    def render(frames):                  # frames: список кадров [(делитель или None) x2]
        out = []; ph = [0.0, 0.0]
        for f in frames:
            for _ in range(FR):
                s = 0
                for k in (0, 1):
                    if f[k]:
                        ph[k] += 1.5e6 / f[k] / R
                        s += 6000 if (ph[k] % 1) < 0.5 else -6000
                out.append(s)
        return b''.join(struct.pack('<h', max(-32767, min(32767, x))) for x in out)
    def dv(code):
        if not code: return None
        if code == 0xC0: return 40
        if code & 0x80 and code < 0xC0: base = nb(noise[code & 0x3F]); return base + (random.randint(0, 65535) & ((1 << (base.bit_length() - 1)) - 1))
        return divs[code - 1]
    fr = []
    for c in (1, 2):
        seq = []
        for code, n in mus[c]:
            seq += [dv(code & 0x7F)] * n + ([None] if code & 0x80 else [])
        for i, x in enumerate(seq):
            while len(fr) <= i: fr.append([None, None])
            fr[i][c - 1] = x
    def save(n, data):
        with wave.open(os.path.join(d, n + '.wav'), 'w') as f:
            f.setnchannels(1); f.setsampwidth(2); f.setframerate(R); f.writeframes(data)
    save('music', render(fr))
    for name, v, frs, _ in sfx:
        f2 = [[None, None] for _ in frs]
        for i, x in enumerate(frs): f2[i][v - 1] = dv(x)
        if frs == [0xC0]: f2 = [[40, None]]
        save(name, render(f2 + [[None, None]] * 10))


main()
