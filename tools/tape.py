#!/usr/bin/env python3
"""Блоки TAP/TZX: список и выгрузка данных. tools/tape.py <файл> [каталог_выгрузки]
TZX: блоки 10 (стандарт), 11 (турбо), 14 (чистые данные); прочие — только в списке."""
import sys, os, struct
def tap_blocks(d):
    i = 0
    while i + 2 <= len(d):
        n = struct.unpack_from('<H', d, i)[0]; yield ('10', d[i+2:i+2+n]); i += 2 + n
def tzx_blocks(d):
    i = 10
    while i < len(d):
        t = d[i]; i += 1
        if t == 0x10: n = struct.unpack_from('<H', d, i+2)[0]; yield ('10', d[i+4:i+4+n]); i += 4 + n
        elif t == 0x11: n = int.from_bytes(d[i+15:i+18], 'little'); yield ('11', d[i+18:i+18+n]); i += 18 + n
        elif t == 0x14: n = int.from_bytes(d[i+7:i+10], 'little'); yield ('14', d[i+10:i+10+n]); i += 10 + n
        elif t == 0x12: i += 4
        elif t == 0x13: i += 1 + 2 * d[i]
        elif t == 0x20: i += 2
        elif t in (0x21, 0x30): yield ('%02X' % t, d[i+1:i+1+d[i]]); i += 1 + d[i]
        elif t == 0x22: pass
        elif t == 0x32: n = struct.unpack_from('<H', d, i)[0]; yield ('32', d[i+2:i+2+n]); i += 2 + n
        elif t == 0x15: n = int.from_bytes(d[i+5:i+8], 'little'); yield ('15', b''); i += 8 + n
        else: print('неизвестный блок %02X на %d' % (t, i - 1)); break
f = sys.argv[1]; d = open(f, 'rb').read()
bl = list(tzx_blocks(d) if d[:7] == b'ZXTape!' else tap_blocks(d))
out = sys.argv[2] if len(sys.argv) > 2 else None
if out: os.makedirs(out, exist_ok=True)
hdr = None
for k, (t, b) in enumerate(bl):
    info = ''
    if t in ('10', '11') and len(b) == 19 and b[0] == 0:
        typ, name, ln, p1, p2 = b[1], b[2:12].decode('latin1'), *struct.unpack_from('<HHH', b, 12)
        info = 'заголовок тип %d "%s" длина %d p1=%d (%04X) p2=%d' % (typ, name, ln, p1, p1, p2); hdr = (name.strip(), p1)
    elif t in ('10', '11', '14'):
        info = 'данные флаг %02X, %d Б' % (b[0], len(b) - 2) if b else 'пусто'
        if out:
            nm = '%02d_%s.bin' % (k, hdr[0].replace(' ', '_') if hdr else 'blk')
            open(os.path.join(out, nm), 'wb').write(b[1:-1] if t != '14' else b)
            if hdr: info += ' -> %s @%04X' % (nm, hdr[1])
        hdr = None
    else: info = repr(b[:60])
    print('%2d %s %s' % (k, t, info))
