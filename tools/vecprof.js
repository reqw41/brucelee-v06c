#!/usr/bin/env node
// Профиль образа Вектора по подпрограммам (метки без точки) за кадры [от, до): такты vcycles vector06js.
//   node tools/vecprof.js build/vec/brucelee.bin <кадров> "<план>" <от> [N строк]
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const [ROM, NS, PLAN, FROM, TOP] = process.argv.slice(2);
const labs = [];
for (const l of fs.readFileSync(path.join(__dirname, '../build/vec/brucelee.sym'), 'latin1').split('\n')) {
  const m = l.match(process.env.DOTS ? /^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i : /^([\w]+):\s+EQU\s+0x([0-9A-F]+)/i);
  if (m && !/^z[cv]_|^Z_/.test(m[1])) { const a = parseInt(m[2], 16); if (a < 0xA000 && !/^ROOMHOLE|^hcode/.test(m[1])) labs.push([a, m[1]]); }
}
labs.sort((x, y) => x[0] - y[0]);
const owner = new Array(0x10000).fill('?');
for (let i = 0; i < labs.length; i++) for (let a = labs[i][0]; a < (labs[i + 1] ? labs[i + 1][0] : 0xA000); a++) owner[a] = labs[i][1];
const m = E.mk(ROM), plan = VK.parse(PLAN || '');
const prof = {}; let last = -1, on = false, total = 0;
m.onInstr = (pc) => { if (on && last >= 0) { const c = m.cpu.vcycles || 0; const k = owner[last] || '?'; prof[k] = (prof[k] || 0) + c; total += c; } last = pc; };
for (let f = 0; f < +NS; f++) { on = f >= +FROM; VK.apply(m, plan[f]); m.frame(); }
const fr = +NS - +FROM;
console.log(`кадров ${fr}, тактов на кадр ${(total / fr) | 0}`);
for (const [k, v] of Object.entries(prof).sort((a, b) => b[1] - a[1]).slice(0, +TOP || 25)) console.log(k.padEnd(16), (v / fr | 0).toString().padStart(7), (100 * v / total).toFixed(1) + '%');
