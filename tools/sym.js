// Метки игры: @label из skool nzeemin + свои (tools/names.txt: "АДРЕС имя"), прочие подпрограммы — L_XXXX.
// SYM: имя -> адрес, NAME: адрес -> имя, where(a): "имя+N".
'use strict';
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..');
const SYM = {}, NAME = new Map();
const add = (n, a) => { if (!(n in SYM)) SYM[n] = a; if (!NAME.has(a)) NAME.set(a, n); };
const own = path.join(ROOT, 'tools/names.txt');
if (fs.existsSync(own)) for (const l of fs.readFileSync(own, 'utf8').split('\n')) {
  const m = l.match(/^([0-9A-Fa-f]{4})\s+(\w+)/); if (m) add(m[2], parseInt(m[1], 16));
}
let pend = null;
for (const l of fs.readFileSync(path.join(ROOT, 'ref/sgr/brucelee-zx/brucelee.skool'), 'utf8').split('\n')) {
  const m = l.match(/^@label=(\w+)/); if (m) { pend = m[1]; continue; }
  const a = l.match(/^[cbwtsu* ]\$([0-9A-F]{4})/);
  if (a) { const ad = parseInt(a[1], 16); if (pend) { add(pend, ad); pend = null; } if (l[0] === 'c') add('L_' + a[1], ad); }
}
const sorted = [...NAME].sort((x, y) => x[0] - y[0]);
function where(a) {
  let best = null; for (const [v, k] of sorted) { if (v > a) break; best = [v, k]; }
  return best ? best[1] + (a - best[0] ? '+' + (a - best[0]) : '') : a.toString(16);
}
module.exports = { SYM, NAME, where, ROOT };
