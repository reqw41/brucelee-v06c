#!/usr/bin/env node
// Стенд паузы (владелец 07.11): ВК — пауза (ZX ENTER), в паузе игра стоит; ВК — дальше; АР2 в паузе — выход в титул
// (title_restart); АР2 без паузы ничего не делает.   node tools/vecpause.js [образ]   NEG=1 — без выхода по АР2
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const ROM = process.argv[2] || path.join(__dirname, '../build/vec/brucelee.bin');
const sym = {}; for (const l of fs.readFileSync(ROM.replace(/\.bin$/, '.sym'), 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
function run(plan, frames) {
  const m = E.mk(ROM); let title = -1, passes = 0; const pp = [];
  if (process.env.NEG) { const a = sym['plat_menu_keys.w'] + 2 + 3 + 2; m.wr(a, 0); m.wr(a + 1, 0); m.wr(a + 2, 0); }   // JP NZ,title_restart -> NOP
  m.onInstr = (pc) => { if (pc === sym.title_restart && title < 0 && m.frames > 250) title = m.frames; if (pc === sym.pass) passes++; };
  const p = VK.parse('160:space+ 200:space- ' + plan);
  for (let f = 0; f < frames; f++) { VK.apply(m, p[f]); m.frame(); if (f % 50 === 0) pp.push(passes); }
  return { title, pp };
}
const d = (pp, a, b) => pp[b / 50] - pp[a / 50];
let bad = 0;
const ck = (name, ok, info) => { if (!ok) bad++; console.log(`  ${ok ? 'верно' : 'НЕВЕРНО'}: ${name} (${info})`); };
// ВК на 400 — пауза; 600..700 игра стоит; ВК на 800 — дальше; 900..1000 идёт
let r = run('400:vk+ 410:vk- 800:vk+ 810:vk-', 1100);
ck('ВК — пауза, игра стоит', d(r.pp, 600, 700) === 0, `проходов за 100 кадров ${d(r.pp, 600, 700)}`);
ck('ВК — дальше', d(r.pp, 900, 1000) > 40 && r.title < 0, `проходов ${d(r.pp, 900, 1000)}`);
r = run('400:vk+ 410:vk- 600:ar2+ 610:ar2-', 900);
ck('АР2 в паузе — титул', r.title >= 600 && r.title < 640, `title_restart на кадре ${r.title}`);
r = run('400:ar2+ 410:ar2-', 700);
ck('АР2 без паузы — ничего', r.title < 0 && d(r.pp, 450, 650) > 80, `title_restart ${r.title}, проходов ${d(r.pp, 450, 650)}`);
console.log(`пауза: проверок 4, неверно ${bad}`);
process.exit(bad ? 1 : 0);
