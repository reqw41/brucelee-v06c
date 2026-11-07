#!/usr/bin/env node
// Сверка логики i8080 (build/l80/logic.bin) с эталоном ZX по шагам (docs/PLAN.md, этап 2; образец —
// jetpac-v06c/tools/lock80.js). JS-модель совпадает с эталоном, поэтому i8080 сверяется прямо с эталоном.
//
// Память i8080 — раскладка Вектора: 5B00..9FFF как на ZX, острова C000..DFFF и FB00..FEFF перенесены
// (карта из build/l80/logic.sym: метки Z_xxxx). На каждом шаге i8080 выполняет `pass`; чтения адресов
// прерывания подаются из очереди шага (rd), порты ZX — IN E0 (in), ld a,r — IN E1 (r), звук — OUT E2,
// щелчки — OUT E3; OUT E4 — «не моделируется» (шаг пропускается). Сравниваются все адреса ZX из d эталона
// и все записанные i8080 (по обратной карте), кроме служебных ячеек вывода и бипера. После шага память
// исправляется по эталону.
//   node tools/run80.js build/golden/<имя>.json.gz [...] [--max N] [--from шаг] [--prof] [--ship]
// --ship — боевой образ build/vec/brucelee.bin: вывод Вектора работает по-настоящему (экран, полоса, шапка), на
// ввод, случайность, звук, щелчки и ожидание кадра — перехваты по меткам с теми же очередями эталона; записи вне
// карты ZX разрешены только в экран (A000..), полосу 9700.. и стек 9640..
'use strict';
const fs = require('fs'), path = require('path'), zlib = require('zlib'), vm = require('vm');
const { where, ROOT } = require('./sym');
const sound = require('../src/model/sound');
const { Mem } = require('../src/model/core');

const SHIP = process.argv.includes('--ship');
const SYM80 = {};
for (const l of fs.readFileSync(path.join(ROOT, SHIP ? 'build/vec/brucelee.sym' : 'build/l80/logic.sym'), 'latin1').split('\n')) {
  const m = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) SYM80[m[1]] = parseInt(m[2], 16);
}
const BIN = fs.readFileSync(path.join(ROOT, SHIP ? 'build/vec/brucelee.bin' : 'build/l80/logic.bin'));
if (process.env.BREAK80) {                     // негативный контроль: BREAK80=метка+смещение:байт
  const m = process.env.BREAK80.match(/^([\w.]+)\+(\d+):(\d+)$/);
  BIN[SYM80[m[1]] + +m[2]] = +m[3];
}
// стрельба колдуна как у CPC (WIZ_CPC, room.asm r_DD0D: JP wiz_cpc) — только в образе; сверка с ZX — без перехода
if (SHIP && SYM80.wiz_cpc !== undefined) {
  const a = SYM80.r_DD0D; if (BIN[a] !== 0xC3) throw new Error('r_DD0D: не JP wiz_cpc'); BIN[a] = BIN[a + 1] = BIN[a + 2] = 0;
}
// победа (VEC_WIN, game.asm level_complete): прыжки под мелодию титула — только в образе; сверка с ZX — без вставки
if (SHIP && SYM80['level_complete.win_hook'] !== undefined) {
  if (BIN[SYM80['level_complete.win_hook']] !== 0xCD || BIN[SYM80['level_complete.win_hook'] + 3] !== 0xD8) throw new Error('win_hook: не CALL / RET C');
  for (let k = 0; k < 4; k++) BIN[SYM80['level_complete.win_hook'] + k] = 0;
}
// боевой образ с ИИ ближнего боя CPC (src/vec/aicpc.asm): для сверки с ZX вернуть ветку ZX — переход ai.near
// на ai.nzx, пауза разворота 0x32, ряд Брюса без допуска (ai.ytol: INC A -> NOP),
// задержки возвращения и появления Ямо — ZX
if (SHIP && SYM80['ai.nzx'] - SYM80['ai.near'] === 3) {
  const a = SYM80['ai.near'], t = SYM80['ai.nzx'];
  if (BIN[a] !== 0xC3 || BIN[SYM80['ai.tdly']] !== 0x3E) throw new Error('ai.near / ai.tdly: не те команды');
  BIN[a + 1] = t & 0xff; BIN[a + 2] = t >> 8; BIN[SYM80['ai.tdly'] + 1] = 0x32;
  if (BIN[SYM80['ai.ytol']] !== 0x3C) throw new Error('ai.ytol: не INC A'); BIN[SYM80['ai.ytol']] = 0;
  // tile_fix (src/vec/tilefix.asm: цвета тайлов как CPC, узор оружия комнаты 18) — только вид: в сверке выключен (RET)
  if (SYM80.tile_fix !== undefined) BIN[SYM80.tile_fix] = 0xC9;
  for (const [n, v] of [['rsp_ninja', 0x32], ['rsp_yamo', 0x32], ['revive.app', 0x4B]]) {
    if (BIN[SYM80[n]] !== 0x3E) throw new Error(n + ': не LD A,n'); BIN[SYM80[n] + 1] = v;
  }
}
const ZXIMG = fs.readFileSync(path.join(ROOT, 'build/zx_tap.bin'));

// карта ZX -> Вектор
const zx2v = new Int32Array(0x10000).fill(-1);
for (let a = 0x5B00; a < 0xA000; a++) zx2v[a] = a;
// потоки тайлов комнат на Векторе — ZX0 на месте RLE (tools/mkvecdata.py): не переносить и не сверять
for (const [lo, hi] of JSON.parse(fs.readFileSync(path.join(ROOT, 'build/roomz_spans.json'), 'utf8'))) for (let a = lo; a < hi; a++) zx2v[a] = -1;
for (const [k, v] of Object.entries(SYM80)) {
  const m = k.match(/^Z_([0-9A-F]{4})$/); if (!m) continue;
  const lo = parseInt(m[1], 16);
  const len = lo === 0xFB00 ? 0x400 : lo === 0xA000 ? 0 : null;
  if (len === 0) continue;
}
// длины островов — по EQU zc_/zv_
for (const [k, v] of Object.entries(SYM80)) {
  const m = k.match(/^z[cv]_([0-9A-F]{4})$/); if (m) zx2v[parseInt(m[1], 16)] = v;
}
// спрайты — блоки кадров (tools/mkvecdata.py: Z_SPRC и дыры комнат; у врагов масок нет)
for (const [zx, base, off] of JSON.parse(fs.readFileSync(path.join(ROOT, 'build/sprmap.json'), 'utf8'))) zx2v[zx] = SYM80[base] + off;
// боевой образ: код вывода в дырах потоков комнат (метки hcodeN..hcodeN_end) — свой, с самоизменением
const HCODE = new Uint8Array(0x10000);
for (let i = 0; SYM80['hcode' + i] !== undefined; i++) for (let a = SYM80['hcode' + i]; a < SYM80['hcode' + i + '_end']; a++) HCODE[a] = 1;
const v2zx = new Int32Array(0x10000).fill(-1);
for (let a = 0; a < 0x10000; a++) if (zx2v[a] >= 0) v2zx[zx2v[a]] = a;
// указатели в островах (слова, которые i8080 держит своими): из исходника gen/zxdata.asm
const ptrZX = new Set();
for (const l of fs.readFileSync(path.join(ROOT, 'src/i8080/gen/zxdata.asm'), 'utf8').split('\n')) {
  const m = l.match(/DW\t\S+\t\t; ([0-9A-F]{4})/); if (m) { const a = parseInt(m[1], 16); ptrZX.add(a); ptrZX.add(a + 1); }
}
// не сверяются: служебные ячейки вывода, бипер ZX
const NOCMP = new Set([0x600B, 0x9339, 0x962A, 0x963E, 0xFE96, 0xFE97]);
for (let a = 0xFEA0; a <= 0xFEAD; a++) NOCMP.add(a);
if (SHIP) for (let a = 0x933A; a < 0x9800; a++) NOCMP.add(a);   // Вектор: шрифт, стек, полоса (звук ZX не нужен)


// --- процессор i8080 (ядро vector06js)
const base = process.env.V06JS || path.join(require('os').homedir(), 'projects/vector06js');
const g = { console: { log() {}, debug() {}, warn() {}, error() {}, info() {} } }; g.window = g;
const ctx = vm.createContext(g);
for (const f of ['i8080-js/i8080_trace.js', 'i8080-js/i8080_disasm.js', 'i8080-js/i8080.js'])
  vm.runInContext(fs.readFileSync(path.join(base, f), 'utf8'), ctx, { filename: f });
const mem = new Uint8Array(0x10000);
let S = null;                                  // состояние шага: очереди и журналы
const written = new Set();
let ownedV = new Set();
const memory = {
  read: (a) => {
    a &= 0xffff;
    if (S && ownedV.has(a)) { const q = S.q.get(a); if (q && q.length) { const v = q.length > 1 ? q.shift() : q[0]; mem[a] = v; return v; } }
    return mem[a];
  },
  write: (a, v) => { a &= 0xffff; written.add(a); mem[a] = v & 0xff; },
};
class Abort extends Error {}
const io = {
  input: (p) => {
    p &= 0xff;
    if (p === 0xE0) { if (!S.inq.length) throw new Error('нет значения порта'); return S.inq.shift()[1]; }
    if (p === 0xE1) { if (!S.rq.length) throw new Error('нет ld a,r'); return S.rq.shift(); }
    return 0xff;
  },
  output: (p, v) => {
    p &= 0xff;
    if (p === 0xE2) {                          // звук: имя и чтения клавиатуры, как у бипера ZX
      const name = ['', 'snd_jingle', 'snd_die', 'snd_key', 'snd_hit'][v];
      const fe9a = mem[zx2v[0xFE9A]];
      const M = new Mem(ZXIMG.slice ? Uint8Array.from(ZXIMG) : ZXIMG); M.inq = S.inq;
      if (name === 'snd_hit') sound.hit(M);
      else if (name === 'snd_jingle') sound.play(M, name, 0x935C, 0, fe9a ? 0xD3 : 0x3E);
      else sound.play(M, name, name === 'snd_die' ? 0x933A : 0x9346, 0, 0xD3);
      S.snd.push(M.snd[0]);
    } else if (p === 0xE3) S.clicks++;
    else if (p === 0xE4) throw new Abort('не моделируется');
  },
  commit: () => {}, interrupt: () => {},
};
const cpu = new ctx.I8080(memory, io);
const PROF = process.argv.includes('--prof');
const prof = new Float64Array(0x10000);
// --ship: перехваты платформы (как plat_test.asm: те же очереди)
const HOOK = new Map();
if (SHIP) {
  const inv = () => { if (!S.inq.length) throw new Error('нет значения порта'); return S.inq.shift()[1]; };
  const setA = (v) => { cpu.regs[7] = v & 0xff; };          // A в ядре vector06js — regs[7]
  HOOK.set(SYM80.plat_keys, () => {
    let v = inv(); let a;
    if (!(v & 1)) { v = inv(); if (!(v & 1)) { setA(1); return; } }
    v = inv(); if (!(v & 1)) { setA(2); return; }
    v = inv(); setA((v & 2) ? 0 : 4);
  });
  HOOK.set(SYM80.plat_rand, () => { if (!S.rq.length) throw new Error('нет ld a,r'); setA(S.rq.shift()); });
  HOOK.set(SYM80.plat_sound, () => io.output(0xE2, cpu.regs[7]));
  HOOK.set(SYM80.plat_click, () => { S.clicks++; });
  for (const n of ['plat_wait', 'plat_halts', 'pal_set_wait', 'plat_weapon', 'plat_win_msg', 'plat_tile']) HOOK.set(SYM80[n], () => {});   // plat_tile: вывод клетки (шар колдуна — wizball)   // plat_win_msg: мелодия и лицо Брюса (07.11)
  for (const n of ['plat_menu_keys', 'plat_game_over']) HOOK.set(SYM80[n], () => { throw new Abort('не моделируется'); });
}
const WAIT_LO = SYM80['pass.w'], WAIT_HI = SYM80['pass.go'];   // ожидание кадра на стенде — не логика
let tWait = 0, stepWait = 0, stepRoom = false, tPlain = 0, nPlain = 0;
const STACK0 = SHIP ? SYM80.STACK - 2 : 0x5afe;
function call(addr) {
  const SENT = 0xfffe;
  mem[STACK0] = SENT & 0xff; mem[STACK0 + 1] = SENT >> 8;
  cpu.sp = STACK0; cpu.pc = addr;
  let t = 0;
  while (cpu.pc !== SENT) {
    const h = HOOK.get(cpu.pc);
    if (h) { h(); cpu.pc = mem[cpu.sp] | mem[cpu.sp + 1] << 8; cpu.sp = (cpu.sp + 2) & 0xffff; t += 40; continue; }
    const pc0 = cpu.pc;
    cpu.instruction(); t += cpu.vcycles;
    if (PROF) prof[pc0] += cpu.vcycles;
    if ((pc0 >= WAIT_LO && pc0 < WAIT_HI) || pc0 === SYM80.plat_wait) { tWait += cpu.vcycles; stepWait += cpu.vcycles; }
    if (pc0 === SYM80.room_load) stepRoom = true;
    if (t > 5e7) throw new Error('i8080: шаг не кончается, pc ' + cpu.pc.toString(16));
  }
  return t;
}

const args = process.argv.slice(2);
let maxShow = 5, from = 0;
const files = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--max') maxShow = +args[++i];
  else if (args[i] === '--from') from = +args[++i];
  else if (args[i] !== '--prof' && args[i] !== '--ship') files.push(args[i]);
}
const sn = (l) => l.map((s) => s[0] + (s[1] === null || s[0] === 'snd_hit' ? '' : `(${s[1]},${s[2]})`)).join(' ');
let tAll = 0, tN = 0, tMax = 0;

function setZX(a, v) { const p = zx2v[a]; if (p >= 0 && !ptrZX.has(a)) mem[p] = v; }
function runOne(file) {
  const gd = JSON.parse(zlib.gunzipSync(fs.readFileSync(file)));
  mem.fill(0); mem.set(BIN.subarray(0, 0xA000));
  const first = Buffer.from(gd.first, 'base64');
  const real = new Uint8Array(0x10000); real.set(first, 0x4000);
  for (let a = 0x4000; a < 0x10000; a++) setZX(a, real[a]);
  const owned = new Set(gd.owned);
  ownedV = new Set([...owned].map((a) => zx2v[a]).filter((v) => v >= 0));
  let bad = 0, runN = 0, skipped = 0, shown = 0;
  for (let t = 0; t < gd.ticks.length; t++) {
    const tk = gd.ticks[t];
    for (const [a, v] of tk.pk || []) { real[a] = v; setZX(a, v); }
    if (t < from || tk.menu) { for (const [a, v] of tk.d) { real[a] = v; setZX(a, v); } skipped++; continue; }
    S = { q: new Map(), inq: tk.in.slice(), rq: tk.r.slice(), snd: [], clicks: 0 };
    for (const [a, v] of tk.rd) { const p = zx2v[a]; let q = S.q.get(p); if (!q) S.q.set(p, q = []); q.push(v); }
    written.clear();
    let err = null, tt = 0;
    stepWait = 0; stepRoom = false;
    try { tt = call(SYM80.pass); } catch (e) { err = e; }
    if (!err && !stepRoom) { tPlain += tt - stepWait; nPlain++; }
    S.done = true;
    for (const [a, v] of tk.d) real[a] = v;
    if (err instanceof Abort) { for (let a = 0x4000; a < 0x10000; a++) setZX(a, real[a]); skipped++; S = null; continue; }
    runN++; tAll += tt; tN++; if (tt > tMax) tMax = tt;
    const diffs = [];
    const check = new Set(tk.d.map((x) => x[0]));
    for (const p of written) { const a = v2zx[p]; if (a >= 0) check.add(a); else if (p >= 0x5B00 && !(SHIP && (p >= 0xA000 || (p >= 0x9640 && p < 0x9800) || HCODE[p]))) diffs.push(['запись вне карты ' + p.toString(16), '', '']); }
    for (const a of check) {
      if (owned.has(a) || NOCMP.has(a) || ptrZX.has(a) || a < 0x5D00) continue;
      if (a >= 0xE000 && a < 0xFB00) continue;
      if (a >= 0xFF00) continue;
      const p = zx2v[a];
      if (p < 0) { diffs.push(['нет на Векторе ' + a.toString(16), real[a], '']); continue; }
      if (mem[p] !== real[a]) {
        // колдун комнаты 18 по рисунку (tools/mkroom18tiles.py, 06.11): номера тайлов карты (6040, копия 5D00) другие,
        // класс клетки (>= 40 твёрдая, 18..1F пол, иначе проходимая) — тот же
        const cls = (t) => (t >= 0x40 ? 2 : t >= 0x18 && t < 0x20 ? 1 : 0);
        if (real[0xFE03] === 18 && ((a >= 0x6040 && a < 0x6300) || (a >= 0x5D00 && a < 0x5FC0)) && cls(mem[p]) === cls(real[a]) && real[a] >= 0x18 && mem[p] >= 0x18) continue;
        diffs.push([a, real[a], mem[p]]);
      }
    }
    diffs.sort((x, y) => (typeof x[0] === 'number' ? x[0] : 0) - (typeof y[0] === 'number' ? y[0] : 0));
    const want = tk.snd.map((s) => (s[0] === 'snd_hit' ? ['snd_hit', null, null] : s));
    if (sn(S.snd) !== sn(want)) diffs.push(['звук', sn(want), sn(S.snd)]);
    const clicks = tk.out.filter((o) => o[0] === 0xCF00).length;
    if (clicks !== S.clicks) diffs.push(['щелчки', clicks, S.clicks]);
    if (S.inq.length) diffs.push(['порты', 'осталось ' + S.inq.length, '']);
    if (S.rq.length) diffs.push(['ld a,r', 'осталось ' + S.rq.length, '']);
    if (err) diffs.push(['исключение', '', err.message + ' pc ' + cpu.pc.toString(16)]);
    if (diffs.length) {
      bad++;
      if (shown++ < maxShow) {
        const nm = (a) => typeof a === 'number' ? where(a) + ':' + a.toString(16) : a;
        console.log(`  шаг ${t}: ${diffs.length} расхождений: ` + diffs.slice(0, 8).map(([a, r, m]) => `${nm(a)} ZX ${r} i8080 ${m}`).join('; '));
      }
    }
    for (let a = 0x4000; a < 0x10000; a++) setZX(a, real[a]);
    S = null;
  }
  console.log(`${gd.name}: шагов ${gd.ticks.length}, i8080 ${runN}, расхождений ${bad}, пропущено ${skipped}`);
  return bad === 0;
}
let ok = true;
for (const f of files) ok = runOne(f) && ok;
if (tN) console.log(`такты на шаг: среднее ${(tAll / tN).toFixed(0)}, наибольшее ${tMax} (кадр Вектора 59904); без ожидания кадра ${((tAll - tWait) / tN).toFixed(0)}, обычный шаг (без смены комнаты) ${(tPlain / nPlain).toFixed(0)}`);
if (PROF) {
  const labs = Object.entries(SYM80).filter(([k, v]) => v >= 0x100 && v < SYM80.code_end && !k.includes('.')).sort((a, b) => a[1] - b[1]);
  const acc = labs.map(([k]) => [k, 0]);
  let j = 0;
  for (let a = 0x100; a < SYM80.code_end; a++) { while (j + 1 < labs.length && labs[j + 1][1] <= a) j++; acc[j][1] += prof[a]; }
  acc.sort((x, y) => y[1] - x[1]);
  const tot = acc.reduce((s, x) => s + x[1], 0);
  for (const [k, v] of acc.slice(0, 25)) console.log(`  ${k.padEnd(18)} ${(100 * v / tot).toFixed(1)} %  ${(v / tN).toFixed(0)} т/шаг`);
}
process.exit(ok ? 0 : 1);
