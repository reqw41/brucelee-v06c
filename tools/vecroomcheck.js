#!/usr/bin/env node
// Сверка вывода комнат: в образе Вектора по очереди грузятся все 20 комнат (FE0E = n, переход на next_player
// в начале прохода), сразу после загрузки (персонажей на экране нет) экран строк 2..23 сравнивается с тайлами и
// атрибутами ZX из памяти образа (карта 6000, таблица цветов (6003)): точка тайла — чернила, иначе бумага.
// Снимки — в каталог, если задан.   node tools/vecroomcheck.js build/vec/brucelee.bin [каталог]
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const [ROM, DIR] = process.argv.slice(2);
const sym = {};
for (const l of fs.readFileSync(path.join(__dirname, '../build/vec/brucelee.sym'), 'latin1').split('\n')) {
  const m = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const m = E.mk(ROM);
if (process.env.NEG) m.wr(sym.optab + 7, 0);   // негативный контроль: атрибут 07 (белые чернила) — всё чёрное
let state = 'title', room = 0, bad = 0, checked = 0;
const TOUR = +(process.env.TOUR || 0);          // TOUR=кадров: после проверки фона — игра со случайным вводом и сверкой экрана
const compose = require('./veccompose').make(m, sym);
let seed = 5; const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
let tourLeft = 0, tourPass = 0; const tourBad = {};
const pix = (x, y) => { const a = ((x >> 3) << 8) | (255 - y), b = 7 - (x & 7); return ((m.rd(0xA000 + a) >> b) & 1) << 2 | ((m.rd(0xC000 + a) >> b) & 1) << 1 | ((m.rd(0xE000 + a) >> b) & 1); };
function check(n) {
  let diff = 0;
  const gfx = m.rd(0x6000) | m.rd(0x6001) << 8, pg = m.rd(0x6003) << 8;
  for (let r = 2; r < 24; r++) for (let c = 0; c < 32; c++) {
    const t = m.rd(0x6000 + r * 32 + c), at = m.rd(pg + t), ink = at & 7, paper = (at >> 3) & 7;
    for (let k = 0; k < 8; k++) { const row = m.rd(gfx + t * 8 + k);
      for (let b = 0; b < 8; b++) { const want = (row >> (7 - b)) & 1 ? ink : paper, got = pix(c * 8 + b, 32 + r * 8 + k);
        if (want !== got) { if (diff < 3) console.log(`  комната ${n}: клетка ${r},${c} строка ${k} точка ${b}: ждали ${want}, на экране ${got}`); diff++; } } }
  }
  checked++; if (diff) bad++;
  console.log(`комната ${n}: ${diff ? 'расхождений ' + diff : 'совпадает'}`);
  if (DIR) { fs.mkdirSync(DIR, { recursive: true }); VK.shot(m, `${DIR}/room${String(n).padStart(2, '0')}.png`, m.rd(sym.pal_ptr) | m.rd(sym.pal_ptr + 1) << 8); }
}
m.onInstr = (pc) => {
  if (pc !== sym.pass) return;
  if (state === 'title') state = 'go';
  if (state === 'tour') {
    tourPass++;
    if (tourPass % 10 === 0) { const c = compose(); if (c.bad) { const k = tourBad[room] = tourBad[room] || { n: 0, cells: new Set() }; k.n++; for (const [rr, cc] of c.cells) k.cells.add(rr + ',' + cc); if (!k.ex) { const [r0, c0] = c.cells[0];
      if (process.env.DUMP) { const t = m.rd(0x6000 + r0 * 32 + c0), gfx = m.rd(0x6000) | m.rd(0x6001) << 8; const rows = []; for (let k2 = 0; k2 < 8; k2++) rows.push(m.rd(gfx + t * 8 + k2).toString(16).padStart(2, '0') + '/' + [0xA000, 0xC000, 0xE000].map((p) => m.rd(p + (c0 << 8) + 223 - r0 * 8 - k2).toString(16).padStart(2, '0')).join(':')); VK.shot(m, (process.env.DUMPDIR || '/tmp') + `/bad_room${room}.png`, m.rd(sym.pal_ptr) | m.rd(sym.pal_ptr + 1) << 8); console.log('    тайл/экран G:R:B', rows.join(' '), ' фон 5D00', m.rd(0x5D00 + r0 * 32 + c0).toString(16)); } k.ex = JSON.stringify(c.cells[0]) + ' amap ' + m.rd(sym.amap + r0 * 32 + c0).toString(16) + ' тайл ' + m.rd(0x6000 + r0 * 32 + c0).toString(16) + ' кадр ' + m.frames; } } }
    if (m.frames >= tourLeft) {
      if (tourBad[room]) console.log(`  комната ${room}, игра: сверок с расхождениями ${tourBad[room].n}, клетки ${[...tourBad[room].cells].slice(0, 12).join(" ")}; пример ${tourBad[room].ex}`);
      room++; state = room < 20 ? 'go' : 'done';
    }
  }
  if (state === 'loaded') { check(room); if (TOUR) { state = 'tour'; tourLeft = m.frames + TOUR; tourPass = 0; } else { room++; state = room < 20 ? 'go' : 'done'; } }
  if (state === 'go') { m.wr(sym.zv_FE0E, room); m.wr(sym.zv_FE04, 1); m.wr(sym.zv_FED0, 0x30); m.wr(sym.zv_FED1, 0x39); m.cpu.pc = sym.next_player; state = 'loaded'; }
};
const plan = VK.parse('160:space+ 200:space-');
const keys = ['left', 'right', 'up', 'down', 'space'];
for (let f = 0; f < 5000 + 20 * TOUR * 3 && state !== 'done'; f++) {
  if (state === 'tour' && f % 10 === 0) for (const k of keys) VK.apply(m, [[k, rnd() < 0.3]]);
  if (state !== 'tour' && state !== 'title') for (const k of keys) VK.apply(m, [[k, false]]);
  VK.apply(m, plan[f]);
  m.frame();
}
console.log(`комнат проверено ${checked}, с расхождениями ${bad}`);
process.exit(bad || checked < 20 ? 1 : 0);
