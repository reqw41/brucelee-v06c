// Сверка экрана Вектора с композицией disp (src/vec/render.asm): тайл + атрибут amap (мигание по flash_ph),
// персонажи — кадры CPC (решение владельца 05.11.2026): точка своего цвета (Ямо 4, Брюс 6) или чёрная (1),
// Ниндзя, Ямо, затем Брюс поверх. -> { bad: клеток с расхождениями, cells: [[r, c, ждали, есть]] }
'use strict';
function make(m, sym) {
const pix = (x, y) => { const a = ((x >> 3) << 8) | (255 - y), b = 7 - (x & 7); return ((m.rd(0xA000 + a) >> b) & 1) << 2 | ((m.rd(0xC000 + a) >> b) & 1) << 1 | ((m.rd(0xE000 + a) >> b) & 1); };
function compose() {
  const gfx = m.rd(0x6000) | m.rd(0x6001) << 8, fl = m.rd(sym.flash_ph);
  const spr = new Int8Array(256 * 192).fill(-1);   // -1 нет персонажа, иначе номер цвета (Ниндзя, Ямо, Брюс — Брюс поверх)
  const COLY = [0, 4, 6];
  for (let i = 0; i < 3; i++) {
    const d = sym.disp + 8 * i; if (!m.rd(d)) continue;
    const x = (m.rd(d + 1) << 24) >> 24, y = m.rd(d + 2), yo = m.rd(d + 3), blk = (m.rd(d) & 0x80) ? sym.mbuf + i * sym.SPR_MAXB : m.rd(d + 6) | m.rd(d + 7) << 8;   // влево — буфер отражения
    const vx = (m.rd(blk) << 24) >> 24, vw = m.rd(blk + 1), vy = (m.rd(blk + 2) << 24) >> 24, vh = m.rd(blk + 3);
    for (let j = 0; j < vw; j++) for (let sl = 0; sl < vh; sl++) {     // столбец j: vh строк по 2 байта (Y, K)
      const q = blk + 4 + 2 * (j * vh + sl), L = y * 8 + yo + vy + sl;
      if (L < 16 || L >= 192) continue;
      const yb = m.rd(q), kb = m.rd(q + 1);
      for (let b = 0; b < 8; b++) { const X = (x + vx + j) * 8 + b; if (X < 0 || X >= 256) continue;
        const o = L * 256 + X, sh = 7 - b;
        if ((kb >> sh) & 1) spr[o] = 1; else if ((yb >> sh) & 1) spr[o] = COLY[i]; }   // (S, K): S — все точки
    }
  }
  let badCells = 0; const list = [];
  for (let r = 2; r < 24; r++) for (let c = 0; c < 32; c++) {
    const t = m.rd(0x6000 + r * 32 + c); const at = m.rd(sym.amap + r * 32 + c);
    let ink = at & 7, paper = (at >> 3) & 7; if ((at & 0x80) && fl) [ink, paper] = [paper, ink];
    let hasSpr = false;
    let g = gfx;                                    // искра (room.asm, D9xx): тайл 0 с базой 9EA8
    const cellOk = (rot) => {                       // rot — сдвиг воды (строк): точки тайла строки (k + rot) & 7
      for (let k = 0; k < 8; k++) { const L = r * 8 + k, row = m.rd(g + t * 8 + ((k + rot) & 7));
        for (let b = 0; b < 8; b++) { const X = c * 8 + b, o = L * 256 + X, sp = spr[o]; if (sp >= 0) hasSpr = true;
          const want = sp >= 0 ? sp : ((row >> (7 - b)) & 1 ? ink : paper);
          if (pix(X, L + 32) !== want) return [want, pix(X, L + 32)]; } }
      return null;
    };
    let e = cellOk(0);
    if (e && t === 0) { g = 0x9EA8; if (!cellOk(0)) e = null; g = gfx; }
    if (e && t === 0 && m.rd(sym.zv_FE03) === 18) {   // шар колдуна (07.11, wizball): клетка из копии карты 5D00, искра 9EA8 — XOR плоскостей A и C
      const tb = m.rd(0x5D00 + r * 32 + c); let bad = null;
      for (let k = 0; k < 8 && !bad; k++) { const L = r * 8 + k, row = m.rd(gfx + tb * 8 + k), sp = m.rd(0x9EA8 + k);
        for (let b = 0; b < 8; b++) { const X = c * 8 + b, o = L * 256 + X, sv = spr[o];
          const want = sv >= 0 ? sv : (((row >> (7 - b)) & 1 ? ink : paper) ^ (((sp >> (7 - b)) & 1) ? 6 : 0));
          if (pix(X, L + 32) !== want) { bad = [want, pix(X, L + 32)]; break; } } }
      if (!bad) e = null; }
    if (e && (at & 0x80)) { [ink, paper] = [paper, ink]; if (!cellOk(0)) e = null; else [ink, paper] = [paper, ink]; }   // мигание: фаза могла смениться до перерисовки
    if (e && !hasSpr) for (const rot of [2, 4, 6]) if (!cellOk(rot)) { e = null; break; }
    if (e) { badCells++; list.push([r, c, e[0], e[1], hasSpr]); }
  }
  return { bad: badCells, cells: list };
}
  return compose;
}
module.exports = { make };
