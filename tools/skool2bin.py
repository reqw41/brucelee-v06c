#!/usr/bin/env python3
"""Собрать образ памяти ZX 48K из skool: build/zx48.bin (65536 Б, 0000-5AFF нули), через skool2bin SkoolKit."""
import sys, subprocess, os
root = os.path.join(os.path.dirname(__file__), '..')
skool = os.path.join(root, 'ref/sgr/brucelee-zx/brucelee.skool')
out = os.path.join(root, 'build/zx_5b00.bin')
os.makedirs(os.path.dirname(out), exist_ok=True)
subprocess.check_call([os.path.join(root,'tools/.venv/bin/skool2bin.py'), '-i', skool, out])
data = open(out, 'rb').read()
img = bytearray(0x5B00) + data
img += bytes(65536 - len(img))
open(os.path.join(root, 'build/zx48.bin'), 'wb').write(img)
print('5B00..%04X, %d байт' % (0x5B00 + len(data) - 1, len(data)))
