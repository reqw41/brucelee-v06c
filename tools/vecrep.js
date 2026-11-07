#!/usr/bin/env node
// Стоимость перерисовок (repaint): такты на вызов, размер области, по частям (полосы, клетки со спрайтом и без).
//   node tools/vecrep.js build/vec/brucelee.bin <кадров> "<план>|@файл"
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
const parts = { col_prep: 0, pp_prep: 0, plain_cell: 0, pl_E: 0, pl_C: 0, pl_A: 0, cfq_7: 0, strip_build: 0, rp_dc: 0, sb_cell: 0, dE_t: 0, dA_t: 0, dN_t: 0, dE_0: 0, dA_0: 0, mirror_blk: 0, rect_of: 0, pz_0: 0, pb_t: 0, pb_0: 0 };
const ent = {}; for (const k of Object.keys(parts)) ent[sym[k]] = k;
let depth = null, retTo = -1, inRep = false, repRet = -1, t = 0, calls = 0, cells = 0, area = {};
let stack = [];   // [имя, адрес возврата]
m.onInstr = (pc) => {
  const c = m.cpu.vcycles || 0;
  if (inRep) { t += c; for (const s of stack) parts[s[0]] += c; }
  while (stack.length && pc === stack[stack.length - 1][1]) stack.pop();
  if (inRep && pc === repRet) inRep = false;
  if ((pc === sym.repaint || pc === sym.repaint_ps) && !inRep) { inRep = true; repRet = m.rd(m.cpu.sp) | m.rd(m.cpu.sp + 1) << 8; calls++;
    const r = m.rd(sym.ar1) - m.rd(sym.ar0) + 1, cc = m.rd(sym.ac1) - m.rd(sym.ac0) + 1; cells += r * cc; area[r + 'x' + cc] = (area[r + 'x' + cc] || 0) + 1; }
  if (inRep && ent[pc]) stack.push([ent[pc], m.rd(m.cpu.sp) | m.rd(m.cpu.sp + 1) << 8]);
};
for (let f = 0; f < +NS; f++) { VK.apply(m, plan[f]); m.frame(); }
console.log(`перерисовок ${calls}, тактов на перерисовку ${(t / calls) | 0}, клеток в среднем ${(cells / calls).toFixed(1)}, на клетку ${(t / cells) | 0}`);
console.log('части (на перерисовку): ' + Object.entries(parts).map(([k, v]) => `${k} ${(v / calls) | 0}`).join(', '));
console.log('области (строк x столбцов): ' + Object.entries(area).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([k, v]) => `${k}: ${v}`).join(', '));
