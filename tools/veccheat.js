#!/usr/bin/env node
// Стенд скрытого старта (владелец 08.11): на титуле Ф1+Ф3 вместе — один игрок, жизни не убывают (bruce_died: DEC H ->
// NOP, src/vec/cheat.asm); обычный старт (пробел) — убывают; после чита обычный старт снова обычный.
//   node tools/veccheat.js [образ]   NEG=1 — чит не ставит NOP
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const ROM = process.argv[2] || path.join(__dirname, '../build/vec/brucelee.bin');
const sym = {}; for (const l of fs.readFileSync(ROM.replace(/\.bin$/, '.sym'), 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
function run(keys) {           // старт клавишами keys; после старта 3 раза «погибнуть» (вызов bruce_died с прохода)
  const m = E.mk(ROM); if (process.env.NEG) for (let i = 9; i < 12; i++) m.wr(sym.tw_cheat + i, 0);   // запись NOP в логику — убрана
  let n = 0, deaths = 0, lives = [];
  m.onInstr = (pc) => {
    if (pc !== sym.pass || m.rd(sym.zv_FE03) === undefined) return;
    if (m.rd(sym.zv_FE0E + 0) === 0 && n === 0 && m.frames < 400) return;
    n++;
    if (n % 150 === 0 && deaths < 3) { deaths++; lives.push(String.fromCharCode(m.rd(sym.zv_FED0), m.rd(sym.zv_FED1)));
      m.cpu.sp -= 2; m.wr(m.cpu.sp, sym.pass & 255); m.wr(m.cpu.sp + 1, sym.pass >> 8); m.cpu.pc = sym.bruce_died; }
  };
  const p = VK.parse(keys);
  for (let f = 0; f < 3000; f++) { VK.apply(m, p[f]); m.frame(); }
  lives.push(String.fromCharCode(m.rd(sym.zv_FED0), m.rd(sym.zv_FED1)));
  return { lives, op: m.rd(sym['bruce_died.live']), two: m.rd(sym.zv_FE08) };
}
let bad = 0;
const ck = (name, ok, info) => { if (!ok) bad++; console.log(`  ${ok ? 'верно' : 'НЕВЕРНО'}: ${name} (${info})`); };
let r = run('300:f1+ 300:f3+ 330:f1- 330:f3-');
ck('Ф1+Ф3 — жизни не убывают', r.lives.every((x) => x === r.lives[0]) && r.op === 0 && r.two === 0, `жизни ${r.lives.join(' ')}, байт ${r.op.toString(16)}`);
r = run('300:space+ 330:space-');
ck('пробел — жизни убывают', r.lives[0] > r.lives[r.lives.length - 1] && r.op === 0x25, `жизни ${r.lives.join(' ')}, байт ${r.op.toString(16)}`);
console.log(`чит: проверок 2, неверно ${bad}`);
process.exit(bad ? 1 : 0);
