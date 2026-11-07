// Снять образ игры с BruceLee(fixed).tap: повторить BASIC-загрузчик на модели ZX 48K.
// LD-BYTES ПЗУ (0x0556) перехватывается: следующий блок ленты кладётся по IX/DE, флаги CY=1.
// Выход: build/zx_tap.bin (64 КБ) и build/zx_tap.json (регистры в момент входа в C000/C4B8).
'use strict';
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..');
const ZX48 = require('../tools/zx48.js');
const tap = fs.readFileSync(path.join(ROOT, 'orig/bugfix/BruceLee(fixed).tap'));
const blocks = []; for (let i = 0; i < tap.length;) { const n = tap[i] | tap[i + 1] << 8; blocks.push(tap.subarray(i + 2, i + 2 + n)); i += 2 + n; }
let bi = 0;
const zx = new ZX48();
const cpu = zx.cpu;
function feed(addr, len) {                       // данные блока (без флага и контрольной суммы)
  while (bi < blocks.length && blocks[bi][0] === 0) bi++;   // заголовки пропускаем
  const b = blocks[bi++]; const d = b.subarray(1, b.length - 1);
  if (len !== d.length) console.log(`  внимание: запрошено ${len}, в блоке ${d.length}`);
  for (let k = 0; k < Math.min(len, d.length); k++) zx.mem[(addr + k) & 0xffff] = d[k];
  console.log(`блок ${bi - 1}: ${d.length} Б -> ${addr.toString(16)}`);
}
// BASIC: CLEAR 24791; LOAD ""SCREEN$; POKE 23739,111; LOAD "bruce lee3" CODE; CLS; LOAD "bruce lee2" CODE;
//        RANDOMIZE USR 24830; LOAD "bruce lee1" CODE 16464; RANDOMIZE USR 24833
bi = 2; feed(0x4000, 6912); zx.mem[23739] = 111;
feed(0x60D8, 31749);
for (let a = 0x4000; a < 0x5800; a++) zx.mem[a] = 0;           // CLS
feed(0x4000, 12);
function usr(pc, maxFrames) {
  const st = cpu.getState(); st.pc = pc; st.sp = 0x60D0; st.iff1 = 0; st.imode = 1; st.i = 0x3f; cpu.setState(st);
  zx.mem[0x60D0] = 0xFF; zx.mem[0x60D1] = 0xFF;                 // возврат в FFFF = «вернулись в BASIC»
  const lim = zx.total + 69888 * maxFrames;
  while (zx.total < lim) {
    const p = zx.pc;
    if (p === 0xFFFF) return 'ret';
    if (p === 0xC000 || p === 0xC4B8) return 'game';
    if (p === 0x0556) {                                        // LD-BYTES
      const s = cpu.getState(); const addr = s.ix, len = s.d << 8 | s.e;
      if (s.flags.C) feed(addr, len); else console.log('VERIFY');
      s.ix = (addr + len) & 0xffff; s.d = 0; s.e = 0; s.flags.C = 1;
      const sp = s.sp; s.pc = zx.mem[sp] | zx.mem[sp + 1] << 8; s.sp = sp + 2; cpu.setState(s); continue;
    }
    zx.step();
  }
  return 'timeout';
}
console.log('USR 24830:', usr(24830, 200), 'pc', zx.pc.toString(16));
feed(16464, 1968);
const r = usr(24833, 3000);
const s = cpu.getState();
console.log('USR 24833:', r, 'pc', zx.pc.toString(16), 'sp', s.sp.toString(16), 'I', s.i.toString(16), 'IM', s.imode, 'iff', s.iff1);
fs.writeFileSync(path.join(ROOT, 'build/zx_tap.bin'), zx.mem);
fs.writeFileSync(path.join(ROOT, 'build/zx_tap.json'), JSON.stringify({ pc: zx.pc, sp: s.sp, i: s.i, im: s.imode, iff1: s.iff1 }));
