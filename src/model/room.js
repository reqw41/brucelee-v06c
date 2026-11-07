// Комната: загрузка (C16E), смена тайлов (D60E/D626), сценарии «воли» (D5BB), обработчики комнат по
// таблицам D7AC (каждый шаг), D7D4 (после подбора), D7FC (клетки 17h), вода и трещины. Только логика:
// карты 6000/5D00, переменные, служебные ячейки; вывод в экран ZX и теневой экран не моделируется.
'use strict';
const P = require('./pers');
const { u8, u16, n256, NINJA, YAMO, BRUCE } = P;

const off = (hl) => (((hl >> 8) & 0x1f) << 5) | (hl & 0x1f);     // (строка, столбец) -> смещение 0..3FF
// D60E: положить тайл a в карту 6000 по (H=строка, L=столбец)
function tile_put(M, a, hl) { M.wr(0x6000 + off(hl), a); }
// D626: восстановить тайл из фона 5D00
function tile_redraw(M, hl) { const o = off(hl); M.wr(0x6000 + o, M.rd(0x5D00 + o)); }

// CA37: обработчик по номеру комнаты из таблицы tbl; de — аргумент обработчика
function dispatch(M, tbl, de) {
  const h = M.rd16(u16(tbl + u8(M.rd(0xFE03) * 2)));
  const f = R[h];
  if (!f) throw new Error('модель: нет обработчика комнаты ' + h.toString(16));
  f(M, de);
}

// D5BB: применить «волю» комнаты a к точке hl (строка, столбец)
function will_apply(M, a, hl) {
  M.wr(0xFE98, a); M.wr16(0xFEAE, hl);
  const desc = M.rd16(0x6400 | u8(a * 2));
  let p = M.rd16(u16(desc + 6));
  const e = M.rd(0xFEAE), d = M.rd(0xFEAF);
  for (;;) {
    let v = M.rd(p);
    if (v === 0xFF) return;
    if (v & 0x80) { M.wr16(0xFEB0, p); p = u16(p + 1); v = M.rd(p); }
    p = u16(p + 1);
    let z = false;
    if (v === e) z = M.rd(p) === d;
    p = u16(p + 2);
    if (z) break;
  }
  let q = M.rd16(0xFEB0);
  M.wr(q, ~M.rd(0xFE04) & M.rd(q));
  if (M.rd(0xFE98) !== M.rd(0xFE03)) return;
  q = u16(q + 1);
  do {
    const ee = M.rd(q), dd = M.rd(u16(q + 1)); q = u16(q + 2);
    tile_redraw(M, dd << 8 | ee);
    q = u16(q + 1);
  } while (!(M.rd(q) & 0x80));
}

// --- вода (DDFF, DE47/DF11), полосы (DF7A), бегающие объекты (DDA8), трещины (D9D7) --------------------
function water_phase(M) {          // DDFF: Z (true) — можно двигать воду
  if (M.rd(0xCCAF)) return false;
  if (M.dec(0xFE9B)) return false;
  let b = M.rd(0xFE9C), c = b & 0x3f, a;
  M.wr(0xFE9B, (c >> 2) + 6);
  if (b & 0x40) { c--; if (!c) b &= ~0x40 & 0xff; a = ((c ^ b) & 0x3f) ^ b; }
  else { c++; if (c & 0x40) a = ((b | 0x7f) ^ 0x80) & 0xff; else a = ((c ^ b) & 0x3f) ^ b; }
  M.wr(0xFE9C, a);
  return true;
}
function overlap(M, ix, hl, de) {  // DEDD: Z (true) — персонаж задевает область; возвращает и высоту
  if (M.rd(ix + 0x0A)) return { z: false };
  if (!M.rd(ix + 2)) return { z: false };
  const { b, c } = P.size(M, ix);
  const H = hl >> 8, L = hl & 0xff, D = de >> 8, E = de & 0xff;
  const x = M.rd(ix + 6), y = M.rd(ix + 7);
  if (u8(x + c - 1) < L) return { z: false };
  if (u8(L + D - 1) < x) return { z: false };
  if (u8(H + E - 1) < y) return { z: false };
  if (u8(y + b - 1) < H) return { z: false };
  return { z: true, b };
}
function decd(hl) {                // DECD: адрес экрана -> (строка, столбец)
  const H = hl >> 8, L = hl & 0xff;
  const r = ((L << 3) | (L >> 5)) & 0xff;
  return ((((r ^ H) & 0xE7) ^ H) & 0x1f) << 8 | (L & 0x1f);
}
function water(M, hl, bc) {        // DE47: вода сдвигает картинку (вывод) и толкает персонажей
  M.wr(0xFE1A, 1);
  hl &= ~0xA000 & 0xffff;
  const t = decd(hl), de = bc;
  const up = !(M.rd(0xFE9C) & 0x80);
  for (const ix of [NINJA, YAMO, BRUCE]) {
    const o = overlap(M, ix, t, de);
    if (!o.z) continue;
    if (up) {                      // DEA6
      if (P.ceiling_above(M, ix)) continue;
      const f = u8(M.rd(ix + 4) - 2) & 6; M.wr(ix + 4, f);
      if (f !== 6) continue;
      M.dec(ix + 7);
      if (M.rd(ix + 7) >= 2) continue;
      M.wr(ix + 7, 2); M.wr(ix + 4, 0);
    } else {                       // DF60
      if (u8(M.rd(ix + 7) + o.b) >= 0x17) continue;
      const f = (M.rd(ix + 4) + 2) & 6; M.wr(ix + 4, f);
      if (f) continue;
      M.inc(ix + 7);
    }
  }
}
function strip(M, hl, ix) {        // DF9D
  if (!M.rd(hl)) return;
  if (M.rd(ix + 0)) { M.dec(ix + 0); return; }
  if (M.rd(ix + 1) < 4) return;
  M.wr(ix + 1, 0);
  let a = M.rd(ix + 4);
  if (!a) { M.wr(ix + 3, M.rd(u16(hl + 1))); a = 4; }
  else if (a === 4) a = 5;
  else {
    tile_redraw(M, M.rd(hl) << 8 | M.rd(ix + 3));
    M.inc(ix + 3);
    if (M.rd(u16(hl + 2)) < M.rd(ix + 3)) { M.wr(ix + 0, M.rd(u16(hl + 3))); M.wr(ix + 4, 0); return; }
    a = 4;
  }
  M.wr(ix + 4, a);
  tile_put(M, a, M.rd(hl) << 8 | M.rd(ix + 3));
}
function strips(M) { strip(M, 0x6030, 0xFE72); strip(M, 0x6034, 0xFE77); strip(M, 0x6038, 0xFE7C); }   // DF7A
function mover(M, ix) {            // DDA8
  let a;
  const at = () => M.rd(ix + 0) << 8 | M.rd(ix + 1);
  if (!(M.rd(ix + 4) & 1)) {
    if (M.rd(ix + 5) === 6) a = 7;
    else {
      tile_redraw(M, at());
      if (M.rd(ix + 1) >= M.rd(ix + 3)) { a = 6; M.wr(ix + 1, M.rd(ix + 2)); }
      else { M.inc(ix + 1); a = 6; }
    }
  } else {
    if (M.rd(ix + 5) === 7) a = 6;
    else {
      tile_redraw(M, at());
      if (M.rd(ix + 3) >= M.rd(ix + 1)) { a = 7; M.wr(ix + 1, M.rd(ix + 2)); }
      else { M.dec(ix + 1); a = 7; }
    }
  }
  M.wr(ix + 5, a);
  tile_put(M, a, at());
}
const SPREAD = { 0x19: 0xDA51, 0x28: 0xDA51, 0x1E: 0xDA57, 0x2D: 0xDA5D };
function crack(M, s) {             // D9E7
  const v = M.inc(s);
  if (v < 0x14) return;
  const hl = M.rd(s + 2) << 8 | M.rd(s + 1);
  if (v === 0x14) { tile_put(M, 8, hl); return; }
  if (v === 0x32) { tile_put(M, 0x20, hl); return; }
  if (v === 0x37) { tile_redraw(M, hl); M.wr(s, 0); return; }
  let de = SPREAD[v]; if (!de) return;
  let h = u8((hl >> 8) - 1), l = u8((hl & 0xff) - 1);
  for (let k = 0; k < 3; k++) { tile_put(M, M.rd(de), h << 8 | l); l = u8(l + 1); de++; }
  h = hl >> 8; l = u8((hl & 0xff) - 1);
  for (let k = 0; k < 3; k++) { tile_put(M, M.rd(de), h << 8 | l); l = u8(l + 1); de++; }
}
function cracks(M) { for (let s = 0xFE60, k = 0; k < 6; k++, s += 3) if (M.rd(s)) crack(M, s); }   // D9D7

// --- обработчики по адресам ---------------------------------------------------------------------------
const R = {};
R[0xD824] = () => {};
R[0xDAC4] = (M) => { M.ldar(); };                                   // BUGFIX: ловушка-сброс выключена
function flick(M, hl) {            // DA97
  let v = M.rd(0xFE38); if (!v) return;
  v = u8(v + 1) | 1; M.wr(0xFE38, v);
  tile_put(M, (v & 0x40) ? 0x79 : 0x53, hl);
}
R[0xDA94] = (M) => flick(M, 0x0F05);
R[0xDAAD] = (M) => flick(M, 0x0F1A);
const W = (list) => (M) => { if (water_phase(M)) for (const [hl, bc] of list) water(M, hl, bc); strips(M); };
R[0xDAB2] = W([[0xE091, 0x0312]]);
R[0xDACC] = W([[0xE09B, 0x0214]]);
R[0xDAFF] = W([[0xE801, 0x020F], [0xE08E, 0x0412], [0xE81D, 0x020F]]);
R[0xDADE] = (M) => {
  if (M.rd(0xFE99) >= 3) { M.wr(0xFE99, 0); mover(M, 0xDAF9); }
  cracks(M); strips(M);
};
R[0xDB23] = (M) => {
  if (water_phase(M)) for (const [hl, bc] of [[0xE8A1, 0x0204], [0xE863, 0x0204], [0xE825, 0x0204], [0xE0E7, 0x0204],
    [0xE0E9, 0x0202], [0xE874, 0x0206], [0xE836, 0x0206], [0xE0F8, 0x0206], [0xE0FA, 0x0204], [0xE09D, 0x0213]]) water(M, hl, bc);
  if (M.rd(0xFE99) < 2) { strips(M); return; }
  M.wr(0xFE99, 0);
  mover(M, M.rd(0xFE3A) === 2 ? 0xDBAA : 0xDBA4);
};
R[0xDBB0] = (M) => {               // смена цвета воды: тайлы в 6128.. через C2B8
  const v = M.inc(0xFE38);
  let de;
  if (v === 0x40) de = 0x206C; else if (v === 0xC0) de = 0x6C20; else return;
  for (const [base, t] of [[0xF928, de >> 8], [0xF930, de & 0xff]]) {
    let a = base;
    for (let k = 0; k < 6; k++) { M.wr(u16(a + 0x6800), t); a = u16(a + 1); }
    M.wr16(0xFEA8, a);
  }
  M.wr(0xFE0B, 1);
};
R[0xD9D7] = cracks;
R[0xDBEC] = (M) => { cracks(M); strips(M); };
R[0xDBF2] = (M) => {
  if (water_phase(M)) water(M, 0xE081, 0x0413);
  cracks(M);
  const a = M.rd(0xCCAB);
  if (a < 8 || a >= 0x1B) return;
  if (M.rd(0xCCAC) !== 0x0D) return;
  if (M.rd(0xCCA9)) return;
  M.wr(0xFE0C, 1);
};
R[0xDC1D] = (M) => { M.wr(0xFE95, M.rd(0xFE95) | 0xC0); cracks(M); };
R[0xDC27] = (M) => {
  const walls = (v) => { for (const a of [0xFA5D, 0xFA7D, 0xFA9D, 0xFABD, 0xFADD]) M.wr16(a, v); M.wr(0xFE0B, 1); };
  for (;;) {
    const a = M.rd(0xFE95);
    if (!a) break;
    if (a === 0xC0) { M.wr(0xFE95, 0); walls(0); break; }
    M.wr(0xFE95, a & ~0x40 & 0xff);
    if (!(a & 0x80)) break;
    if (a & 0x40) { walls(0x8686); break; }
    if (M.rd(0xCCAC) < 0x11 || M.rd(0xCCAB) !== 0x1A) break;
    const n = M.rd(0xFE95) & 7;
    if (!n) break;
    M.wr(0xFE95, n - 1);
    require('./game').lives_up(M);
    walls(0); break;
  }
  cracks(M);
};
R[0xDC78] = (M) => {
  if (M.rd(0xFE99) < 3) return;
  M.wr(0xFE99, 0);
  for (let ix = 0xDCBE; ix <= 0xDCE8; ix += 6) mover(M, ix);
};
R[0xDCEE] = (M) => {
  if (M.rd(0xFE99) >= 3) { M.wr(0xFE99, 0); mover(M, 0xDD07); }
  strips(M);
};
R[0xDD0D] = (M) => {               // осыпание
  let a = M.rd(0xFE3C);
  if (!a) {
    M.wr16(0xFE17, 0x0810);
    const x = M.rd(0xCCAB); let b = 0xFF;
    if (x >= 0x0A) { b = 0; if (x >= 0x12) b = 1; }
    M.wr(0xFE19, b); M.wr(0xFE3C, 1); return;
  }
  a = M.inc(0xFE3C);
  if (a < 0x1E) return;
  let hl = M.rd16(0xFE17);
  tile_redraw(M, hl);
  if ((hl >> 8) >= 0x15) { M.wr(0xFE3C, 0); return; }
  hl = u8((hl >> 8) + 1) << 8 | u8((hl & 0xff) + M.rd(0xFE19));
  M.wr16(0xFE17, hl);
  const save = M.rd16(0x6000);
  M.wr16(0x6000, 0x9EA8); tile_put(M, 0, hl); M.wr16(0x6000, save);
};
R[0xDD67] = (M) => require('./game').level_complete(M);
R[0xDA63] = (M, de) => {           // клетка 17h: новая трещина
  const o = u16(de - 0x6000), rc = ((o >> 5) & 0x1f) << 8 | (o & 0x1f);
  for (let s = 0xFE60, k = 0; k < 6; k++, s += 3) {
    if (M.rd(s)) continue;
    M.inc(s); M.wr(s + 1, rc & 0xff); M.wr(s + 2, rc >> 8);
    tile_put(M, 0x20, rc); return;
  }
};
// после подбора предмета (D7D4): de = (строка, столбец)
const cnt = (M, a) => M.inc(a);
R[0xD845] = (M) => { if (cnt(M, 0xFE20) === 0x15) will_apply(M, 1, 0x170F); };
R[0xD856] = (M, de) => {
  const D = de >> 8, E = de & 0xff;
  if (D < 0x10) { if (E < 0x1B) return; M.wr(0xFE38, 1); will_apply(M, 2, 0x111F); return; }
  const v = cnt(M, 0xFE22);
  if (v === 4) will_apply(M, 4, 0x1200); else if (v === 2) will_apply(M, 4, 0x1112);
};
R[0xD888] = (M) => { if (cnt(M, 0xFE36) === 8) will_apply(M, 5, 0x0300); };
R[0xD898] = (M, de) => {
  if ((de >> 8) < 0x0F) {
    const v = cnt(M, 0xFE24);
    if (v === 5) will_apply(M, 6, 0x031B); else if (v === 0x0A) will_apply(M, 6, 0x091F);
    return;
  }
  if (cnt(M, 0xFE26) < 2) return;
  M.wr(0xDAFB, 0x1C); M.wr(0xDAFC, 5); M.wr(0xDAFD, 1);
  will_apply(M, 7, 0x0B0B);
};
R[0xD8D4] = (M, de) => {
  const E = de & 0xff;
  if (E < 6) { M.wr(0xDAFB, 5); M.wr(0xDAFC, 0x1C); M.wr(0xDAFD, 0); will_apply(M, 7, 0x1100); return; }
  if (E >= 0x15) return;
  if (cnt(M, 0xFE28) < 2) return;
  M.wr16(0xFE9B, 0xC810);
  will_apply(M, 7, 0x0B14);
};
R[0xD902] = (M, de) => {
  const D = de >> 8, E = de & 0xff;
  if (D < 6) { M.wr16(0xFE9B, 0xC810); return; }
  if (D < 0x11) return;
  if (E >= 0x19) { M.wr16(0xFE9B, 0x4810); return; }
  if (cnt(M, 0xFE3A) !== 2) return;
  M.wr(0xDBAB, M.rd(0xDBA5));
  will_apply(M, 7, 0x031F);
};
R[0xD928] = (M) => { if (cnt(M, 0xFE2A) >= 2) will_apply(M, 9, 0x1718); };
R[0xD938] = (M) => { if (cnt(M, 0xFE2C) === 3) will_apply(M, 0x0A, 0x041F); };
R[0xD948] = (M) => { if (cnt(M, 0xFE2E) === 3) will_apply(M, 0x0C, 0x0B1F); };
R[0xD958] = (M, de) => {
  if ((de >> 8) < 0x10) { if (cnt(M, 0xFE30) === 2) will_apply(M, 0x0D, 0x041F); }
  else if (cnt(M, 0xFE32) === 2) will_apply(M, 0x0D, 0x121F);
};
R[0xD97D] = (M) => { if (cnt(M, 0xFE34) === 2) will_apply(M, 0x0E, 0x0B00); };
R[0xD98D] = (M) => {               // подбор оружия: очки, вспышка ~255 кадров (вывод), FE0C = 1
  const out = require('./out');
  require('./game').add_score(M, 0xC995);
  M.wr(0xFE3C, 0);
  out.pers_draw(M, BRUCE);
  out.screen_copy(M);
  M.wr(0xFE3C, 0xFF);
  M.wr(0xFE0C, 1);
};

// C16E: загрузка комнаты FE03 (логика; рисование — только служебные ячейки)
function room_load(M) {
  const game = require('./game');
  const room = M.rd(0xFE03);
  const desc = M.rd16(0x6400 | u8(room * 2));
  for (let k = 0; k < 0x40; k++) M.wr(0x6000 + k, M.rd(u16(desc + k)));
  M.wr(u16(desc + 0x0C + (M.rd(0xFE04) === 1 ? 0 : 1)), 1);
  let hl = u16(desc + 0x40), de = 0x6040;
  for (;;) {
    const a = M.rd(hl);
    if (!a) break;
    if (a & 0x80) { let n = a & 0x7f; hl = u16(hl + 1); for (let k = n || 0x10000; k > 0 && n; k--) { M.wr(de, M.rd(hl)); de = u16(de + 1); hl = u16(hl + 1); } }
    else { hl = u16(hl + 1); const v = M.rd(hl); for (let k = a; k > 0; k--) { M.wr(de, v); de = u16(de + 1); } hl = u16(hl + 1); }
  }
  for (let k = 0; k < 0x300; k++) M.wr(0x5D00 + k, M.rd(0x6000 + k));
  // ключи и предметы комнаты
  hl = M.rd16(0x6006);
  for (;;) {
    let v = M.rd(hl);
    if (v & 0x80) {
      if (v === 0xFF) break;
      if (!(M.rd(0xFE04) & v)) {
        hl = u16(hl + 1);
        do hl = u16(hl + 3); while (!(M.rd(hl) & 0x80));
        continue;
      }
      hl = u16(hl + 1);
    }
    const a = M.rd(hl); hl = u16(hl + 1);
    let b = M.rd(hl); b = ((b >> 3) | (b << 5)) & 0xff;
    const c = ((a ^ b) & 0x1f) ^ b; b &= 3;
    hl = u16(hl + 1);
    M.wr(0x6000 + (b << 8 | c), M.rd(hl));
    hl = u16(hl + 1);
  }
  M.wr16(0xFEA6, 0x6300); M.wr16(0xFEA8, 0xFB00);          // рисование сцены (C1F8): итоговые указатели
  M.wr(0xFE02, 0);
  for (const a of [0xCB1E, 0xCBC0, 0xCB20, 0xCBC2, 0xCCA9, 0xCB2A, 0xCBCC, 0xCCB3, 0xCB26, 0xCBC8, 0xCCAF, 0xCB2D, 0xCBCF, 0xCCB6]) M.wr(a, 0);
  M.wr(0xCCA7, 1);
  for (let k = 0; k < 0x0F; k++) M.wr(0xFE72 + k, 0);
  for (let k = 0; k < 0x12; k++) M.wr(0xFE60 + k, 0);
  if (room !== 0 && room !== 0x13 && !M.rd(0x600C + (M.rd(0xFE04) === 1 ? 0 : 1))) game.add_score(M, 0xC98F);
  const a = M.rd(0xFE0D) ? 0x0A : 0x28;
  M.wr(0xCB2C, a); M.wr(0xCBCE, a);
  M.wr16(0xFE05, 0);
  M.wr16(0xFE9B, 0x4810);
  require('./out').screen_copy(M);
}

module.exports = { tile_put, tile_redraw, dispatch, will_apply, room_load, R, water_phase, water, strips, mover, cracks, crack, decd, overlap };
