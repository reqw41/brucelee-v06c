#!/usr/bin/env node
// Покрытие кода игры эталонами: какие команды (по меткам) ни разу не выполнялись (кроме прерывания).
//   node tools/coverage.js build/golden/*.json.gz [--all]   (--all — и меню/титул/звук)
'use strict';
const fs = require('fs'), zlib = require('zlib'), path = require('path');
const { where, ROOT } = require('./sym');
const args = process.argv.slice(2), all = args.includes('--all');
const hit = new Set();
for (const f of args.filter((a) => !a.startsWith('--'))) for (const a of JSON.parse(zlib.gunzipSync(fs.readFileSync(f))).cov || []) hit.add(a);
const instr = []; let inCode = false;
for (const l of fs.readFileSync(path.join(ROOT, 'ref/sgr/brucelee-zx/brucelee.skool'), 'utf8').split('\n')) {
  if (/^[bwtsu]\$/.test(l)) inCode = false; else if (/^c\$/.test(l)) inCode = true;
  const m = l.match(/^[c* ]\$([0-9A-F]{4}) ([A-Z]+.*?)\s*;/);
  if (inCode && m && !/^DEF/.test(m[2])) instr.push({ a: parseInt(m[1], 16), txt: m[2].trim() });
}
// не логика игры: титул/меню, вывод, звук, прерывание
const NOT_LOGIC = [[0x9300, 0x9649], [0xC000, 0xC0E5], [0xC29C, 0xC2B2], [0xC2EC, 0xC366], [0xC3CB, 0xC714], [0xC8C6, 0xC93C], [0xD825, 0xD845]];
const code = instr.filter((i) => all || !NOT_LOGIC.some(([lo, hi]) => i.a >= lo && i.a < hi));
const miss = code.filter((i) => !hit.has(i.a));
console.log(`команд ${code.length}, выполнено ${code.length - miss.length} (${(100 * (code.length - miss.length) / code.length).toFixed(1)} %)`);
let prev = null;
for (const i of miss) { const L = where(i.a).split('+')[0]; if (L !== prev) { console.log(' ' + L + ':'); prev = L; } console.log(`   ${i.a.toString(16)} ${i.txt}`); }
