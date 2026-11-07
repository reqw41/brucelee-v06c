// Ход игры: проход главного цикла (play_loop C7A4), очки (C99B), шапка (C93C), жизни (CA1A), гибель Брюса
// (CA46), переход в другую комнату (C875 -> C790), конец уровня (DD67 -> C73C).
'use strict';
const P = require('./pers');
const { NotModeled } = require('./core');
const { u8, u16, NINJA, YAMO, BRUCE } = P;

const cur2 = (M) => M.rd(0xFE04) === 1 ? 0 : 1;

// C93C + C960: шапка — номер игрока и очки в строку FEB2.., FE0B = 1 (вывод строки — экран)
function header(M) {
  const d = M.rd(0xFE04) + 0x30;
  M.wr(0xFEB2, d);
  const src = d === 0x31 ? 0xFEF2 : 0xFEF8;
  for (let k = 0; k < 6; k++) M.wr(0xFEB6 + k, M.rd(src + k));
  M.wr(0xFE0B, 1);
}
function header_msg(M) { M.wr(0xFE0B, 1); }        // C960
// CA1A: жизнь +1 (две цифры, не больше 99)
function lives_up(M) {
  let L = M.rd(0xFED0), H = M.rd(0xFED1) + 1;
  if (H >= 0x3A) { L = u8(L + 1); H = 0x30; }
  if (L >= 0x3A) { L = 0x39; H = 0x39; }
  M.wr(0xFED0, L); M.wr(0xFED1, H);
  header_msg(M);
}
// C99B: прибавить очки (6 цифр ASCII по адресу hl) текущему игроку; рекорд; жизнь за 30 000/60 000/90 000…
function add_score(M, hl) {
  let de = M.rd(0xFE04) === 1 ? 0xFEF2 : 0xFEF8;
  M.wr(0xFEAA, M.rd(de)); M.wr(0xFEAB, M.rd(de + 1));
  de += 5; hl += 5;
  let c = 0;
  for (let k = 0; k < 6; k++) {
    let a = u8(u8(M.rd(de) + M.rd(hl)) - 0x30 + c);
    c = 0;
    if (a >= 0x3A) { a = u8(a - 0x0A); c = 1; }
    M.wr(de, a); de--; hl--;
  }
  de++;
  let h = 0xFEC2;
  for (let k = 6; k > 0; k--) {
    const a = M.rd(de), r = M.rd(h);
    if (a < r) break;
    if (a > r) { for (let n = k, v = a; n > 0; n--) { M.wr(h, v); h++; de++; v = M.rd(de); } break; }
    h++; de++;
  }
  header(M);
  const DE = M.rd16(0xFEB6), HL = M.rd16(0xFEAA);
  if (HL === DE) return;
  const D = DE >> 8, E = DE & 0xff;
  let a = D & 0x0F;
  if (!a) return;
  a = (u8(a - 1 + E)) & 0x0F;
  if (a >= 0x0A) a -= 9;
  if (a === 3 || a === 6 || a === 9) lives_up(M);
}

// C121: пауза, рестарт, звук — по клавишам (кроме «ничего не нажато» — не моделируется)
function check_keys(M) {
  if (!(M.in(0x7FFE) & 1) && !(M.in(0xFEFE) & 1)) throw new NotModeled('рестарт BREAK');
  if (!(M.in(0xBFFE) & 1)) throw new NotModeled('пауза');
  if (!(M.in(0x7FFE) & 2)) throw new NotModeled('звук вкл/выкл');
}

// CAB6: обмен блоков
function swap(M, a, b, n) { for (let k = 0; k < n; k++) { const t = M.rd(b + k); M.wr(b + k, M.rd(a + k)); M.wr(a + k, t); } }

// C790: шапка, комната игрока, загрузка
function next_player(M) {
  header(M);
  M.wr(0xFE03, M.rd(0xFE0E + cur2(M)));
  require('./room').room_load(M);
}
// CA46: Брюс погиб
function bruce_died(M) {
  let E = M.rd(0xFED0), D = M.rd(0xFED1);
  if (E === 0x30 && D === 0x30) { const e = new NotModeled('конец игры'); e.gameOver = true; throw e; }
  D = u8(D - 1);
  if (D < 0x30) { D = 0x39; E = u8(E - 1); }
  M.wr(0xFED0, E); M.wr(0xFED1, D);
  header_msg(M);
  M.halts += 50;
  const hl = M.rd(0xCCAC) >= 0x12 ? 0x6008 : 0x602D;
  M.wr(0xCCAB, M.rd(hl)); M.wr(0xCCAC, M.rd(hl + 1)); M.wr(0xCCA8, M.rd(hl + 2) & 1); M.wr(0xCCA7, 0);
  if (M.rd(0xFE07)) {
    M.wr(0xFE04, M.rd(0xFE04) === 1 ? 2 : 1);
    swap(M, 0xCCA5, 0xFE81, 0x12);
    swap(M, 0xFE20, 0xFE40, 0x20);
  }
  next_player(M);
}
// C73C: новый круг (после DD67) — Брюс в начало, флаги комнат и предметы заново
function restart_level(M) {
  M.wr16(0xCCAB, 0x0604);
  for (let k = 0; k < 0x12; k++) M.wr(0xFE81 + k, M.rd(0xCCA5 + k));
  for (let k = 0; k < 0x40; k++) M.wr(0xFE20 + k, 0);
  for (let l = 0; l < 0x28; l += 2) {
    const desc = M.rd16(0x6400 + l);
    M.wr(u16(desc + 0x0C), 0); M.wr(u16(desc + 0x0D), 0);
    let p = M.rd16(u16(desc + 6));
    for (;;) {
      const v = M.rd(p);
      if (v & 0x80) { if (v === 0xFF) break; M.wr(p, v | 3); p = u16(p + 1); }
      p = u16(p + 3);
    }
  }
  M.wr16(0xFE0E, 0);
  next_player(M);
}
// DD67: финал — надпись, через 3 шага мелодия и новый круг
function level_complete(M) {
  const v = M.rd(0xFE3E); M.wr(0xFE3E, u8(v + 1));
  if (v === 0) require('./out').screen_copy(M);
  if (v !== 3) {
    M.wr(0xFE11, 0); M.wr(0xFE12, 0); M.wr(0xCCA8, 0); M.wr(0xCCA5, 1); M.wr(0xCCA7, 0x10);
    return;
  }
  require('./sound').play(M, 'snd_jingle', 0x935C, 0x00, M.rd(0xFE9A) ? 0xD3 : 0x3E);
  M.wr(0xFE0D, 1);
  const e = new Error('restart'); e.restart = true; throw e;
}

// один проход главного цикла: от play_loop до следующего play_loop
function pass(M) {
  const out = require('./out'), room = require('./room');
  check_keys(M);
  M.wr(0xFE0C, 0);
  for (;;) { const v = M.rd(0xFE02); M.wr(0xFE02, v >> 1); if (v & 1) break; }
  if (M.rd(0xFE0B)) out.screen_copy(M);
  for (const ix of [NINJA, YAMO, BRUCE]) out.pers_erase(M, ix);
  try { room.dispatch(M, 0xD7AC, 0); } catch (e) { if (e.restart) { restart_level(M); return; } throw e; }
  const f = M.rd(0xFE1A); M.wr(0xFE1A, 0);
  if (!f) for (const ix of [NINJA, YAMO, BRUCE]) P.step(M, ix);
  if (M.rd(0xCCAF) >= 0x64) { bruce_died(M); return; }
  for (const ix of [NINJA, YAMO]) { P.fell(M, ix); P.expire(M, ix); }
  const ix = BRUCE;
  let leave = !!M.rd(0xFE0C);
  if (!leave) {
    const { b, c } = P.size(M, ix);
    let a = M.rd(ix + 7);
    if (a < 3) { a = M.rd(ix + 4); if (a < 4) leave = true; }
    if (!leave && u8(a + b) >= 0x18) leave = true;
    if (!leave) {
      if (M.rd(ix + 3)) { if (M.rd(ix + 6) & 0x80) leave = true; }
      else if (u8(M.rd(ix + 6) + c) >= 0x21) leave = true;
    }
  }
  if (!leave) { for (const i of [NINJA, YAMO, BRUCE]) out.pers_draw(M, i); return; }
  // C875: выход из комнаты по зоне 3×3
  let e = 0;
  const bx = u8(M.rd(ix + 6) + 1);
  if (M.rd(0x600E) < bx) { e++; if (M.rd(0x600F) < bx) e++; }
  const by = M.rd(ix + 7);
  if (M.rd(0x6010) < by) { e += 3; if (M.rd(0x6011) < by) e += 3; }
  const hl = 0x6012 + e * 3;
  const r = M.rd(hl);
  if (r === 0xFF) { bruce_died(M); return; }
  M.wr(0xFE0E + cur2(M), r);
  M.wr(0xCCAB, M.rd(hl + 1)); M.wr(0xCCAC, M.rd(hl + 2));
  next_player(M);
}

module.exports = { pass, add_score, header, lives_up, check_keys, bruce_died, next_player, restart_level, level_complete, swap };
