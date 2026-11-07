#!/usr/bin/env node
// Вызов подпрограммы образа в начале прохода (после старта игры) и снимки: проверка редких событий вывода.
//   node tools/vecevent.js build/vec/brucelee.bin <метка> <кадров после> <снимок.png> [комната]
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const [ROM, LABEL, AFTER, OUT, ROOM] = process.argv.slice(2);
const sym = {};
for (const l of fs.readFileSync(path.join(__dirname, '../build/vec/brucelee.sym'), 'latin1').split('\n')) {
  const m = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16);
}
const m = E.mk(ROM);
let state = ROOM !== undefined ? 'room' : 'call', at = -1, passes = 0;
m.onInstr = (pc) => {
  if (pc !== sym.pass) return;
  passes++;
  if (state === 'room' && passes > 5) { m.wr(sym.zv_FE0E, +ROOM); m.cpu.pc = sym.next_player; state = 'wait'; return; }
  if (state === 'wait') { state = 'call0'; return; }
  if ((state === 'call' || state === 'call0') && passes > 30) {        // CALL метка, возврат на pass
    const sp = (m.cpu.sp - 2) & 0xffff; m.wr(sp, sym.pass & 255); m.wr(sp + 1, sym.pass >> 8); m.cpu.sp = sp;
    m.cpu.pc = sym[LABEL]; state = 'done'; at = m.frames;
  }
};
const plan = VK.parse('160:space+ 200:space-');
for (let f = 0; f < 3000; f++) { VK.apply(m, plan[f]); m.frame(); if (at >= 0 && m.frames >= at + +AFTER) break; }
VK.shot(m, OUT, m.rd(sym.pal_ptr) | m.rd(sym.pal_ptr + 1) << 8);
console.log(`${LABEL}: вызвано на кадре ${at}, снимок на ${m.frames}, PC ${m.cpu.pc.toString(16)}`);
