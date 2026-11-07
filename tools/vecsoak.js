#!/usr/bin/env node
// Долгий прогон образа со случайным вводом: PC вне кода, SP вне стека, зависание (нет проходов pass),
// комнаты, снимки раз в SHOT кадров.   node tools/vecsoak.js build/vec/brucelee.bin <кадров> [каталог снимков] [зерно]
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const [ROM, NS, DIR, SEED] = process.argv.slice(2);
const sym = {};
for (const l of fs.readFileSync(path.join(__dirname, '../build/vec/brucelee.sym'), 'latin1').split('\n')) {
  const m = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
let seed = +(SEED || 1);
const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
const m = E.mk(ROM);
if (process.env.NEG === '1') { m.wr(sym.tabQ_E + 2, sym.qp_3 & 255); m.wr(sym.tabQ_E + 3, sym.qp_3 >> 8); }   // негатив: Брюс в E000 без тайла
if (process.env.NEG === '3') { m.wr(sym.cfq_tab + 14, sym.cfq_0 & 255); m.wr(sym.cfq_tab + 15, sym.cfq_0 >> 8); } // негатив: белые чернила как чёрные
if (process.env.NEG === '2') m.wr(sym['strip_build.b'] + 15, 0);   // негатив: у Брюса в C000 нет своего цвета (жёлтый -> зелёный)
let passes = 0, bad = 0, minSP = 0xffff;
const rooms = new Set();
const HITS = ['plat_game_over', 'title_start', 'title_restart', 'menu', 'start_game', 'plat_win_msg', 'plat_weapon', 'bruce_died', 'plat_menu_keys'];
const hits = {}; const hitAt = {}; for (const h of HITS) { hits[sym[h]] = 0; }
// сверка экрана с композицией disp (CHECK=n — каждые n проходов): тайл + атрибут amap, спрайты белые, дырка маски — бумага
const CHECK = +(process.env.CHECK || 0); let ckN = 0, ckBad = 0, ckCells = 0;
const compose0 = require('./veccompose').make(m, sym);
function compose() { const r = compose0(); ckN++; if (r.bad) { if (ckBad < 3) for (const [rr, c, w, g, sp] of r.cells.slice(0, 3)) console.log(`  кадр ${m.frames}: клетка ${rr},${c} ждали ${w} на экране ${g}${sp ? ' (спрайт)' : ''}`); ckBad++; ckCells += r.bad; } }
let wdBad = 0, wdN = 0;                         // после показа (pass.er) want == disp у каждого персонажа
function wantDisp() { if (m.rd(sym.sh_def)) return; wdN++; for (let i = 0; i < 3; i++) { const w = sym.want + 8 * i, d = sym.disp + 8 * i;
  if (!m.rd(w) && !m.rd(d)) continue; for (let k = 0; k < 8; k++) if (m.rd(w + k) !== m.rd(d + k)) { if (wdBad++ < 3) console.log(`  кадр ${m.frames}: персонаж ${i}: want != disp (байт ${k}) want ${[0,1,2,3,4,5,6,7].map((q) => m.rd(w + q).toString(16)).join(" ")} disp ${[0,1,2,3,4,5,6,7].map((q) => m.rd(d + q).toString(16)).join(" ")}`); return; } } }
m.onInstr = (pc) => {
  if (pc === sym['pass.er']) wantDisp();
  if (pc === sym.pass) { passes++; if (CHECK && passes % CHECK === 0) compose(); }
  if (pc in hits) { hits[pc]++; }
  if (pc >= sym.code_end && pc !== 0x38 && ![0, 1, 2, 3, 4, 5, 6, 7, 8, 9].some((i) => pc >= sym['hcode' + i] && pc < sym['hcode' + i + '_end']) && bad < 5) { bad++; console.log(`PC ${pc.toString(16)} вне кода, кадр ${m.frames}`); }
  const sp = m.cpu.sp; if (sp < minSP) minSP = sp;
};
if (DIR) fs.mkdirSync(DIR, { recursive: true });
const keys = ['left', 'right', 'up', 'down', 'space'];
const P = +(process.env.PRIGHT || 0.5);
let lastP = 0, stuck = 0;
for (let f = 0; f < +NS; f++) {
  if (f === 160) VK.apply(m, [['space', true]]);
  if (f === 200) VK.apply(m, [['space', false]]);
  if (process.env.PAUSE && f > 1000 && (f % 1000 === 250 || f % 1000 === 500)) VK.apply(m, [['vk', true]]);
  if (process.env.PAUSE && f > 1000 && (f % 1000 === 270 || f % 1000 === 520)) VK.apply(m, [['vk', false]]);
  if (f > 400 && f % 12 === 0) for (const k of keys) VK.apply(m, [[k, rnd() < (k === 'right' ? P : 0.25)]]);
  m.frame();
  if (m.rd(sym.zv_FE03) !== undefined && passes) rooms.add(m.rd(sym.zv_FE03));
  if (f % 100 === 99) { if (passes === lastP && f > 600) { stuck++; if (stuck < 4) console.log(`нет проходов 100 кадров, кадр ${f}, PC ${m.cpu.pc.toString(16)}`); } lastP = passes; }
  if (DIR && f % 1000 === 999) { const pp = m.rd(sym.pal_ptr) | m.rd(sym.pal_ptr + 1) << 8; VK.shot(m, `${DIR}/f${String(f + 1).padStart(6, '0')}.png`, pp); }
}
console.log(`want == disp после показа: ${wdN} раз, с расхождениями ${wdBad}`);
if (CHECK) console.log(`сверка экрана: ${ckN} раз, с расхождениями ${ckBad} (клеток ${ckCells})`);
console.log(HITS.map((h) => h + ' ' + hits[sym[h]]).join(', '));
console.log(`кадров ${NS}, проходов ${passes}, мин. SP ${minSP.toString(16)}, комнаты ${[...rooms].sort((a, b) => a - b).join(',')}, ошибок PC ${bad}, жизни ${String.fromCharCode(m.rd(sym.zv_FED0), m.rd(sym.zv_FED1))}`);
