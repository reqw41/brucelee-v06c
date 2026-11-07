// Персонажи: шаг (D24E), обработчики состояний, проверки клеток, удары, ИИ (D675), касание объектов (D4EC).
// Перевод с листинга ZX один к одному по смыслу; регистры — аргументы и результаты, флаги — булевы.
'use strict';
const NINJA = 0xCB1C, YAMO = 0xCBBE, BRUCE = 0xCCA5;
const u8 = (v) => v & 0xff, u16 = (v) => v & 0xffff;
const dir = (M, ix) => M.rd(ix + 3) & 1;

// D4A3: адрес клетки персонажа в 6000 (Y*32+X)
function cell(M, ix) { const x = M.rd(ix + 6), y = M.rd(ix + 7); return 0x6000 + (((y & 0x1f) << 5) | (x & 0x1f)); }
// D4BE: размер картинки: FEAC = описатель, FEA4 = ширина (C), FEA5 = высота (B)
function size(M, ix) {
  const off = u8((M.rd(ix + 2) - 1) * 4 + 0x16);
  const desc = M.rd16(u16(ix + off));
  M.wr16(0xFEAC, desc);
  const c = M.rd(desc), b = M.rd(u16(desc + 1));
  M.wr(0xFEA4, c); M.wr(0xFEA5, b);
  return { b, c, desc };
}
const n256 = (v) => v || 256;

// D332: пол под ногами — Z
function floor_below(M, ix) {
  let hl = cell(M, ix);
  const { b, c } = size(M, ix);
  hl = u16(hl + 0x20 * n256(b));
  for (let k = n256(c); k > 0; k--) {
    const a = M.rd(hl);
    if (a >= 0x40) return true;
    if (a < 0x20 && a >= 0x18) return true;
    hl = u16(hl + 1);
  }
  return false;
}
// D353: потолок над головой — Z
function ceiling_above(M, ix) {
  if (M.rd(ix + 7) < 3) return true;
  let hl = u16(cell(M, ix) - 0x20);
  const { c } = size(M, ix);
  for (let k = n256(c); k > 0; k--) { if (M.rd(hl) >= 0x40) return true; hl = u16(hl + 1); }
  return false;
}
// D405: верёвка/лестница под персонажем — { z, a }
function rope_under(M, ix) {
  let hl = cell(M, ix);
  let { b, c } = size(M, ix);
  const d = u8(c - 1);
  if (M.rd(ix + 4)) b = u8(b + 1);
  let e = 0;
  for (let rows = n256(b); rows > 0; rows--) {
    e = 0;
    for (let k = n256(c); k > 0; k--) {
      const a = M.rd(hl);
      if (a < 0x20 && a >= 0x18) { e++; if (e === 2) return { z: true, a: 2 }; }
      hl = u16(hl + 1);
    }
    if (e === d) return { z: true, a: e };
    c = M.rd(0xFEA4);
    hl = u16(hl + u8(0x20 - c));
  }
  return { z: false, a: e };
}
// D462: край комнаты — Z для Ниндзя и Ямо
const edge = (ix) => ix === NINJA || ix === YAMO;
// D479: столбец клеток высотой b (+1 в середине кадра) — Z, если твёрдое
function wallScan(M, ix, hl, b) {
  if (M.rd(ix + 4)) b = u8(b + 1);
  for (let k = n256(b); k > 0; k--) { if (M.rd(hl) >= 0x40) return true; hl = u16(hl + 0x20); }
  return false;
}
// D45C: препятствие слева — Z
function obst_left(M, ix) {
  if (M.rd(ix + 6) === 0) return edge(ix);
  const hl = u16(cell(M, ix) - 1);
  const { b } = size(M, ix);
  return wallScan(M, ix, hl, b);
}
// D48F: препятствие справа — Z
function obst_right(M, ix) {
  let hl = cell(M, ix);
  const { b, c } = size(M, ix);
  if (u8(M.rd(ix + 6) + c) >= 0x20) return edge(ix);
  return wallScan(M, ix, u16(hl + c), b);
}
// D456: препятствие по направлению взгляда
const obst_ahead = (M, ix) => (dir(M, ix) ? obst_left(M, ix) : obst_right(M, ix));
// D43B / D447: препятствие или край комнаты
function obst_left_edge(M, ix) { if (obst_left(M, ix)) return true; const x = M.rd(ix + 6); return x === 0 || x === 1; }
function obst_right_edge(M, ix) { if (obst_right(M, ix)) return true; return u8(M.rd(0xFEA4) + M.rd(ix + 6)) >= 0x20; }

// D007: следующий шаг дуги прыжка/падения
function arc(M, ix) { const c = M.inc(ix + 0x0C); const a = M.rd(0xD018 + c); M.wr(ix + 4, a); return a; }

// CEE9: щелчок шагов Брюса (звук включён)
function click(M, ix, a) {
  if (ix === BRUCE && M.rd(0xFE9A)) { const v = M.rd(0x600B) ^ 0x10; M.wr(0x600B, v); M.outFE(v); }
  return a;
}

// --- обработчики состояний (адрес -> функция(M, ix, a) -> новое состояние) -----------------------------
const H = {};
H[0xCB8A] = (M, ix, a) => a;
H[0xCD9B] = (M, ix) => {
  M.wr(ix + 0x0C, 0); M.wr(ix + 0x0D, 0);
  if (ix !== NINJA) {
    const a = M.rd(ix + 0x0B);
    if (a === 9) { M.wr(ix + 3, 0); return click(M, ix, 2); }
    if (a === 0x0A) { M.wr(ix + 3, 1); return click(M, ix, 2); }
  }
  if (!floor_below(M, ix)) return cdcd(M, ix);
  const a = M.rd(ix + 0x0B);
  if (a === 0x10) {
    if (obst_ahead(M, ix)) return 1;
    if (dir(M, ix)) M.dec(ix + 6);
    return 0x16;
  }
  if (a === 1) { if (!dir(M, ix)) return 2; M.wr(ix + 3, 0); return 1; }
  if (a === 2) { if (dir(M, ix)) return 2; M.wr(ix + 3, 1); return 1; }
  if (a === 8) return 0x0C;
  if (a !== 4) return 1;
  if (ix !== BRUCE) return 1;
  if (obst_right(M, ix)) { if (obst_left(M, ix)) return 1; M.dec(ix + 6); }
  M.inc(ix + 7); M.inc(ix + 7);
  return 8;
};
function cdcd(M, ix) {           // CDCD: нет пола — верёвка?
  if (rope_under(M, ix).z) return 0x0E;
  if (ix !== NINJA) M.wr(ix + 3, 1);
  return 0x11;
}
H[0xCE48] = (M, ix) => {
  M.wr(ix + 0x0C, 0);
  if (!floor_below(M, ix)) return cdcd(M, ix);
  if (!dir(M, ix)) {
    if (obst_right(M, ix)) return 1;
    let a = M.rd(ix + 0x0B);
    const go = () => { M.inc(ix + 6); return click(M, ix, 3); };
    if (a === 1) return go();
    if (ix === NINJA) return 1;
    a = M.rd(ix + 0x0B);
    if (a === 0x11) { if (M.rd(ix + 0x0D) < 2) return go(); if (obst_right(M, ix)) return 1; return 4; }
    if (a !== 9) return 1;
    if (ceiling_above(M, ix)) return go();
    M.dec(ix + 7); M.wr(ix + 4, 7); return 0x0A;
  }
  if (obst_left(M, ix)) return 1;
  let a = M.rd(ix + 0x0B);
  const go = () => { M.dec(ix + 6); return click(M, ix, 3); };
  if (a === 2) return go();
  if (ix === NINJA) return 1;
  a = M.rd(ix + 0x0B);
  if (a === 0x12) { if (M.rd(ix + 0x0D) < 2) return go(); if (obst_left(M, ix)) return 1; M.dec(ix + 6); return 4; }
  if (a !== 0x0A) return 1;
  if (ceiling_above(M, ix)) return go();
  M.dec(ix + 6); M.dec(ix + 7); M.wr(ix + 4, 7); return 0x0A;
};
H[0xCF04] = (M, ix) => {
  if (floor_below(M, ix)) { M.inc(ix + 0x0D); return 2; }
  return rope_under(M, ix).z ? 0x0E : 0x11;
};
H[0xCF18] = (M, ix) => { melee(M, ix, NINJA, 8); melee(M, ix, YAMO, 8); melee(M, ix, BRUCE, 8); return 5; };
H[0xCF2D] = (M, ix) => {
  const c = M.inc(ix + 0x0C);
  const stop = () => { M.wr(ix + 0x0D, 0); return 2; };
  if (c >= 4) return stop();
  if (!dir(M, ix)) { if (obst_right(M, ix)) return stop(); M.inc(ix + 6); return 4; }
  if (obst_left(M, ix)) return stop();
  M.dec(ix + 6); return 4;
};
H[0xCF59] = (M, ix) => {
  M.wr(ix + 4, 0);
  if (!floor_below(M, ix)) M.inc(ix + 7);
  if (M.rd(ix + 0x0C) === 2) {
    M.wr(ix + 0, 0x14);
    if (!killcheck(M, ix)) { M.wr(ix + 0x0F, 6); return 6; }
    M.dec(ix + 7);
    if (ix === BRUCE) return 1;
    M.wr(ix + 0, 0x32); return 1;
  }
  M.wr(ix + 0, 3);
  const bump = () => { M.wr(ix + 0x0C, 2); return 6; };
  if (!dir(M, ix)) { if (obst_left_edge(M, ix)) return bump(); M.dec(ix + 6); return 7; }
  if (obst_right_edge(M, ix)) return bump();
  M.inc(ix + 6); return 7;
};
H[0xCFB3] = (M, ix) => { M.inc(ix + 0x0C); M.wr(ix + 0, 3); return 6; };
H[0xCFBD] = (M, ix) => { if (M.rd(ix + 0x0B) === 4) return 8; M.dec(ix + 7); M.dec(ix + 7); return 1; };
H[0xCFCE] = (M, ix) => {
  const land = () => { M.inc(ix + 7); M.wr(ix + 4, 0); return click(M, ix, 2); };
  if (arc(M, ix) === 0) return land();
  if (!dir(M, ix)) { if (obst_right(M, ix)) return land(); return 0x0A; }
  if (obst_left(M, ix)) return land();
  M.dec(ix + 6); return 0x0A;
};
H[0xCFF8] = (M, ix) => { arc(M, ix); if (!dir(M, ix)) M.inc(ix + 6); return 9; };
H[0xD023] = (M, ix) => { M.wr(ix + 0, 0x0A); if (!dir(M, ix)) return 1; M.inc(ix + 6); return 1; };
H[0xD032] = (M, ix) => { M.wr(ix + 0, 6); return ceiling_above(M, ix) ? 1 : 0x12; };
H[0xD03F] = (M, ix) => {
  if (arc(M, ix) === 0) { M.inc(ix + 7); M.wr(ix + 0, 7); return 1; }
  if (M.rd(ix + 0x0C) === 3 && rope_under(M, ix).z) { M.wr(ix + 4, 0); return 0x0E; }
  return 0x0D;
};
function climb(M, ix, saved) {   // D066
  if (!rope_under(M, ix).z) {
    const a = M.rd(ix + 4); M.wr(ix + 4, 0);
    if (a) M.inc(ix + 7);
    return 0x11;
  }
  const fin = (s) => { M.wr(ix + 3, (M.rd(ix + 3) ^ 1) & 1); M.wr(ix + 0, 8); return click(M, ix, s); };   // D090
  const a = M.rd(ix + 0x0B);
  if (a === 8) {
    let f = M.rd(ix + 4), v;
    if (f < 4) {
      if (ceiling_above(M, ix)) { M.wr(ix + 4, 0); return fin(saved); }
      f = M.rd(ix + 4);
    }
    v = u8(f - 4); if (f < 4) M.dec(ix + 7);
    M.wr(ix + 4, v & 6);
    return fin(saved);
  }
  if (a === 4) {
    const { b } = size(M, ix);
    if (u8(M.rd(ix + 7) + b) >= 0x17) return fin(saved);
    const f = (M.rd(ix + 4) + 4) & 4; M.wr(ix + 4, f);
    if (!f) M.inc(ix + 7);
    return fin(saved);
  }
  if (a === 1) {
    if (saved === 0x0F) { M.inc(ix + 6); return fin(0x0E); }
    if (obst_right(M, ix)) return fin(0x0E);
    return fin(0x0F);
  }
  if (a === 2) {
    if (saved === 0x0F) return fin(0x0E);
    if (obst_left(M, ix)) return fin(0x0E);
    M.dec(ix + 6); return fin(0x0F);
  }
  M.wr(ix + 0, 8); return saved;
}
H[0xD063] = (M, ix) => climb(M, ix, M.rd(ix + 2));
H[0xD10D] = (M, ix) => climb(M, ix, 0x0F);
H[0xD112] = (M, ix) => {
  const rec = (a) => { M.wr(ix + 4, a); M.wr(ix + 0, 2); return 0x11; };
  let a = M.rd(ix + 4);
  if (a) { a = (a + 2) & 6; if (!a) M.inc(ix + 7); return rec(a); }
  if (!floor_below(M, ix)) return rec(2);
  if (ix === BRUCE) {
    const bc = M.rd16(0xCCAB);
    if (M.rd16(0xCB22) === bc || M.rd16(0xCBC4) === bc) require('./game').add_score(M, 0xC96B);
  }
  M.wr(ix + 0, 6); return click(M, ix, 1);
};
H[0xD15D] = (M, ix) => { M.dec(ix + 7); M.wr(ix + 4, 7); M.wr(ix + 3, 0); M.wr(ix + 0x0C, 0); return 0x0D; };
H[0xD16F] = (M, ix) => {
  if (M.rd(ix + 0x0E) >= 0x0A) return H[0xD1A2](M, ix);
  M.wr(ix + 0, 0x0A);
  if (!dir(M, ix)) { if (obst_left_edge(M, ix)) return 1; M.dec(ix + 6); return 0x14; }
  if (obst_right_edge(M, ix)) return 1;
  M.inc(ix + 6); return 0x14;
};
H[0xD198] = (M, ix) => { killcheck(M, ix); M.wr(ix + 0x0F, 1); return 1; };
H[0xD1A2] = (M, ix) => {
  M.wr(ix + 0x0C, 0); M.wr(ix + 0, 3);
  if (!dir(M, ix)) { if (obst_left_edge(M, ix)) return H[0xD198](M, ix); M.dec(ix + 6); }
  else if (obst_right_edge(M, ix)) return H[0xD198](M, ix);
  M.wr(ix + 2, 6);
  if (!floor_below(M, ix)) M.inc(ix + 7);
  M.wr(ix + 4, 0); return 6;
};
H[0xD1D2] = (M, ix) => { melee(M, ix, NINJA, 9); melee(M, ix, YAMO, 9); melee(M, ix, BRUCE, 9); M.wr(ix + 0, 0x0F); return 0x0B; };

// D1EB: накоплен урон — гибель и очки; CY = выжил (true)
function killcheck(M, ix) {
  const game = require('./game');
  const e = M.rd(ix + 0x0E);
  if (e >= 0x35 || (ix === NINJA && e >= 0x23)) {
    M.wr(ix + 0x0A, 1); M.wr(ix + 0x0E, 0);
    if (ix !== BRUCE) {
      if (!M.rd(ix + 0x11)) return false;
      game.add_score(M, ix === NINJA ? 0xC983 : 0xC989);
    }
    M.wr(ix + 0x11, 0); return false;
  }
  if (ix !== BRUCE) {
    const a = M.rd(ix + 0x11);
    if (a) game.add_score(M, a === 8 ? 0xC971 : 0xC977);
  }
  M.wr(ix + 0x11, 0); return true;
}
// D375/D371: удар по соседу iy, урон d
function melee(M, ix, iy, d) {
  if (ix === iy) return;
  if (M.rd(iy + 0x0A) || !M.rd(iy + 2)) return;
  const a = M.rd(ix + 7), ty = M.rd(iy + 7);
  if (a !== ty && u8(a - 1) !== ty) return;
  const x = M.rd(ix + 6), tx = M.rd(iy + 6);
  if (!dir(M, ix)) { if (u8(x + 1) !== tx && u8(x + 2) !== tx) return; M.wr(iy + 3, 1); }
  else { if (x !== tx && u8(x - 1) !== tx) return; M.wr(iy + 3, 0); }
  let v = u8(M.rd(iy + 0x0E) + d); M.wr(iy + 0x0E, v);
  if (ix !== NINJA) M.wr(iy + 0x0E, u8(v + d));
  M.wr(iy + 2, 0x13); M.wr(iy + 0, 1);
  if (M.rd(0xFE9A)) require('./sound').hit(M);
  if (ix === BRUCE) M.wr(iy + 0x11, d);
  if (d === 8) M.wr(ix + 0x0C, 3);
}

// D2EB: возвращение врага после гибели
function revive(M, ix) {
  if (ix === BRUCE) return;
  const hl = M.rd(0xCCAC) >= 0x12 ? 0x600A : 0x602F;
  if (M.rd(hl) & 0x80) return;
  if (M.dec(ix + 0x10)) return;
  M.wr(ix + 3, M.rd(hl) & 1); M.wr(ix + 7, M.rd(hl - 1)); M.wr(ix + 6, M.rd(hl - 2));
  M.wr(ix + 0, 1); M.wr(ix + 2, 1); M.wr(ix + 4, 0); M.wr(ix + 0x0A, 0);
  if (ix === YAMO) M.wr(ix + 0, 0x4B);
}

// D587: касание по точкам: тайл в клетке hl против кадра спрайта (байт de) — true, если касается
function pix_collide(M, ix, hl, de) {
  let bc = u16(M.rd(hl) * 8 + M.rd16(0x6000) + M.rd(ix + 4));
  let p = u16(M.rd(de) * 8 + (dir(M, ix) ? 0xA800 : 0xA000));
  for (;;) {
    if (M.rd(bc) & M.rd(p)) return true;
    p = (p & 0xff00) | u8(p + 1);
    bc = (bc & 0xff00) | u8(bc + 1);
    if (!(bc & 7)) return false;
  }
}
// D4EC: объекты под персонажем
function objects(M, ix) {
  const game = require('./game'), room = require('./room');
  let hl = cell(M, ix);
  let { b, c } = size(M, ix);
  let de = u16(M.rd16(0xFEAC) + 2);
  for (let rows = n256(b); rows > 0; rows--) {
    for (let k = n256(c); k > 0; k--) {
      const a = M.rd(hl);
      if (a === 0x17) room.dispatch(M, 0xD7FC, hl);
      else if (a < 0x10) {
        if (pix_collide(M, ix, hl, de)) { M.wr(ix + 0x0A, 1); M.wr(ix + 0x0F, M.rd(ix + 2)); }
      } else if (a < 0x17 && ix === BRUCE && pix_collide(M, ix, hl, de)) {
        game.add_score(M, 0xC97D);
        if (M.rd(0xFE9A)) require('./sound').play(M, 'snd_key', 0x9346, 0x00, 0xD3);
        const off = u16(hl - 0x6000), rc = ((off >> 5) << 8) | (off & 0x1f);
        room.will_apply(M, M.rd(0xFE03), rc);
        room.dispatch(M, 0xD7D4, rc);
      }
      hl = u16(hl + 1); de = u16(de + 1);
    }
    c = M.rd(0xFEA4);
    hl = u16(hl + u8(0x20 - c));
  }
}

// D675: желаемое действие (ИИ врагов; Брюс — ввод)
function ai(M, ix) {
  const inp = M.rd(0xFE11);                           // читается для всех (до RET Z)
  if (ix === BRUCE) return inp;
  if (M.rd(0xFE08) && ix === YAMO) {
    if (M.rd(0xFE06) >= 6) M.wr(0xFE06, 6);
    else { const a = M.rd(0xFE12); if (!a) return 0; M.wr(0xFE06, 0); return a; }
  }
  const st = M.rd(ix + 2);
  const bx = () => M.rd(0xCCAB), by = () => M.rd(0xCCAC);
  const turn = () => { M.wr(ix + 3, M.rd(ix + 3) ^ 1); M.wr(ix + 0, 0x32); return 0; };          // D734
  const walk = () => (obst_ahead(M, ix) ? 0 : (dir(M, ix) ? 2 : 1));                            // D726
  const face = () => {                                                                         // D710
    if (bx() < M.rd(ix + 6)) return dir(M, ix) ? walk() : turn();
    return dir(M, ix) ? turn() : walk();
  };
  const near = () => {                                                                         // D6DD
    let a = u8(bx() - 2); const x = M.rd(ix + 6);
    if (a === x) { M.wr(ix + 3, 0); return 0x10; }
    a = u8(a - 2); if (a === x) return 0x11;
    a = u8(a + 6); if (a === x) { M.wr(ix + 3, 1); return 0x10; }
    a = u8(a + 2); if (a === x) return 0x12;
    return face();
  };
  if (st >= 4) {
    if (st < 0x0C || st >= 0x10) return 0;
    if (ceiling_above(M, ix)) return face();
    if (M.rd(ix + 4) || obst_left(M, ix) || obst_right(M, ix)) return 8;
    const a = by(), y = M.rd(ix + 7);
    if (a === y) return near();
    if (a > y) return face();
    return 8;
  }
  if (by() === M.rd(ix + 7)) return near();
  // D742
  if (u8(by() + 1) < M.rd(ix + 7) && ix === YAMO) {
    M.dec(ix + 7);
    const r = rope_under(M, ix);
    if (r.z && r.a === 2) { M.inc(ix + 7); return 8; }
    M.inc(ix + 7);
  }
  if ((M.ldar() & 3) === 0) {
    const hl = ix === NINJA ? M.rd16(0xCBC4) : M.rd16(0xCB22);
    if (M.rd(ix + 7) === hl >> 8) {
      let a = u8(M.rd(ix + 6) - 2);
      if (a === (hl & 0xff)) { M.wr(ix + 3, 1); return 0x10; }
      a = u8(a + 4);
      if (a === (hl & 0xff)) { M.wr(ix + 3, 0); return 0x10; }
    }
  }
  if (obst_ahead(M, ix)) return turn();
  return dir(M, ix) ? 2 : 1;
}

// D24E: шаг персонажа
function step(M, ix) {
  let a = M.rd(ix + 0x0A);
  if (a) {
    a = M.inc(ix + 0x0A);
    if (a === 2 && M.rd(0xFE9A)) {                      // D271
      if (ix === BRUCE) { M.wr(ix + 0x0A, 0x4B); require('./sound').play(M, 'snd_die', 0x933A, 0x00, 0xD3); }
      M.wr(ix + 2, M.rd(ix + 0x0F)); return;
    }
    M.wr(ix + 2, (a & 2) ? 0 : M.rd(ix + 0x0F));        // D264
    return;
  }
  if (M.dec(ix + 0)) return;
  M.wr(ix + 0, M.rd(ix + 1));
  if (!M.rd(ix + 2)) { revive(M, ix); return; }
  M.wr(ix + 0x0B, ai(M, ix));
  objects(M, ix);
  const idx = M.rd(ix + 2);
  const handler = M.rd16(u16(ix + u8((idx - 1) * 4 + 0x18)));
  const x0 = M.rd(ix + 6), y0 = M.rd(ix + 7);
  const h = H[handler];
  if (!h) throw new Error('модель: нет обработчика ' + handler.toString(16));
  M.wr(ix + 2, h(M, ix, idx));
  let x = Math.min(M.rd(ix + 6), x0); if (x >= 0x1D) x = 0x1C;
  M.wr(ix + 8, x);
  let y = Math.min(M.rd(ix + 7), y0); if (y >= 0x14) y = 0x13; if (y < 2) y = 2;
  M.wr(ix + 9, y);
}

// CAF7: упал за низ экрана — начать гибель
function fell(M, ix) {
  cell(M, ix); size(M, ix);
  if (u8(M.rd(0xFEA5) + M.rd(ix + 7)) < 0x17) return;
  if (M.rd(ix + 4) < 4) return;
  if (M.rd(ix + 0x0A)) return;
  M.wr(ix + 0x0F, M.rd(ix + 2)); M.wr(ix + 0x0A, 0x5F);
}
// CAE2: конец мигания — убрать, завести отсчёт возвращения
function expire(M, ix) {
  if (M.rd(ix + 0x0A) < 0x64) return;
  M.wr(ix + 2, 0); M.wr(ix + 0x0A, 0); M.wr(ix + 0x10, 0x32);
}

module.exports = { NINJA, YAMO, BRUCE, cell, size, floor_below, ceiling_above, rope_under, obst_left, obst_right,
  obst_ahead, obst_left_edge, obst_right_edge, arc, click, H, killcheck, melee, revive, pix_collide, objects, ai, step,
  fell, expire, u8, u16, n256 };
