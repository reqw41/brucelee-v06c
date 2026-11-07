// Звук бипера: только то, что остаётся в памяти (без задержек).
// 95E2: B -> 963E (маска клавиш для обрыва: операнд AND), C -> 962A (код команды: D3 = OUT, 3E = LD A,n —
// «без звука»); каждое ненулевое значение таблицы длительностей переключает бит 4 в 600B. После группы
// нот — чтение порта 00FE: нажата клавиша (с маской) — мелодия обрывается.
// 9312: шум удара — 11 шагов сдвигового регистра в 9339, бит 4 XOR в 600B.
'use strict';
const u16 = (v) => v & 0xffff;

function group(M, hl) {              // 960A: одна группа нот, true = оборвали клавишей
  const tbl = M.rd16(hl); let bc = M.rd16(u16(hl + 2)); hl = u16(hl + 4);
  let toggles = 0;
  while (bc) {
    bc--;
    for (let p = tbl; ; p = u16(p + 2)) { if (!M.rd16(p)) break; toggles++; }
  }
  if (toggles & 1) M.wr(0x600B, M.rd(0x600B) ^ 0x10);
  const v = M.in(0x00FE);
  if ((~v & M.rd(0x963E)) & 0xff) return true;
  return false;
}
function play95E2(M, hl, b, c) {
  M.wr(0x963E, b); M.wr(0x962A, c);
  for (;;) {
    const de = M.rd16(hl); hl = u16(hl + 2);
    if (!de) return;
    for (let p = de; ; p = u16(p + 2)) {
      const g = M.rd16(p);
      if (!g) break;
      if (group(M, g)) return;
    }
  }
}
// входы: snd_jingle (9300, HL=935C), snd_die (9306, 933A), snd_key (930C, 9346)
function play(M, name, hl, b, c) { M.sound(name, b, c); play95E2(M, hl, b, c); }
function hit(M) {
  M.sound('snd_hit', null, null);
  for (let c = 0xF5; c !== 0x100; c++) {
    let a = M.rd(0x9339) || 1;
    const cy = a & 1; a >>= 1; if (cy) a ^= 0xA6;
    M.wr(0x9339, a);
    M.wr(0x600B, M.rd(0x600B) ^ (a & 0x10));
  }
}
module.exports = { play, hit, play95E2 };
