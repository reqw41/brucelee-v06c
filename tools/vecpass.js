#!/usr/bin/env node
// Длительность проходов pass в тактах (vcycles vector06js): гистограмма по долям кадра (59904), без проходов
// со звуком, загрузкой комнаты, паузой; ожидание кадра (plat_wait) не считается.
//   node tools/vecpass.js build/vec/brucelee.bin <кадров> "<план>"   (план можно взять из файла: @файл)
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
let [ROM, NS, PLAN] = process.argv.slice(2);
if (PLAN && PLAN[0] === '@') PLAN = fs.readFileSync(PLAN.slice(1), 'utf8').trim();
const sym = {};
for (const l of fs.readFileSync(path.join(__dirname, '../build/vec/brucelee.sym'), 'latin1').split('\n')) {
  const m = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const m = E.mk(ROM), plan = VK.parse(PLAN || '');
const SKIP = new Set(['plat_room', 'snd_run', 'snd_hit', 'plat_menu_keys', 'plat_weapon', 'plat_halts', 'plat_game_over'].map((n) => sym[n]));
let cur = -1, skip = false, inWait = false, waitRet = -1, show = 0;
const hist = new Array(8).fill(0); let n = 0, worst = 0, tShow = 0;
const showAt = sym['pass.er'], showFrom = sym['pass.go'];
m.onInstr = (pc) => {
  const c = m.cpu.vcycles || 0;
  if (cur >= 0 && !inWait) cur += c;
  if (pc === sym.plat_wait) { inWait = true; waitRet = m.rd(m.cpu.sp) | m.rd(m.cpu.sp + 1) << 8; }
  else if (inWait && pc === waitRet) inWait = false;
  if (SKIP.has(pc)) skip = true;
  if (pc === sym.pass) {
    if (cur >= 0 && !skip) { const k = Math.min(7, Math.floor(cur / 59904 * 4)); hist[k]++; n++; if (cur > worst) worst = cur; }
    cur = 0; skip = false; inWait = false;
  }
};
for (let f = 0; f < +NS; f++) { VK.apply(m, plan[f]); m.frame(); }
console.log(`проходов ${n}, доля кадра: ` + hist.map((h, i) => `${i * 25}-${i * 25 + 25}%: ${(100 * h / n).toFixed(1)}`).join(', ') + `; наибольший ${(worst / 59904).toFixed(2)} кадра`);
