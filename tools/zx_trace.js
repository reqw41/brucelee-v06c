#!/usr/bin/env node
// Эталонный прогон Bruce Lee на модели ZX 48K (tools/zx48.js) по шагам (docs/PLAN.md, этап 0). Из jetpac-v06c.
//
// Шаг = проход главного цикла от play_loop (C7A4) до следующего play_loop. Смена комнаты, гибель и
// переход хода — внутри шага (C790 -> room_load -> play_loop).
// На каждом шаге пишется:
//   d   — изменения состояния к концу шага: [адрес, байт] в RANGES (карты комнаты 5D00–62FF, данные и код
//         6300–DFFF — там списки ключей, флаги посещения, самомодификация; переменные FB00–FEFF). Экран ZX
//         4000–5AFF и теневой экран E000–FAFF не входят: логика их не читает (stand/zxreads.js);
//   rd  — чтения игрой адресов, которые пишет прерывание (ввод, флаг кадра, счётчики), по порядку;
//   in  — чтения портов игрой по порядку: [порт, байт];
//   r   — значения `ld a,r`;
//   snd — входы в звуковые подпрограммы [имя, b, c]; out — записи в порт FE игрой [адрес команды, байт]
//         (CF00 — щелчок шагов, C29F — бордюр при копии экрана);
//   fr  — кадров за шаг; keys — клавиши шага; pk — записи сценария перед шагом.
// В начале — снимок `first` (вся память 4000–FFFF, base64) и регистры `regs`.
//
//   node tools/zx_trace.js <сценарий.json> [выход.json.gz]
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const scenario = require('./scenario');
const { SYM, ROOT } = require('./sym');

const RANGES = [[0x5d00, 0xe000], [0xfb00, 0xff00]];
const inState = (a) => RANGES.some(([lo, hi]) => a >= lo && a < hi);
const SHOTS = process.env.SHOTS, SHOT_EVERY = +(process.env.SHOT_EVERY || 100);   // SHOTS=каталог — снимки экрана ZX
if (SHOTS) fs.mkdirSync(SHOTS, { recursive: true });
const SND = ['snd_jingle', 'snd_die', 'snd_key', 'snd_hit'];

function regsOf(m) {
  const s = m.cpu.getState();
  return { a: s.a, b: s.b, c: s.c, d: s.d, e: s.e, h: s.h, l: s.l, ix: s.ix, iy: s.iy, sp: s.sp };
}

function run(sc, owned, learn) {
  const { m, keysFor, applied } = scenario.start(sc);
  let cur = null;
  m.onWrite = (a, v, isr) => { if (isr && learn) learn.add(a); };
  m.onRead = (a, v, isr) => { if (!isr && cur && owned && owned.has(a)) cur.rd.push([a, v]); };
  m.onIn = (p, v, isr) => { if (!isr && cur) cur.in.push([p, v]); };
  m.onOut = (p, v) => { if (!m.inIsr && cur && (p & 1) === 0 && !cur.inSnd) cur.out.push([lastPc, v]); };
  const sndAt = new Map(SND.map((n) => [SYM[n], n]));
  const ticks = [];
  const cov = new Uint8Array(0x10000);
  const snap = () => m.mem.slice(0);
  let prev = snap();
  const first = Buffer.from(m.mem.subarray(0x4000)).toString('base64');
  const regs = regsOf(m);
  const END = SYM.play_loop, MENU = [SYM.menu, SYM.start, SYM.game_over];
  let minSp = 0x10000, lastPc = 0;
  for (let t = 0; ; t++) {
    const keys = keysFor(t);
    if (!keys) break;
    for (const [a, v] of applied) prev[a] = v;
    m.keysOnly(keys);
    cur = { rd: [], in: [], r: [], snd: [], out: [], keys, inSnd: false };
    if (applied.length) cur.pk = applied.slice();
    const f0 = m.frames, t0 = m.total;
    let menu = false, moved = false, sndDepth = -1;
    for (;;) {
      const pc = m.pc;
      if (pc === END && !m.inIsr && moved) break;
      if (m.intLine && m.intReady()) { m.step(); continue; }
      if (!m.inIsr) {
        moved = true; cov[pc] = 1;
        if (MENU.includes(pc)) menu = true;
        const sn = sndAt.get(pc);
        if (sn && !cur.inSnd) { const s = m.cpu.getState(); cur.snd.push([sn, s.b, s.c]); cur.inSnd = true; sndDepth = s.sp; }
        const sp = m.cpu.get_sp(); if (sp < minSp) minSp = sp;
        if (cur.inSnd && sp > sndDepth) cur.inSnd = false;          // вернулись из звука
      }
      const isLdAR = !m.inIsr && m.peek(pc) === 0xed && m.peek(pc + 1) === 0x5f;
      if (!m.inIsr) lastPc = pc;
      m.step();
      if (isLdAR) cur.r.push(m.cpu.get_a());
      if (menu) break;
      if (m.frames - f0 > 3000) throw new Error('шаг не кончается, pc ' + pc.toString(16));
    }
    delete cur.inSnd;
    cur.fr = m.frames - f0;
    cur.t = m.total - t0;
    if (menu) cur.menu = 1;
    const now = snap();
    const d = [];
    for (const [lo, hi] of RANGES) for (let a = lo; a < hi; a++) {
      if (now[a] === prev[a] || (owned && owned.has(a))) continue;
      d.push([a, now[a]]);
    }
    cur.d = d;
    ticks.push(cur);
    prev = now;
    if (SHOTS && learn === null && t % SHOT_EVERY === SHOT_EVERY - 1) fs.writeFileSync(path.join(SHOTS, `t${String(t + 1).padStart(5, '0')}.ppm`), m.ppm());
    if (menu) break;
  }
  return { m, ticks, first, regs, cov, minSp };
}

if (require.main === module) {
  const scFile = process.argv[2];
  const sc = JSON.parse(fs.readFileSync(scFile, 'utf8'));
  const out = process.argv[3] || path.join(ROOT, 'build/golden', sc.name + '.json.gz');
  const learn = new Set();
  run(sc, null, learn);
  const owned = new Set([...learn].filter((a) => inState(a)));
  const t0 = Date.now();
  const { ticks, first, regs, cov, minSp } = run(sc, owned, null);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  const covList = []; for (let a = 0x9300; a < 0xe000; a++) if (cov[a]) covList.push(a);
  const doc = { name: sc.name, scenario: sc, owned: [...owned].sort((a, b) => a - b), ranges: RANGES, first, regs, cov: covList, ticks };
  fs.writeFileSync(out, zlib.gzipSync(JSON.stringify(doc)));
  const fr = ticks.reduce((s, t) => s + t.fr, 0);
  const cnt = (k) => ticks.reduce((s, t) => s + t[k].length, 0);
  const rooms = new Set(); // комнаты по записям cur_room
  for (const t of ticks) for (const [a, v] of t.d) if (a === SYM.cur_room) rooms.add(v);
  console.log(`${sc.name}: шагов ${ticks.length}, кадров ${fr} (${(fr / ticks.length).toFixed(2)} на шаг), ` +
    `адресов прерывания ${owned.size} [${[...owned].map((a) => a.toString(16)).join(' ')}], ldar ${cnt('r')}, in ${cnt('in')}, ` +
    `звуков ${cnt('snd')}, out ${cnt('out')}, комнаты [${[...rooms].join(',')}], мин. SP ${minSp.toString(16)}` +
    `${ticks.length && ticks[ticks.length - 1].menu ? ', конец — меню' : ''}, ${Date.now() - t0} мс -> ${path.relative(ROOT, out)}`);
}
module.exports = { run, RANGES };
