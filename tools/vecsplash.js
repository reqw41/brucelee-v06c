#!/usr/bin/env node
// Образ ROM с заставкой (rom/BruceLee-v06c.r0m): после клавиши распаковка игры; при входе в boot память 0000..9FFF
// должна совпасть с build/vec/brucelee.bin байт в байт.   node tools/vecsplash.js [rom] [игра]
'use strict';
const fs = require('fs'), path = require('path'); const R = path.join(__dirname, '..');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const ROM = process.argv[2] || R + '/rom/BruceLee-v06c.r0m', GAME = process.argv[3] || R + '/build/vec/brucelee.bin';
const sym = {}; for (const l of fs.readFileSync(GAME.replace(/\.bin$/, '.sym'), 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const g = fs.readFileSync(GAME), m = E.mk(ROM); let hit = false, bad = -1, n = 0;
m.onInstr = (pc) => { if (pc === sym.boot && !hit && m.frames > 5) { hit = true; for (let a = 0; a < 0xA000; a++) if (m.rd(a) !== g[a]) { if (bad < 0) bad = a; n++; } } };
const plan = VK.parse('100:space+ 110:space-');
for (let f = 0; f < 600 && !hit; f++) { VK.apply(m, plan[f]); m.frame(); }
console.log(`заставка: ${!hit ? 'игра не запустилась' : n ? `распаковка расходится: ${n} байт, первый ${bad.toString(16)}` : 'распаковка совпадает с игрой'}`);
process.exit(hit && !n ? 0 : 1);
