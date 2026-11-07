#!/usr/bin/env node
// Таблица цветов тайлов 6300 общая на всю игру, tile_fix (src/vec/tilefix.asm) правит её по комнате: цвета в комнате не
// должны зависеть от того, откуда в неё пришли и сколько раз (06.11: правки копились). Эталон — каждая комната с
// чистого старта; сверка — обход 0..19, 19..0 и повторные входы. Колдун комнаты 18 (06.11): заёмные номера
// (build/room18_tiles.json) в комнате 18 — узор и цвет по плану, в остальных — весь набор 9800 как в образе.
//   node tools/vectilefix.js [образ]   NEG=1 — без возврата цветов, NEG=2 — без обмена заёмных номеров, NEG=3 — без возврата
'use strict';
const fs = require('fs'), path = require('path');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const ROM = process.argv[2] || path.join(__dirname, '../build/vec/brucelee.bin');
const sym = {}; for (const l of fs.readFileSync(ROM.replace(/\.bin$/, '.sym'), 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
function visit(seq) {                                // последовательность комнат -> таблицы 6300 (и узор тайла 14) после входа
  const m = E.mk(ROM); let i = 0, st = 0; const out = [];
  if (process.env.NEG === '1') m.wr(sym.tf_orig + 1, 0);   // негативный контроль: без возврата исходных цветов
  if (process.env.NEG === '2') m.wr(sym.r18_swap, 0xC9);    // негативный контроль: заём не делается
  if (process.env.NEG === '3') for (let k = 4; k < 7; k++) m.wr(sym.tile_fix + k, 0);   // заём не возвращается (CALL NZ -> NOP)
  m.onInstr = (pc) => {
    if (pc !== sym.pass) return;
    if (st === 0 && i < seq.length) { m.wr(sym.zv_FE0E, seq[i]); m.wr(sym.zv_FE04, 1); m.wr(sym.zv_FED0, 0x30); m.wr(sym.zv_FED1, 0x39); m.cpu.pc = sym.next_player; st = 1; }
    else if (st === 1) { const t = []; for (let a = 0x6300; a < 0x6400; a++) t.push(m.rd(a)); for (let a = 0x9800; a < 0xA000; a++) t.push(m.rd(a)); out.push([m.rd(sym.zv_FE03), t.join(',')]); i++; st = 0; }
  };
  const plan = VK.parse('160:space+ 200:space-');
  for (let f = 0; f < 400 + seq.length * 60 && i < seq.length; f++) { VK.apply(m, plan[f]); m.frame(); }
  return out;
}
const fresh = {}; for (let r = 0; r < 20; r++) fresh[r] = visit([r])[0][1];
// вне списка tile_fix (tf_orig: тайл, число, исходные...) таблица должна быть как в образе (ZX + цвета колдуна при сборке)
const BIN = fs.readFileSync(ROM), ZX = fs.readFileSync(path.join(__dirname, '../build/zx_tap.bin'));
const touched = new Set(); for (let a = sym.tf_orig; ;) { const t = BIN[a], n = BIN[a + 1]; if (!n) break; for (let k = 0; k < n; k++) touched.add(t + k); a += 2 + n; if (touched.size > 256) break; }
const R18 = JSON.parse(fs.readFileSync(path.join(__dirname, '../build/room18_tiles.json'), 'utf8')).borrow;
const b18 = {}; for (const b of R18) b18[b.t] = b;
let badzx = 0, badpat = 0;
for (let r = 0; r < 20; r++) { const t = fresh[r].split(',').map(Number);
  for (let i = 0; i < 256; i++) { const want = r === 18 && b18[i] ? b18[i].attr : BIN[0x6300 + i];
    if ((!touched.has(i) || (r === 18 && b18[i])) && t[i] !== want) { badzx++; if (badzx <= 3) console.log(`  комната ${r}: тайл ${i.toString(16)} — цвет не как в образе (${t[i].toString(16)} против ${want.toString(16)})`); }
    for (let k = 0; k < 8; k++) { const w = r === 18 && b18[i] ? b18[i].pat[k] : BIN[0x9800 + i * 8 + k];
      if (t[256 + i * 8 + k] !== w) { badpat++; if (badpat <= 3) console.log(`  комната ${r}: узор тайла ${i.toString(16)} не как ${r === 18 && b18[i] ? 'в плане колдуна' : 'в образе'}`); break; } } } }
const seq = [...Array(20).keys(), ...[...Array(20).keys()].reverse(), 18, 18, 7, 9, 12, 17, 13, 16, 8, 3];
let bad = 0;
for (const [r, t] of visit(seq)) if (t !== fresh[r]) { bad++; if (bad <= 5) console.log(`  комната ${r}: таблица цветов/узоры тайлов не как при чистом входе`); }
console.log(`цвета тайлов: ${seq.length} входов, расхождений ${bad}; вне правок не как в образе: ${badzx} (правит ${touched.size} тайлов); узоры: не как в образе/плане ${badpat} (заём ${R18.length})`);
process.exit(bad || badzx || badpat ? 1 : 0);
