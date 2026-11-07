#!/usr/bin/env node
// Карта экранов (владелец 07.11, по образцу ataricompendium: все комнаты одной картинкой по переходам). Каждая комната
// грузится как в стендах (next_player), персонажи не рисуются (plat_draw -> RET), снимается поле (строки 32..207).
//   node tools/vecmap.js [образ]  -> build/map/room_NN.png (раскладка — tools/mkmap.py)
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const ROOT = path.join(__dirname, '..');
const ROM = process.argv[2] || path.join(ROOT, 'build/vec/brucelee.bin');
const sym = {}; for (const l of fs.readFileSync(ROM.replace(/\.bin$/, '.sym'), 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const OUT = path.join(ROOT, 'build/map'); fs.mkdirSync(OUT, { recursive: true });
for (let n = 0; n < 20; n++) {
  const m = E.mk(ROM); let st = 'title', passes = 0;
  m.onInstr = (pc) => {
    if (pc !== sym.pass) return;
    if (st === 'title') { st = 'go'; return; }
    if (st === 'go') { m.wr(sym.plat_draw, 0xC9); m.wr(sym.zv_FE0E, n); m.wr(sym.zv_FE04, 1); m.cpu.pc = sym.next_player; st = 'run'; return; }
    passes++;
  };
  const plan = VK.parse('160:space+ 200:space-');
  for (let f = 0; f < 2000 && passes < 40; f++) { VK.apply(m, plan[f]); m.frame(); }
  VK.shot(m, path.join(OUT, `full_${String(n).padStart(2, '0')}.png`), m.rd(sym.pal_ptr) | m.rd(sym.pal_ptr + 1) << 8);
}
console.log('карта: снято 20 комнат -> build/map');
