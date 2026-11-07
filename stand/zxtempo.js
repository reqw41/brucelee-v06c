// Темп оригинала: проходы главного цикла (C7A4) за секунду игры. node stand/zxtempo.js
'use strict';
const fs = require('fs'), path = require('path');
const ZX48 = require('../tools/zx48.js');
const ROOT = path.join(__dirname, '..');
const zx = new ZX48();
zx.mem.set(fs.readFileSync(path.join(ROOT, 'build/zx_tap.bin')).subarray(0x4000), 0x4000);
const st = JSON.parse(fs.readFileSync(path.join(ROOT, 'build/zx_tap.json')));
const s = zx.cpu.getState(); Object.assign(s, { pc: st.pc, sp: st.sp, i: st.i, imode: st.im }); zx.cpu.setState(s);
let loops = 0, lastPc = -1, idle = 0, t0 = 0;
const ev = { 300: ['ENTER'], 310: [], 420: ['ENTER'], 430: [], 600: ['P'], 1000: ['O'], 1400: ['P', 'Z'], 1800: [] };
for (let f = 0; f < 2400; f++) {
  if (ev[f]) zx.keysOnly(ev[f]);
  const end = zx.frames + 1;
  while (zx.frames < end) { const p = zx.pc; if (p === 0xC7A4 && lastPc !== 0xC7A4) loops++; lastPc = p; const t = zx.total; zx.step(); if (p >= 0xC7AB && p <= 0xC7B0 && !zx.inIsr) idle += zx.total - t; }
  if (f >= 500 && f % 250 === 249) { console.log(`кадры ${f - 249}-${f}: ${(loops * 50 / 250).toFixed(1)} шагов/с, простой ${(idle / (250 * 69888) * 100).toFixed(0)} %`); loops = 0; idle = 0; }
  if (f === 499) { loops = 0; idle = 0; }
}
