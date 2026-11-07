#!/usr/bin/env node
// Стенд победы (владелец 07.11): комната 19 (её обработчик — level_complete), Брюс на месте входа из 18 (1, 12h).
// Мелодия титула один раз (plat_win_msg), пока играет — Брюс прыгает на месте (plat_win_tick: высота меняется, X тот
// же), после неё — CONGRATULATIONS (big_msg) на плашке, экран стоит; клавиша — новый круг (restart_level). Пока играет —
// присед перед прыжком — подготовка Ch (кадр CPC 4), стойки боком (1) нет; звук перед финалом выключен — мелодия его включает;
// сокровища мерцают (номер 3 палитры меняется) и у Брюса лицо (face_tab: байты K кадров не как в образе), после — как в образе.
//   node tools/vecwin.js [образ]   NEG=1 — без приседа (12h), NEG=2 — мелодия не включает звук
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const ROOT = path.join(__dirname, '..');
const ROM = process.argv[2] || path.join(ROOT, 'build/vec/brucelee.bin');
const sym = {}; for (const l of fs.readFileSync(ROM.replace(/\.bin$/, '.sym'), 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const m = E.mk(ROM), BIN = fs.readFileSync(ROM);
const ftab = [];                        // face_tab: адрес, длина, XOR; DW 1, адрес — продолжение; DW 0 — конец
for (let a = sym.face_tab; ;) { const p = BIN[a] | BIN[a + 1] << 8; if (!p) break; if (p === 1) { a = BIN[a + 2] | BIN[a + 3] << 8; continue; }
  const n = BIN[a + 2]; for (let k = 0; k < n; k++) if (BIN[a + 3 + k]) ftab.push(p + k); a += 3 + n; }
const faceOn = () => !ftab.every((a) => m.rd(a) === BIN[a]);
let faceMid = null, faceEnd = null; const shim = new Set();
if (process.env.NEG === '1') m.wr(sym.plat_win_msg + 19, 0x12);   // подстановка 12h (вытянутый кадр) вместо Ch — без приседа
if (process.env.NEG === '2') { m.wr(sym.plat_win_msg + 7, sym.snd_play & 255); m.wr(sym.plat_win_msg + 8, sym.snd_play >> 8); }   // звук не включается
let crouch = 0, side = 0, musAfter = -1;
let st = 'title', f0 = -1, msgF = -1, restartF = -1, music = 0, jumps = 0, lastY = -1, up = false, xs = new Set(), still = null;
m.onInstr = (pc) => {
  if (pc === sym.plat_win_msg) { music++; if (f0 < 0) f0 = m.frames; }
  if (pc === sym.big_msg && msgF < 0) msgF = m.frames;
  if (pc === sym.restart_level && msgF >= 0 && restartF < 0) { restartF = m.frames; musAfter = m.rd(sym.mus_on); }   // новый круг: музыка выкл. (иначе шум эффектов не снимается)
  if (pc !== sym.pass) return;
  if (st === 'title') { st = 'go'; return; }
  if (st === 'go') { m.wr(sym.zv_FE0E, 19); m.wr(sym.zv_FE04, 1); m.wr(sym.zv_FED0, 0x30); m.wr(sym.zv_FED1, 0x39);
    m.wr(sym.zc_CCAB, 1); m.wr(sym.zc_CCAC, 0x12); m.wr(sym.zv_FE9A, 0); m.cpu.pc = sym.next_player; st = 'run'; return; }
  if (f0 >= 0 && msgF < 0) {
    shim.add(m.rd(sym.pal_room + 3)); const ps = m.rd(sym.zc_CCA7); if (ps === 0x0C) crouch++; if (ps === 1) side++; if (m.frames - f0 > 100 && faceMid === null) faceMid = faceOn();
    const y = m.rd(sym.zc_CCAC) * 8 + m.rd(sym.zc_CCA9); xs.add(m.rd(sym.zc_CCAB));
    if (lastY >= 0 && y < lastY && !up) { up = true; jumps++; } else if (y > lastY) up = false;
    lastY = y;
  }
};
const plan = VK.parse('160:space+ 200:space-');
const scr = () => { const b = []; for (let a = 0xA000; a < 0x10000; a += 7) b.push(m.rd(a)); return b.join(','); };
for (let f = 0; f < 2400 && restartF < 0; f++) {
  if (msgF >= 0 && m.frames === msgF + 60) { still = scr(); faceEnd = faceOn(); }
  if (msgF >= 0 && m.frames === msgF + 120) { if (still !== scr()) still = 'мигает'; VK.shot(m, path.join(ROOT, 'build/vecwin_msg.png'), m.rd(sym.pal_ptr) | m.rd(sym.pal_ptr + 1) << 8); }
  if (msgF >= 0 && m.frames >= msgF + 150 && m.frames < msgF + 160) VK.apply(m, [['space', true]]);
  if (msgF >= 0 && m.frames >= msgF + 160) VK.apply(m, [['space', false]]);
  VK.apply(m, plan[f]); m.frame();
}
const dur = msgF - f0;
const ok = faceMid === true && faceEnd === false && shim.size >= 3 && music === 1 && dur >= 900 && dur <= 960 && jumps >= 15 && xs.size === 1 && still && still !== 'мигает' && restartF > 0 && crouch > 100 && !side && musAfter === 0;
console.log(`победа: мелодия ${music} раз, надпись через ${dur} кадров (мелодия титула 936), прыжков ${jumps} (проходов в приседе Ch ${crouch}, в стойке боком ${side}), X ${[...xs].join(',')}, ` +
  `лицо ${faceMid ? 'есть' : 'нет'}, после ${faceEnd ? 'осталось' : 'снято'}, мерцание ${shim.size} цв., надпись ${still === 'мигает' ? 'мигает' : still ? 'стоит' : 'нет'}, новый круг ${restartF > 0 ? 'после клавиши' : 'нет'} (музыка ${musAfter ? 'вкл.' : 'выкл.'}) — ${ok ? 'верно' : 'НЕВЕРНО'}`);
process.exit(ok ? 0 : 1);
