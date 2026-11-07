#!/usr/bin/env node
// Прогон образа Вектора без окна (vector06js): план клавиш как у vecshot, счёт проходов pass по кадрам
// (темп: на ZX 50 шагов/с), снимок в конце.
//   node tools/vecrun.js build/vec/brucelee.bin <кадров> "<кадр>:<клавиша>+ ..." [out.png] [--from кадр]
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu');
const args = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const [ROM, NS, PLAN, OUT] = args;
const sym = {};
for (const l of fs.readFileSync(path.join(__dirname, '../build/vec/brucelee.sym'), 'latin1').split('\n')) {
  const m = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const m = E.mk(ROM);
const VK = require('./vecshot_keys');
const plan = VK.parse(PLAN || '');
let passes = 0, prevT = 0;
const hist = {};
m.onInstr = (pc) => { if (pc === sym.pass) passes++; };
const N = +NS || 300;
let gap = 0, maxGap = 0, gapAt = 0; let inGame = 0, lagFrames = 0, tot = 0; const line = []; let p50 = 0;
for (let f = 0; f < N; f++) {
  VK.apply(m, plan[f]);
  const p0 = passes;
  m.frame();
  const d = passes - p0;
  if (passes > 0) { if (d) { if (gap > maxGap) { maxGap = gap; gapAt = f; } gap = 0; } else gap++; }
  if ((f + 1) % 50 === 0) { line.push(passes - p50); p50 = passes; }
  if (passes > 0) { hist[d] = (hist[d] || 0) + 1; tot += d; inGame++; }
}
console.log(`кадров ${N}, проходов ${passes}; проходов за кадр: ${JSON.stringify(hist)}; комната ${m.rd(sym.zv_FE03)}, Брюс x,y ${m.rd(sym.zc_CCAB)},${m.rd(sym.zc_CCAC)}`);
if (OUT) { const pp = m.rd(sym.pal_ptr) | m.rd(sym.pal_ptr + 1) << 8; VK.shot(m, OUT, pp); }
console.log(`наибольший перерыв без проходов: ${maxGap} кадров (до кадра ${gapAt})`);
console.log('проходов по 50 кадров: ' + line.join(' '));
