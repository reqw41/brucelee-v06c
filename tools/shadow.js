#!/usr/bin/env node
// Теневая сверка JS-модели (docs/PLAN.md, этап 1; образец — aticatac-v06c/tools/shadow.js): игра идёт на
// модели ZX по сценарию; на входе в подпрограмму, которая есть в модели (src/model/index.js), снимается
// память и регистры, Z80 доходит до возврата (его записи, чтения адресов прерывания, порты, ld a,r, звуки),
// затем модель выполняет ту же подпрограмму на снимке; сравниваются все записанные адреса (кроме адресов
// прерывания, стека, экранов) и выходные регистры. Вложенные вызовы проверяются отдельно.
//
//   node tools/shadow.js <сценарий.json> [имя,имя,...] [--ticks N] [--max 5]
'use strict';
const fs = require('fs');
const scenario = require('./scenario');
const { SYM, where } = require('./sym');
const model = require('../src/model');
const { Mem } = require('../src/model/core');
const { run } = require('./zx_trace');

const args = process.argv.slice(2);
const sc = JSON.parse(fs.readFileSync(args[0], 'utf8'));
let only = null, maxShow = 5;
for (let i = 1; i < args.length; i++) {
  if (args[i] === '--ticks') sc.ticks = +args[++i];
  else if (args[i] === '--max') maxShow = +args[++i];
  else only = new Set(args[i].split(','));
}
const names = Object.keys(model.routines).filter((n) => !only || only.has(n));
const entry = new Map(names.map((n) => [SYM[n], n]));
const learn = new Set();
run(Object.assign({}, sc, { ticks: Math.min(sc.ticks || 1e9, 1500) }), null, learn);
const owned = new Set([...learn].filter((a) => a >= 0x5d00));
const skipCmp = (a) => owned.has(a) || a < 0x5d00 || (a >= 0xE000 && a < 0xFB00) || a >= 0xFF00;
const SND = new Map(['snd_jingle', 'snd_die', 'snd_key', 'snd_hit'].map((n) => [SYM[n], n]));

const active = [];
let m = null, inSnd = 0;
const onCreate = (mm) => {
  m = mm;
  m.onWrite = (a, v, isr) => { if (!isr) for (const c of active) c.w.add(a); };
  m.onRead = (a, v, isr) => { if (isr || !owned.has(a)) return; for (const c of active) { let q = c.q.get(a); if (!q) c.q.set(a, q = []); q.push(v); } };
  m.onIn = (p, v, isr) => { if (!isr) for (const c of active) c.inq.push([p, v]); };
  m.onOut = (p, v) => { if (!m.inIsr && !(p & 1) && !inSnd) for (const c of active) c.out.push(v); };
};
const stat = {}; for (const n of names) stat[n] = { calls: 0, bad: 0, skip: 0 };
let shown = 0, tick = 0;

function finish(c) {
  const st = stat[c.name]; st.calls++;
  const mem = new Mem(c.ram);
  mem.owned = owned; mem.q = c.q; mem.rq = c.r.slice(); mem.inq = c.inq.slice(); mem.writes = new Set();
  let out;
  try { out = model.routines[c.name](mem, c.regs); }
  catch (e) { if (e.notModeled || e.restart) { st.skip++; return; } console.log(`шаг ${tick} ${c.name}: ${e.stack}`); st.bad++; return; }
  const diffs = [];
  for (const a of new Set([...c.w, ...mem.writes])) if (!skipCmp(a) && m.mem[a] !== c.ram[a]) diffs.push([a, m.mem[a], c.ram[a]]);
  diffs.sort((x, y) => x[0] - y[0]);
  const cs = m.cpu.getState();
  for (const r of model.routines[c.name].out) {
    const real = r[0] === 'f' && r.length === 2 ? !!cs.flags[r[1].toUpperCase()] : cs[r];
    if (!out || out[r] !== real) diffs.push(['рег ' + r, real, out && out[r]]);
  }
  const sn = (l) => l.map((s) => s[0] + (s[1] === null || s[0] === 'snd_hit' ? '' : `(${s[1]},${s[2]})`)).join(' ');
  if (sn(mem.snd) !== sn(c.snd)) diffs.push(['звук', sn(c.snd), sn(mem.snd)]);
  if (mem.out.join() !== c.out.join()) diffs.push(['out FE', c.out.join(), mem.out.join()]);
  if (mem.rq.length) diffs.push(['ld a,r', 'осталось ' + mem.rq.length, '']);
  if (mem.inq.length) diffs.push(['порты', 'осталось ' + mem.inq.length, '']);
  if (diffs.length) {
    st.bad++;
    if (shown++ < maxShow) {
      const nm = (a) => typeof a === 'number' ? where(a) + '(' + a.toString(16) + ')' : a;
      console.log(`шаг ${tick} ${c.name}: ${diffs.length} расхождений; вход ${JSON.stringify(c.regs, (k, v) => typeof v === 'number' ? v.toString(16) : v)}`);
      for (const [a, r, mm] of diffs.slice(0, 8)) console.log(`   ${nm(a)}: ZX ${r} модель ${mm}`);
    }
  }
}

function shadowStep() {
  const pc = m.pc;
  if (m.intLine && m.intReady()) { m.step(); return; }
  if (!m.inIsr) {
    const n = entry.get(pc);
    const s = m.cpu.getState();
    const top = active[active.length - 1];
    if (n && !(top && top.name === n && top.sp === s.sp)) {        // не витки цикла на метке входа
      active.push({ name: n, ram: m.mem.slice(), sp: s.sp, ret: m.peek(s.sp) | m.peek(s.sp + 1) << 8,
        regs: { a: s.a, b: s.b, c: s.c, d: s.d, e: s.e, h: s.h, l: s.l, ix: s.ix, iy: s.iy },
        w: new Set(), q: new Map(), r: [], inq: [], snd: [], out: [] });
    }
    const sn = SND.get(pc);
    if (sn && !inSnd) { for (const c of active) c.snd.push([sn, s.b, s.c]); inSnd = s.sp; }
  }
  const isLdAR = !m.inIsr && m.peek(pc) === 0xed && m.peek(pc + 1) === 0x5f;
  m.step();
  if (isLdAR) { const a = m.cpu.get_a(); for (const c of active) c.r.push(a); }
  if (!m.inIsr) {
    const sp = m.cpu.get_sp();
    if (inSnd && sp > inSnd) inSnd = 0;
    while (active.length) {
      const c = active[active.length - 1];
      if (m.pc === c.ret && sp === ((c.sp + 2) & 0xffff)) { active.pop(); finish(c); }
      else if (sp > ((c.sp + 2) & 0xffff) || sp < 0xF000) { active.pop(); stat[c.name].skip++; }   // ушли не через RET
      else break;
    }
  }
}

const { keysFor } = scenario.start(sc, { onCreate, step: (mm) => mm.step() });
for (let t = 0; ; t++) {
  tick = t;
  const keys = keysFor(t);
  if (!keys) break;
  m.keysOnly(keys);
  let moved = false;
  for (;;) {
    if (m.pc === SYM.play_loop && !m.inIsr && moved) break;
    if ([SYM.menu, SYM.start, SYM.game_over].includes(m.pc)) { t = 1e9; break; }
    shadowStep(); moved = true;
  }
  if (t >= 1e9) break;
}
let ok = true;
for (const n of names) {
  const s = stat[n];
  if (s.bad) ok = false;
  if (s.calls || s.bad) console.log(`${n.padEnd(18)} вызовов ${String(s.calls).padStart(7)}  расхождений ${String(s.bad).padStart(6)}  пропущено ${s.skip}`);
}
console.log('не вызывались:', names.filter((n) => !stat[n].calls).join(' '));
process.exit(ok ? 0 : 1);
