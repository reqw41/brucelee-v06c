// Прогон игры на модели ZX с образа TAP: node stand/zxrun.js <кадров> <каталог> ["кадр:клавиши,..."]
// Снимок экрана каждые 50 кадров (PPM). Клавиши — имена zx48 (ENTER, SPACE, буквы), "-" — отпустить.
'use strict';
const fs = require('fs'), path = require('path');
const ZX48 = require('../tools/zx48.js');
const ROOT = path.join(__dirname, '..');
const [N = 500, out = 'build/zxrun', script = ''] = process.argv.slice(2);
const zx = new ZX48();
zx.mem.set(fs.readFileSync(path.join(ROOT, 'build/zx_tap.bin')).subarray(0x4000), 0x4000);
const st = JSON.parse(fs.readFileSync(path.join(ROOT, 'build/zx_tap.json')));
const s = zx.cpu.getState(); Object.assign(s, { pc: st.pc, sp: st.sp, i: st.i, imode: st.im, iff1: 0, iff2: 0 }); zx.cpu.setState(s);
const ev = {}; for (const e of script.split(',').filter(Boolean)) { const [f, k] = e.split(':'); ev[+f] = k === '-' ? [] : k.split('+'); }
fs.mkdirSync(path.join(ROOT, out), { recursive: true });
for (let f = 0; f < +N; f++) {
  if (ev[f]) zx.keysOnly(ev[f]);
  zx.runFrames(1);
  if (f % 50 === 49) fs.writeFileSync(path.join(ROOT, out, `f${String(f + 1).padStart(5, '0')}.ppm`), zx.ppm());
}
console.log('pc', zx.pc.toString(16), 'кадров', zx.frames, 'кадр игры FE05 =', zx.peek(0xFE05) | zx.peek(0xFE06) << 8);
