// Вывод ZX, сведённый к тому, что остаётся в сравниваемой памяти: служебные указатели FEA0–FEA9,
// FE96/FE97, флаг FE0B и запись бордюра в порт FE. Экран и теневой экран не моделируются.
'use strict';
const { u8, u16, n256 } = require('./pers');

const attrOf = (x, y) => 0xF800 + ((((y & 0x1f) << 5) | (x & 0x1f)) & 0x3ff);

// C29C: копия экрана: OUT (FE) из 600B, FE0B = 0
function screen_copy(M) { M.outFE(M.rd(0x600B)); M.wr(0xFE0B, 0); }

// C366: стереть персонажа (фон из 6800+FEA8 в теневой экран)
function pers_erase(M, ix) {
  const idx = M.rd(ix + 2);
  if (!idx) return;
  const desc = M.rd16(u16(ix + u8((idx - 1) * 4 + 0x16)));
  const b = M.rd(desc);
  let c = 5; const a = u8(0x18 - M.rd(ix + 7)); if (a < 5) c = a;
  M.wr(0xFEA4, c); M.wr(0xFEA5, b);
  let p = attrOf(M.rd(ix + 6), M.rd(ix + 7));
  for (let r = n256(c); r > 0; r--) {
    p = u16(p + n256(M.rd(0xFEA5)));
    p = u16(p + u8(0x20 - M.rd(0xFEA5)));
  }
  M.wr16(0xFEA8, p);
}
// C3CB: нарисовать персонажа в теневой экран
function pers_draw(M, ix) {
  const idx = M.rd(ix + 2);
  if (!idx) return;
  M.wr16(0xFEA2, (M.rd(ix + 3) & 1) ? 0xA800 : 0xA000);
  M.wr(0xFE96, M.rd(ix + 4)); M.wr(0xFE97, M.rd(ix + 5));
  const desc = M.rd16(u16(ix + 5 + u8((idx - 1) * 4 + 0x11)));
  let p = attrOf(M.rd(ix + 6), M.rd(ix + 7));
  const c = M.rd(desc), b = M.rd(u16(desc + 1));
  M.wr(0xFEA4, c); M.wr(0xFEA5, b);
  for (let r = n256(b); ; ) {
    p = u16(p + n256(M.rd(0xFEA4)));
    if (--r === 0) break;
    p = u16(p + u8(0x20 - M.rd(0xFEA4)));
  }
  M.wr16(0xFEA0, p);
}
module.exports = { screen_copy, pers_erase, pers_draw, attrOf };
