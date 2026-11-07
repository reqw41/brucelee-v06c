#!/usr/bin/env node
// Стенд «1 или 2 игрока» (владелец 07.11): старт с титула клавишей 1 / огнём — один игрок, 2 — двое (Ямо — второй
// игрок, ZX FE08 = 1, его ввод — Kempston FE0A = 2 от джойстика «П» А; Брюс — клавиатура и «П» Б, 07.11). Джойстики «П» — как ядро MiSTer: порт 6 читает
// джойстик, выбранный битами 6:5 порта 5 (00 — оба, 01 — А, 10 — Б).
// Проверки: двое — «П» А только в ввод Ямо (FE12), стрелки и «П» Б — только Брюсу (FE11), цифры клавиатуры Ямо не
// управляют; один — «П» Б тоже ведёт Брюса, второго ввода нет.   node tools/vec2p.js [образ]   NEG=1 — без go_2p
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const ROM = process.argv[2] || path.join(__dirname, '../build/vec/brucelee.bin');
const sym = {}; for (const l of fs.readFileSync(ROM.replace(/\.bin$/, '.sym'), 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const JR = 0x01, JL = 0x02, JF = 0x40;
function probe(startKey, act) {
  const m = E.mk(ROM); let sel = 0; const J = { A: 0xFF, B: 0xFF };
  if (process.env.NEG) m.wr(sym.go_2p, 0xC9);
  const o = m.io.output.bind(m.io); m.io.output = (p, v) => { if ((p & 255) === 5) sel = (v >> 5) & 3; return o(p, v); };
  const i = m.io.input.bind(m.io); m.io.input = (p) => { p &= 255; if (p === 6) return sel === 0 ? J.A & J.B : sel === 1 ? J.A : sel === 2 ? J.B : 0xFF; if (p === 0x0E) return 0xFF; return i(p); };
  const plan = VK.parse(`160:${startKey}+ 200:${startKey}-`); const p1 = new Set(), p2 = new Set();
  for (let f = 0; f < 600; f++) { if (f === 400) act(J, m); VK.apply(m, plan[f]); m.frame(); if (f > 420) { p1.add(m.rd(sym.zv_FE11)); p2.add(m.rd(sym.zv_FE12)); } }
  return { two: m.rd(sym.zv_FE08) === 1 && m.rd(sym.zv_FE0A) === 2, p1: [...p1], p2: [...p2] };
}
const cases = [
  ['двое: «П» А влево -> Ямо', '2', (J) => { J.A = 0xFF & ~JL; }, (r) => r.two && r.p2.includes(2) && r.p1.every((v) => v === 0)],
  ['двое: «П» А огонь -> Ямо', '2', (J) => { J.A = 0xFF & ~JF; }, (r) => r.two && r.p2.includes(0x10) && r.p1.every((v) => v === 0)],
  ['двое: «П» Б вправо -> Брюс', '2', (J) => { J.B = 0xFF & ~JR; }, (r) => r.two && r.p1.includes(1) && r.p2.every((v) => v === 0)],
  ['двое: стрелка влево -> Брюс', '2', (J, m) => VK.apply(m, [['left', true]]), (r) => r.two && r.p1.includes(2) && r.p2.every((v) => v === 0)],
  ['двое: цифра 3 — Ямо не ходит', '2', (J, m) => VK.apply(m, [['3', true]]), (r) => r.two && r.p2.every((v) => v === 0)],
  ['один (1): «П» Б вправо -> Брюс', '1', (J) => { J.B = 0xFF & ~JR; }, (r) => !r.two && r.p1.includes(1)],
  ['один (пробел): «П» А влево -> Брюс', 'space', (J) => { J.A = 0xFF & ~JL; }, (r) => !r.two && r.p1.includes(2)],
];
let bad = 0;
for (const [name, key, act, ok] of cases) { const r = probe(key, act); const g = ok(r); if (!g) bad++; console.log(`  ${g ? 'верно' : 'НЕВЕРНО'}: ${name} (FE11 ${r.p1.map((x) => x.toString(16))}, FE12 ${r.p2.map((x) => x.toString(16))})`); }
console.log(`1 / 2 игрока: проверок ${cases.length}, неверно ${bad}`);
process.exit(bad ? 1 : 0);
