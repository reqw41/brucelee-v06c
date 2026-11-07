#!/usr/bin/env python3
# Генератор src/vec/render_pl_{a,b,c,d}.asm (по дырам комнат: a — pb/pe/qu_3/qp_3, b — qu/qp 1, 2, c — таблицы и pl_X, d — cfq, e — pz): вывод клетки по плоскостям (решение владельца 05.11.2026: враги — одна плоскость
# OR, Брюс — три цвета с маской). Все подпрограммы плоскости: HL = источник строки 0 клетки, DE = точки тайла
# (кратно 8), B = старший байт плоскости, C = верхняя строка; 8 строк вниз (DEC C).
#   pb_*   без точек спрайтов: операция тайла (0 — 0, t — точки, nt — ~точки, ff — FF)
#   qu_k / qp_k  четвёрки (маска, точки C000, точки A000, точки E000): чернила плоскости — (тайл & маска) | точки k,
#          без чернил и без бумаги — точки k
#   pl_E / pl_C / pl_A  одна плоскость клетки по rp_ops, rp_cm (0 — тайл, 1 — четвёрки), rp_flc, rp_tile, rp_src, rp_scr
#   cfq_v  клетка Брюса/полосы на чёрной бумаге во всех трёх плоскостях, v = чернила
#   python3 -I tools/mkplanes.py
import os
PL = [('E', 1, 0x00, 3, 0), ('C', 2, 0x20, 1, 1), ('A', 4, 0x40, 2, 2)]   # имя, бит, смещение от E0, k, p (optab)
o = ['; Создано tools/mkplanes.py — вывод клетки по плоскостям.']
def last(body):                      # 7 строк + восьмая без продвижения
    return ['\t\t\tREPT\t7'] + body[0] + ['\t\t\tENDR'] + body[1] + ['\t\t\tret']
I = lambda *a: ['\t\t\t' + x for x in a]
o += ['pb_0:\t\txor\ta', 'pb_fill:\tREPT\t7'] + I('ld\t(bc),a', 'dec\tc') + ['\t\t\tENDR'] + I('ld\t(bc),a', 'ret')
o += ['pb_ff:\t\tld\ta,0xFF', '\t\t\tjp\tpb_fill']
o += ['pb_t:'] + last((I('ld\ta,(de)', 'ld\t(bc),a', 'dec\tc', 'inc\te'), I('ld\ta,(de)', 'ld\t(bc),a')))
o += ['pb_nt:'] + last((I('ld\ta,(de)', 'cpl', 'ld\t(bc),a', 'dec\tc', 'inc\te'), I('ld\ta,(de)', 'cpl', 'ld\t(bc),a')))
o_n = ['; Создано tools/mkplanes.py: плоскость, чужая для врага — операция тайла & ~точки врага.']
o_a = o; o = ['; Создано tools/mkplanes.py.']
for _, _, _, k, _ in PL:
    if k == 1: o_a += o[1:]; o = ['; Создано tools/mkplanes.py.']
    o += ['qu_%d:' % k] + last((I('ld\ta,(de)', 'and\t(hl)', *['inc\thl'] * k, 'or\t(hl)', *['inc\thl'] * (4 - k), 'ld\t(bc),a', 'dec\tc', 'inc\te'),
                               I('ld\ta,(de)', 'and\t(hl)', *['inc\thl'] * k, 'or\t(hl)', 'ld\t(bc),a')))
    o += ['qp_%d:' % k] + last((I(*['inc\thl'] * k, 'ld\ta,(hl)', 'ld\t(bc),a', *['inc\thl'] * (4 - k), 'dec\tc'),
                               I(*['inc\thl'] * k, 'ld\ta,(hl)', 'ld\t(bc),a')))
o_b = o; o = ['; Создано tools/mkplanes.py.']
# таблицы: операция 0..3 -> подпрограмма (одна страница, см. ASSERT в main.asm)
o += ['pl_tabs:', 'tabP:\t\tdw\tpb_0, pb_t, pb_nt, pb_ff', ]
for n, _, _, k, _ in PL: o += ['tabQ_%s:\tdw\tqp_%d, qu_%d, qg_2, qg_3' % (n, k, k)]
o += ['pl_tabs_end:', 'qg_2:\t\tld\ta,2', '\t\t\tld\t(g_op),a', '\t\t\tjp\tqg', 'qg_3:\t\tld\ta,3', '\t\t\tld\t(g_op),a', '\t\t\tjp\tqg']
for n, bit, hi, k, p in PL:
    o += ['pl_%s:\t\tld\ta,(rp_ops)' % n] + I(*['rrca'] * (2 * p), 'and\t3', 'ld\te,a', 'ld\t(g_op),a', 'ld\ta,(rp_cmc)', 'or\ta',
         'jp\tz,.p')
    o += ['.q:\t\t\tld\ta,(rp_flc)'] + I('or\ta', 'jp\tnz,.f', 'ld\thl,tabQ_%s' % n, 'jp\t.go')
    o += ['.f:\t\t\tld\thl,qgf'] + I('jp\t.g1')
    o += ['.p:\t\t\tld\thl,tabP']
    o += ['.go:\t\tld\ta,e'] + I('add\ta,a', 'add\ta,l', 'ld\tl,a', 'ld\ta,(hl)', 'inc\thl', 'ld\th,(hl)', 'ld\tl,a')
    o += ['.g1:\t\tld\t(.j+1),hl'] + I('ld\ta,%d' % k, 'ld\t(g_k),a', 'ld\ta,(rp_scr+1)', *(['sub\t0x%02X' % hi] if hi else []), 'ld\tb,a',
         'ld\ta,(rp_scr)', 'ld\tc,a', 'ld\thl,(rp_tile)', 'ex\tde,hl', 'ld\thl,(rp_src)')
    o += ['.j:\t\t\tjp\t0']
# клетка Брюса/полосы на чёрной бумаге (операции 0/1 во всех плоскостях): v = чернила; вход как у плоскости E
o_c = o; o = ['; Создано tools/mkplanes.py.']
o += ['cfq_tab:\tdw\t' + ', '.join('cfq_%d' % v for v in range(8))]
for v in range(8):
    L = ['cfq_%d:' % v]
    for i, (n, bit, hi, k, p) in enumerate(PL):
        ink = v & bit
        fn = ('qu_%d' if ink else 'qp_%d') % k
        if i: L += I('ld\ta,b', 'sub\t0x20', 'ld\tb,a')
        if i == 2: L += I('jp\t' + fn); break
        L += I('push\thl', *(['push\tde'] if ink else []), 'push\tbc', 'call\t' + fn, 'pop\tbc', *(['pop\tde'] if ink else []), 'pop\thl')
    o += L
o_d = o; o = ['; Создано tools/mkplanes.py.']
o += ['pz_tab:\t\tdw\t' + ', '.join('pz_%d' % v for v in range(8))]
for v in range(8):
    L = ['pz_%d:' % v]
    for i, (n, bit, hi, k, p) in enumerate(PL):
        ink = v & bit
        fn = 'pb_t' if ink else 'pb_0'
        if i: L += I('ld\ta,b', 'sub\t0x20', 'ld\tb,a')
        if i == 2: L += I('jp\t' + fn); break
        L += I(*(['push\tde'] if ink else []), 'push\tbc', 'call\t' + fn, 'pop\tbc', *(['pop\tde'] if ink else []))
    o += L
# операция тайла плоскости по атрибуту (64 байта на плоскость): optab_E/C/A
t = ['; Создано tools/mkplanes.py: операция тайла плоскости p по атрибуту (0 — 0, 1 — точки, 2 — ~точки, 3 — FF).']
for n, bit, hi, k, p in PL:
    t.append('optab_%s:' % n)
    for a0 in range(0, 64, 16): t.append('\t\tDB\t' + ','.join(str(((a >> p) & 1) | (((a >> (p + 3)) & 1) << 1)) for a in range(a0, a0 + 16)))
t.append('; обращение битов байта (отражение кадров, mirror_blk); таблица — с границы страницы')
t.append('\t\t\tALIGN\t256')
t.append('rev8t:')
for a0 in range(0, 256, 16): t.append('\t\tDB\t' + ','.join(str(int('{:08b}'.format(a)[::-1], 2)) for a in range(a0, a0 + 16)))
t.append('cb16:\t\tds\t16\t\t\t\t; клетка края фигуры (render.asm cb_cell) — с начала страницы после rev8t')
# прямой вывод клетки одного персонажа из его кадра (2 байта на строку: S — все точки, K — чёрные; Y = S xor K),
# чёрная бумага: HL = строка 0 клетки в кадре, DE = точки тайла, B = старший байт плоскости, C = верхняя строка.
#   dE_t: ((T | S) xor S) | K   dE_0: K   dA_t: (T | S) xor K   dA_0: S xor K   dN_t: (T | S) xor S   (dN_0 = pb_0)
x = ['; Создано tools/mkplanes.py: прямой вывод клетки одного персонажа (render.asm, rp_dc).']
x += ['dE_t:'] + last((I('ld\ta,(de)', 'or\t(hl)', 'xor\t(hl)', 'inc\thl', 'or\t(hl)', 'ld\t(bc),a', 'inc\thl', 'dec\tc', 'inc\te'),
                      I('ld\ta,(de)', 'or\t(hl)', 'xor\t(hl)', 'inc\thl', 'or\t(hl)', 'ld\t(bc),a')))
x += ['dE_0:'] + last((I('inc\thl', 'ld\ta,(hl)', 'ld\t(bc),a', 'inc\thl', 'dec\tc'), I('inc\thl', 'ld\ta,(hl)', 'ld\t(bc),a')))
x += ['dA_t:'] + last((I('ld\ta,(de)', 'or\t(hl)', 'inc\thl', 'xor\t(hl)', 'ld\t(bc),a', 'inc\thl', 'dec\tc', 'inc\te'),
                      I('ld\ta,(de)', 'or\t(hl)', 'inc\thl', 'xor\t(hl)', 'ld\t(bc),a')))
x += ['dA_0:'] + last((I('ld\ta,(hl)', 'inc\thl', 'xor\t(hl)', 'ld\t(bc),a', 'inc\thl', 'dec\tc'), I('ld\ta,(hl)', 'inc\thl', 'xor\t(hl)', 'ld\t(bc),a')))
x += ['dN_t:'] + last((I('ld\ta,(de)', 'or\t(hl)', 'xor\t(hl)', 'ld\t(bc),a', 'inc\thl', 'inc\thl', 'dec\tc', 'inc\te'),
                      I('ld\ta,(de)', 'or\t(hl)', 'xor\t(hl)', 'ld\t(bc),a')))
x += ['dfq_tab:\tdw\t' + ', '.join('dfq_e%d' % v for v in range(8)), '\t\tdw\t' + ', '.join('dfq_b%d' % v for v in range(8))]
for kd in 'eb':
    for v in range(8):
        fns = ['dE_t' if v & 1 else 'dE_0',
               ('dA_t' if v & 2 else 'dA_0') if kd == 'b' else ('dN_t' if v & 2 else 'pb_0'),
               'dA_t' if v & 4 else 'dA_0']
        L = ['dfq_%s%d:' % (kd, v)]
        for i, fn in enumerate(fns):
            if i: L += I('ld\ta,b', 'sub\t0x20', 'ld\tb,a')
            if i == 2: L += I('jp\t' + fn); break
            L += I('push\thl', 'push\tde', 'push\tbc', 'call\t' + fn, 'pop\tbc', 'pop\tde', 'pop\thl')
        x += L
D = os.path.join(os.path.dirname(__file__), '../src/vec/')
open(D + 'render_pl_x.asm', 'w').write('\n'.join(x) + '\n')
open(D + 'render_pl_t.asm', 'w').write('\n'.join(t) + '\n')
for n, x in (('n', o_n), ('a', o_a), ('b', o_b), ('c', o_c), ('d', o_d), ('e', o)): open(D + 'render_pl_%s.asm' % n, 'w').write('\n'.join(x) + '\n')
