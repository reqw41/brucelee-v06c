#!/usr/bin/env node
// Чем заняты долгие проходы: профиль по подпрограммам отдельно для проходов дольше кадра и для остальных
// (ожидание plat_wait не считается; проходы со сменой комнаты, звуком, паузой отброшены, как в vecpass).
//   node tools/veclong.js build/vec/brucelee.bin <кадров> @build/randplan.txt [N строк]
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
let [ROM, NS, PLAN, TOP] = process.argv.slice(2);
if (PLAN && PLAN[0] === '@') PLAN = fs.readFileSync(PLAN.slice(1), 'utf8').trim();
const sym = {}, labs = [];
for (const l of fs.readFileSync(path.join(__dirname, '../build/vec/brucelee.sym'), 'latin1').split('\n')) {
  const m = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (!m) continue;
  const a = parseInt(m[2], 16); sym[m[1]] = a;
  if (!m[1].includes('.') && !/^z[cv]_|^Z_/.test(m[1]) && a < 0xA000 && !/^ROOMHOLE|^hcode/.test(m[1])) labs.push([a, m[1]]);
}
labs.sort((x, y) => x[0] - y[0]);
const owner = new Array(0x10000).fill('?');
for (let i = 0; i < labs.length; i++) for (let a = labs[i][0]; a < (labs[i + 1] ? labs[i + 1][0] : 0xA000); a++) owner[a] = labs[i][1];
const SKIP = new Set(['plat_room', 'snd_run', 'snd_hit', 'plat_menu_keys', 'plat_weapon', 'plat_halts', 'plat_game_over'].map((n) => sym[n]));
const m = E.mk(ROM), plan = VK.parse(PLAN || '');
const P = { long: {}, short: {} }, N = { long: 0, short: 0 }, T = { long: 0, short: 0 };
let cur = null, cyc = 0, skip = false, last = -1, started = false, rps = 0, cells = 0, cset = new Set();
const RP = { long: [0, 0, 0], short: [0, 0, 0] };
m.onInstr = (pc) => {
  const c = m.cpu.vcycles || 0;
  if (cur && last >= 0) { const k = owner[last]; if (k !== 'plat_wait') { cur[k] = (cur[k] || 0) + c; cyc += c; } }
  last = pc;
  if (SKIP.has(pc)) skip = true;
  if (pc === sym.rp_band) { rps++; cells += (m.rd(sym.ar1) - m.rd(sym.ar0) + 1) * (m.rd(sym.ac1) - m.rd(sym.ac0) + 1);
    for (let r = m.rd(sym.ar0); r <= m.rd(sym.ar1); r++) for (let c = m.rd(sym.ac0); c <= m.rd(sym.ac1); c++) cset.add(r * 32 + c); }
  if (pc === sym.pass) {
    if (cur && started && !skip) { const cl = cyc > 59904 ? 'long' : 'short'; N[cl]++; T[cl] += cyc; RP[cl][0] += rps; RP[cl][1] += cells; RP[cl][2] += cset.size;
      for (const k in cur) P[cl][k] = (P[cl][k] || 0) + cur[k]; }
    started = true; cur = {}; cyc = 0; skip = false; rps = 0; cells = 0; cset = new Set();
  }
};
for (let f = 0; f < +NS; f++) { VK.apply(m, plan[f]); m.frame(); }
for (const cl of ['long', 'short']) {
  console.log(`${cl === 'long' ? 'долгие (> кадра)' : 'остальные'}: ${N[cl]} проходов, в среднем ${(T[cl] / N[cl] | 0)} тактов, перерисовок ${(RP[cl][0] / N[cl]).toFixed(2)}, клеток ${(RP[cl][1] / N[cl]).toFixed(1)} (разных ${(RP[cl][2] / N[cl]).toFixed(1)})`);
  for (const [k, v] of Object.entries(P[cl]).sort((a, b) => b[1] - a[1]).slice(0, +TOP || 20))
    console.log('  ' + k.padEnd(16), (v / N[cl] | 0).toString().padStart(7), (100 * v / T[cl]).toFixed(1) + '%');
}
