#!/usr/bin/env node
// Прогон JS-модели по эталону без процессора (docs/PLAN.md, этап 1; образец — jetpac-v06c): начальное
// состояние — снимок эталона (first, 4000–FFFF) + ПЗУ; на каждом шаге — очереди эталона (rd, in, r);
// модель делает проход главного цикла (game.pass) и сравнивает изменённую память с эталоном (d),
// звук и щелчки. После шага состояние берётся из эталона (расхождения не копятся).
//   node tools/model_run.js build/golden/<имя>.json.gz [...] [--max N] [--from шаг]
'use strict';
const fs = require('fs'), path = require('path'), zlib = require('zlib');
const { Mem } = require('../src/model/core');
const game = require('../src/model/game');
const { where, ROOT } = require('./sym');

const args = process.argv.slice(2);
let maxShow = 5, from = 0;
const files = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--max') maxShow = +args[++i];
  else if (args[i] === '--from') from = +args[++i];
  else files.push(args[i]);
}
const sn = (l) => l.map((s) => s[0] + (s[1] === null || s[0] === 'snd_hit' ? '' : `(${s[1]},${s[2]})`)).join(' ');

function runOne(file) {
  const g = JSON.parse(zlib.gunzipSync(fs.readFileSync(file)));
  const ram = new Uint8Array(0x10000);
  ram.set(fs.readFileSync(path.join(ROOT, 'ref/48.rom')));
  ram.set(Buffer.from(g.first, 'base64'), 0x4000);
  const real = new Uint8Array(ram);
  const owned = new Set(g.owned);
  const inRange = (a) => g.ranges.some(([lo, hi]) => a >= lo && a < hi);
  let bad = 0, runN = 0, skipped = 0, shown = 0;
  const why = {};
  for (let t = 0; t < g.ticks.length; t++) {
    const tk = g.ticks[t];
    for (const [a, v] of tk.pk || []) { real[a] = v; ram[a] = v; }
    if (t < from || tk.menu) { for (const [a, v] of tk.d) real[a] = v; ram.set(real); skipped++; continue; }
    const M = new Mem(ram);
    M.owned = owned; M.writes = new Set();
    for (const [a, v] of tk.rd) { let q = M.q.get(a); if (!q) M.q.set(a, q = []); q.push(v); }
    M.inq = tk.in.slice(); M.rq = tk.r.slice();
    let err = null;
    try { game.pass(M); } catch (e) { err = e; if (!e.notModeled) console.log(`  шаг ${t}: ${e.stack.split('\n').slice(0, 4).join(' | ')}`); }
    for (const [a, v] of tk.d) real[a] = v;
    if (err && err.notModeled) { why[err.message] = (why[err.message] || 0) + 1; ram.set(real); skipped++; continue; }
    runN++;
    const diffs = [];
    for (const a of new Set([...M.writes, ...tk.d.map((x) => x[0])])) if (inRange(a) && !owned.has(a) && ram[a] !== real[a]) diffs.push([a, real[a], ram[a]]);
    diffs.sort((x, y) => x[0] - y[0]);
    if (sn(M.snd) !== sn(tk.snd)) diffs.push(['звук', sn(tk.snd), sn(M.snd)]);
    if (M.out.join() !== tk.out.map((o) => o[1]).join()) diffs.push(['out FE', tk.out.map((o) => o[1]).join(), M.out.join()]);
    if (M.inq.length) diffs.push(['порты', 'осталось ' + M.inq.length, '']);
    if (M.rq.length) diffs.push(['ld a,r', 'осталось ' + M.rq.length, '']);
    if (err) diffs.push(['исключение', '', err.message]);
    if (diffs.length) {
      bad++;
      if (shown++ < maxShow) {
        const nm = (a) => typeof a === 'number' ? where(a) + ':' + a.toString(16) : a;
        console.log(`  шаг ${t}: ${diffs.length} расхождений: ` + diffs.slice(0, 8).map(([a, r, m]) => `${nm(a)} ZX ${r} модель ${m}`).join('; '));
      }
    }
    ram.set(real);
  }
  console.log(`${g.name}: шагов ${g.ticks.length}, модель ${runN}, расхождений ${bad}, без модели ${skipped} ${JSON.stringify(why)}`);
  return bad === 0;
}
let ok = true;
for (const f of files) ok = runOne(f) && ok;
process.exit(ok ? 0 : 1);
