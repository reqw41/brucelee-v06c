// Кто читает теневой экран E000-F7FF (точки) и F800-FAFF (атрибуты) и 5D00-5FFF/6000-62FF: PC -> счёт.
// node stand/zxreads.js [кадров]
'use strict';
const fs = require('fs'), path = require('path');
const ZX48 = require('../tools/zx48.js');
const ROOT = path.join(__dirname, '..');
const zx = new ZX48();
zx.mem.set(fs.readFileSync(path.join(ROOT, 'build/zx_tap.bin')).subarray(0x4000), 0x4000);
const st = JSON.parse(fs.readFileSync(path.join(ROOT, 'build/zx_tap.json')));
const s = zx.cpu.getState(); Object.assign(s, { pc: st.pc, sp: st.sp, i: st.i, imode: st.im }); zx.cpu.setState(s);
const R = { pix: new Map(), att: new Map(), scr: new Map(), map: new Map() };
let pc = 0;
zx.onRead = (a, v, isr) => {
  if (isr) return;
  const k = a >= 0xE000 && a < 0xF800 ? 'pix' : a >= 0xF800 && a < 0xFB00 ? 'att' : a >= 0x4000 && a < 0x5B00 ? 'scr' : a >= 0x5D00 && a < 0x6300 ? 'map' : null;
  if (k) R[k].set(pc, (R[k].get(pc) || 0) + 1);
};
const N = +(process.argv[2] || 3000);
const ev = { 300: ['ENTER'], 310: [], 420: ['ENTER'], 430: [] };
const rnd = (() => { let x = 7; return () => { x ^= x << 13; x >>>= 0; x ^= x >> 17; x ^= x << 5; x >>>= 0; return x / 2 ** 32; }; })();
for (let f = 0; f < N; f++) {
  if (ev[f]) zx.keysOnly(ev[f]);
  else if (f > 500 && f % 20 === 0) zx.keysOnly(['Q', 'A', 'O', 'P', 'Z', 'M'].filter(() => rnd() < 0.3));
  const end = zx.frames + 1;
  while (zx.frames < end) { pc = zx.pc; zx.step(); }
}
for (const k of Object.keys(R)) {
  console.log(k + ':', [...R[k]].sort((a, b) => a[0] - b[0]).map(([p, n]) => p.toString(16) + '×' + n).join(' '));
}
console.log('комната', zx.peek(0xFE03));
