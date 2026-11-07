// Темп игры: Вектор (build/vec/brucelee.bin) против ZX на одном плане build/randplan.txt. node tools/vectempo.js [кадров]
'use strict';
const fs = require('fs'), path = require('path');
const R = path.join(__dirname, '..');
const E = require(R + '/tools/vec_emu'), VK = require(R + '/tools/vecshot_keys'), ZX48 = require(R + '/tools/zx48.js');
const GAME = +(process.argv[2] || 3000);
const raw = fs.readFileSync(R + '/build/randplan.txt', 'utf8').trim();
const ev = VK.parse(raw.split(/\s+/).filter((t) => +t.split(':')[0] >= 420).join(' '));
const ZXK = { left: 'O', right: 'P', up: 'Q', down: 'A', space: 'Z', vk: 'ENTER' };
function stats(name, passFr, roomFr, frames) {
  const d = []; for (let i = 1; i < passFr.length; i++) d.push(passFr[i] - passFr[i - 1]);
  const h = {}; for (const x of d) { const k = x >= 4 ? '4+' : x; h[k] = (h[k] || 0) + 1; }
  const rooms = roomFr.map((f) => { const i = passFr.findIndex((p) => p > f); return i > 0 ? passFr[i] - passFr[i - 1] : 0; });
  const big = d.filter((x) => x > 4).length;
  console.log(`${name}: шагов ${passFr.length} за ${frames} кадров = ${(passFr.length * 50 / frames).toFixed(1)} шагов/с`);
  console.log(`  длина шага (кадров): ` + Object.keys(h).sort().map((k) => `${k}: ${(100 * h[k] / d.length).toFixed(1)}%`).join(', ') + ` (из них >4 кадров — звук/смена комнаты: ${big})`);
  const r = rooms.filter(Boolean); console.log(`  смен комнаты ${r.length}, шаг со сменой: ${r.join(' ')} кадров` + (r.length ? `, в среднем ${(r.reduce((a, b) => a + b) / r.length).toFixed(1)}` : ''));
}
// --- Вектор
{
  const sym = {};
  for (const l of fs.readFileSync(R + '/build/vec/brucelee.sym', 'latin1').split('\n')) { const m = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]] = parseInt(m[2], 16); }
  const m = E.mk(R + '/build/vec/brucelee.bin'), menu = VK.parse('160:space+ 200:space-');
  const passFr = [], roomFr = []; let g0 = -1, f = 0;
  m.onInstr = (pc) => { if (pc === sym.pass && g0 >= 0) passFr.push(f); else if (pc === sym.room_load && g0 >= 0) roomFr.push(f); if (pc === sym.pass && g0 < 0) g0 = f; };
  for (f = 0; ; f++) {
    if (g0 < 0) VK.apply(m, menu[f]); else { if (f - g0 >= GAME) break; VK.apply(m, ev[420 + f - g0]); }
    m.frame(); if (f > 3000 && g0 < 0) throw 'вектор: игра не началась';
  }
  stats('Вектор', passFr, roomFr, GAME);
}
// --- ZX
{
  const zx = new ZX48();
  zx.mem.set(fs.readFileSync(R + '/build/zx_tap.bin').subarray(0x4000), 0x4000);
  const st = JSON.parse(fs.readFileSync(R + '/build/zx_tap.json'));
  const s = zx.cpu.getState(); Object.assign(s, { pc: st.pc, sp: st.sp, i: st.i, imode: st.im }); zx.cpu.setState(s);
  const held = new Set(); const passFr = [], roomFr = []; let g0 = -1, lastPc = -1;
  for (let f = 0; ; f++) {
    if (g0 < 0) { if (f === 300 || f === 420) zx.keysOnly(['ENTER']); if (f === 310 || f === 430) zx.keysOnly([]); }
    else { if (f - g0 >= GAME) break; for (const [k, d] of ev[420 + f - g0] || []) d ? held.add(ZXK[k]) : held.delete(ZXK[k]); if (ev[420 + f - g0]) zx.keysOnly([...held]); }
    const end = zx.frames + 1;
    while (zx.frames < end) { const p = zx.pc;
      if (p === 0xC7A4 && lastPc !== 0xC7A4) { if (g0 < 0) g0 = f; else passFr.push(f); }
      if (p === 0xC16E && lastPc !== 0xC16E && g0 >= 0) roomFr.push(f);
      lastPc = p; zx.step(); }
    if (f > 3000 && g0 < 0) throw 'zx: игра не началась';
  }
  stats('ZX', passFr, roomFr, GAME);
}
