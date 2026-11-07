#!/usr/bin/env node
// Стенд колдуна комнаты 18 (06.11, tools/mkroom18tiles.py -> build/room18_tiles.json): комната 18 телепортом.
// 1) Сразу после загрузки область колдуна (ряды 0..10, столбцы 9..22) на экране — точка в точку по плану: номера карты
//    плана, узор и цвет — заёмные из плана, остальные из образа (запечённые там).
// 2) Брюс ходит случайно TOUR кадров, шар колдуна летит: после каждого прохода экран = композиция карты, тайлов и
//    персонажей (veccompose), а карта области колдуна — номера плана либо 0 (шар; фон за ним — из копии 5D00).
// 3) Звук (07.11): «пшик» на каждый выстрел (FE3C -> 1, стрельба как у CPC), взрыв при подборе оружия (r_D98D), во вспышке выстрелов нет;
//    колдун исчезает по точкам (wiz_fade): за время шума (фонарик, взрыв, рокот; ±12 кадров, не меньше 100 кадров; шум в простое — не меньше 40 вызовов на кадр взрыва, ~55% полного) его клетки (wiz_mask) — фон на экране и в amap, новых выстрелов нет.
// 4) Стрельба как у CPC (wizcpc.asm): 5 направлений по столбцу Брюса.
// Снимки: build/room18_static.png, build/room18_ball.png (шар в полёте).
//   node tools/vecroom18.js [образ]   NEG=1 — заём не делается (r18_swap -> RET), NEG=2 — порча узора на экране, NEG=3 — без звука выстрела, NEG=4 — колдун не исчезает, NEG=5 — шар не в тех плоскостях, NEG=6 — стреляет после исчезновения; фонарик (14h) — номер 3, мигает 4 цветами
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const ROOT = path.join(__dirname, '..');
const ROM = process.argv[2] || path.join(ROOT, 'build/vec/brucelee.bin');
const sym = {}; for (const l of fs.readFileSync(ROM.replace(/\.bin$/, '.sym'), 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const BIN = fs.readFileSync(ROM), PLAN = JSON.parse(fs.readFileSync(path.join(ROOT, 'build/room18_tiles.json'), 'utf8'));
const B18 = {}; for (const b of PLAN.borrow) B18[b.t] = b;
const TOUR = +(process.env.TOUR || 3000);
const m = E.mk(ROM);
if (process.env.NEG === '1') m.wr(sym.r18_swap, 0xC9);
if (process.env.NEG === '3') m.wr(sym.wiz_tick, 0xC9);   // без звука выстрела
if (process.env.NEG === '4') m.wr(sym.wiz_step, 0xC9);   // колдун не исчезает
if (process.env.NEG === '6') { m.wr(sym.wiz_nw0, 0xC3); m.wr(sym.wiz_nw0 + 1, sym.wiz_new & 255); m.wr(sym.wiz_nw0 + 2, sym.wiz_new >> 8); }   // стреляет и после исчезновения
if (process.env.NEG === '5') m.wr(sym['wizball3.x'] + 6, 0);   // шар — в одну плоскость дважды (XOR 60 -> XOR 0)
const compose = require('./veccompose').make(m, sym);
const pix = (x, y) => { const a = ((x >> 3) << 8) | (255 - y), b = 7 - (x & 7); return ((m.rd(0xA000 + a) >> b) & 1) << 2 | ((m.rd(0xC000 + a) >> b) & 1) << 1 | ((m.rd(0xE000 + a) >> b) & 1); };
const shot = (f) => VK.shot(m, path.join(ROOT, 'build', f), m.rd(sym.pal_ptr) | m.rd(sym.pal_ptr + 1) << 8);
let seed = 11; const rnd = () => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
const lampC = new Set(); let lampAttr = -1;
let boomF = -1, boomEnd = -1, fadeEnd = -1, nzIdle = 0;
let fadeLeft = 0, fadeAmap = 0, fadeCells = 0, shots = 0, launches = 0, lastFE3C = -1, boom = 0, wpn = -1, falseShot = 0;
let state = 'title', end = 0, stat = 0, passes = 0, badComp = 0, badMap = 0, ball = 0, ballShot = false; const ex = [];
function staticCheck() {
  if (process.env.NEG === '2') m.wr(0xA000 + (12 << 8) + 255 - 48 - 3 * 8 - 2, m.rd(0xA000 + (12 << 8) + 255 - 48 - 3 * 8 - 2) ^ 0x18);
  for (let r = 0; r < 11; r++) for (let c = 9; c < 23; c++) {
    const t = PLAN.map[r * 32 + c], b = B18[t];
    const at = b ? b.attr : BIN[0x6300 + t], ink = at & 7, paper = (at >> 3) & 7;
    for (let k = 0; k < 8; k++) { const row = b ? b.pat[k] : BIN[0x9800 + t * 8 + k];
      for (let x = 0; x < 8; x++) { const want = (row >> (7 - x)) & 1 ? ink : paper, got = pix(c * 8 + x, 48 + r * 8 + k);
        if (want !== got) { stat++; if (ex.length < 3) ex.push(`клетка ${r},${c} строка ${k} точка ${x}: ждали ${want}, на экране ${got}`); } } }
  }
  shot('room18_static.png');
}
m.onInstr = (pc) => {
  if (pc === sym.snd_sfx) { const hl = m.cpu.regs[4] << 8 | m.cpu.regs[5]; if (hl === sym.sfx_shot) { if (wpn < 0) shots++; else falseShot++; } if (hl === sym.sfx_boom) { boom++; boomF = m.frames; } }
  if (pc === sym['snd_idle.l'] && boomF >= 0 && (boomEnd < 0 || m.frames <= boomEnd)) nzIdle++;
  if (pc === sym.wiz_step && m.rd(sym.wf_k) === 15 && fadeEnd < 0) fadeEnd = m.frames;
  if (boomF >= 0) { const q = m.rd(sym.vc2 + 2) | m.rd(sym.vc2 + 3) << 8; if (q > sym.sfx_boom && q <= sym.sfx_rmb + 25) boomEnd = m.frames; }
  if (pc !== sym.pass) return;
  if (state === 'tour' && wpn < 0) { lampC.add(m.rd(sym.pal_room + 3)); lampAttr = m.rd(0x6300 + 0x14); }
  if (state === 'tour') { const v = m.rd(sym.zv_FE3C); if (v === 1 && lastFE3C !== 1 && wpn < 0) launches++; lastFE3C = v; }
  if (state === 'title') { state = 'go'; return; }
  if (state === 'go') { m.wr(sym.zv_FE0E, 18); m.wr(sym.zv_FE04, 1); m.wr(sym.zv_FED0, 0x30); m.wr(sym.zv_FED1, 0x39); m.cpu.pc = sym.next_player; state = 'loaded'; return; }
  if (state === 'loaded') { staticCheck(); state = 'tour'; end = m.frames + TOUR; return; }
  if (state === 'tour') {
    if (m.rd(sym.zv_FE03) !== 18) { state = 'done'; return; }    // вышли из комнаты — конец обхода
    if (wpn >= 0) {                    // после подбора — колдун исчезает по точкам (wiz_fade); через 300 кадров его клеток нет
      if (m.frames > wpn + 300) { state = 'done'; const MK = []; for (let r = 0; r < 11; r++) { const lo = m.rd(sym.wiz_mask + 2 * r), hi = m.rd(sym.wiz_mask + 2 * r + 1); for (let c = 0; c < 14; c++) if (((c < 8 ? lo >> c : hi >> (c - 8)) & 1)) MK.push([r, c]); }
        for (const [r, c] of MK) { if (m.rd(sym.amap + (r + 2) * 32 + 9 + c) !== 0) fadeAmap++;
          if (m.rd(0x6040 + r * 32 + 9 + c) === 0) continue;   // шар
          let n = 0; for (let k = 0; k < 8; k++) for (let x = 0; x < 8; x++) if (pix((9 + c) * 8 + x, 48 + r * 8 + k) !== 0) n++; fadeLeft += n; if ((n || m.rd(sym.amap + (r + 2) * 32 + 9 + c)) && process.env.DBG) console.log("  клетка", r, c, "точек", n, "6040", m.rd(0x6040 + r * 32 + 9 + c).toString(16), "5D00", m.rd(0x5D40 + r * 32 + 9 + c).toString(16), "amap", m.rd(sym.amap + (r + 2) * 32 + 9 + c).toString(16)); }
        fadeCells = MK.length; }
      return; }
    passes++;
    const c = compose(); if (c.bad) { badComp++; if (ex.length < 3) ex.push(`проход ${passes}: экран не как композиция, клетка ${c.cells[0]}`); }
    let fly = false;
    for (let r = 0; r < 11; r++) for (let cc = 9; cc < 23; cc++) { const v = m.rd(0x6040 + r * 32 + cc), w = PLAN.map[r * 32 + cc];
      if (v === 0 && w !== 0) fly = true; else if (v !== w) { badMap++; if (ex.length < 3) ex.push(`проход ${passes}: карта ${r},${cc} = ${v.toString(16)}, по плану ${w.toString(16)}`); } }
    if (fly) { ball++; if (!ballShot && ball > 6) { shot('room18_ball.png'); ballShot = true; } }
    if (m.frames >= end && wpn < 0) {     // подбор оружия (r_D98D) — взрыв колдуна, во вспышке выстрелов нет
      wpn = m.frames; m.wr(sym.vc2, sym.sfx_lamp & 255); m.wr(sym.vc2 + 1, sym.sfx_lamp >> 8); m.wr(sym.vc1, sym.sfx_lamp2 & 255); m.wr(sym.vc1 + 1, sym.sfx_lamp2 >> 8); m.cpu.sp -= 2;   // звук фонарика (objects -> plat_sound)
       m.wr(m.cpu.sp, sym.pass & 255); m.wr(m.cpu.sp + 1, sym.pass >> 8); m.cpu.pc = sym.r_D98D; return; }
    if (wpn >= 0 && m.frames > wpn + 300) state = 'done';
  }
};
const plan = VK.parse('160:space+ 200:space-'), keys = ['left', 'right', 'up', 'down', 'space'];
for (let f = 0; f < 1000 + TOUR && state !== 'done'; f++) {
  if (state === 'tour' && f % 12 === 0) for (const k of keys) VK.apply(m, [[k, k === 'right' ? rnd() < 0.15 : rnd() < 0.3]]);
  VK.apply(m, plan[f]); m.frame();
}
// 4) стрельба как у CPC (wizcpc.asm): Брюс в столбцах 3, 8, 16, 22, 28 — огонь падает в 3, 10, 16, 22, 29 (5 направлений)
const dirs = (() => { const q = E.mk(ROM); const xs = [3, 8, 16, 22, 28]; let n = 0, st = 'title', last = -1, cur = null; const land = [];
  q.onInstr = (pc) => { if (pc === sym.wiz_new) { q.wr(sym.zc_CCAB, xs[n % 5]); n++; }
    if (pc !== sym.pass) return; if (st === 'title') { st = 'go'; return; }
    if (st === 'go') { q.wr(sym.zv_FE0E, 18); q.wr(sym.zv_FE04, 1); q.wr(sym.zv_FED0, 0x39); q.wr(sym.zv_FED1, 0x39); q.cpu.pc = sym.next_player; st = 'run'; return; }
    const v = q.rd(sym.zv_FE3C); if (v === 1 && last !== 1) { cur = []; land.push(cur); } last = v; if (cur) cur.push(q.rd(sym.zv_FE17)); };
  const p = VK.parse('160:space+ 200:space-'); for (let f = 0; f < 600; f++) { VK.apply(q, p[f]); q.frame(); }
  return land.slice(0, 5).map((a) => a[a.length - 1]).join(','); })();
if (dirs !== '3,10,16,22,29') { ex.push(`стрельба: огонь падает в ${dirs}, ждали 3,10,16,22,29`); }
for (const e of ex) console.log('  ' + e);
const shotsBefore = shots; const okSnd = launches > 0 && launches === shotsBefore && boom === 1 && falseShot === 0 && fadeCells > 50 && !fadeLeft && !fadeAmap && lampC.size >= 4 && lampAttr === 0x43 && Math.abs(fadeEnd - boomEnd) <= 12 && boomF - wpn >= 7 && fadeEnd - wpn >= 100 && nzIdle >= 40 * (boomEnd - boomF);
const ok = dirs === '3,10,16,22,29' && state === 'done' && !stat && !badComp && !badMap && ball > 0 && passes > 100 && okSnd;
console.log(`  фонарик: цвет 14h ${lampAttr.toString(16)}, номер 3 палитры — ${[...lampC].map((c) => c.toString(16)).join(' ')}`);
console.log(`комната 18: колдун на экране — расхождений ${stat} точек; проходов ${passes}, экран не как композиция ${badComp}, карта не по плану ${badMap}, шар в полёте ${ball} проходов; звук: выстрелов ${launches}, «пшиков» ${shotsBefore}, взрыв ${boom}, после подбора ${falseShot}; исчез за ${fadeEnd - wpn} кадров (взрыв с ${boomF - wpn}-го после фонарика, шум до ${boomEnd - wpn}, шум в простое ${nzIdle}): клеток ${fadeCells}, осталось точек ${fadeLeft}, amap не фон ${fadeAmap}; огонь падает в ${dirs}`);
process.exit(ok ? 0 : 1);
