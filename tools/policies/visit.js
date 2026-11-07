// Политика «обход объектов»: в каждой комнате по очереди ставит Брюса на клетки с фонарями/предметами
// (коды 10h–16h) и ловушками (17h) карты 6040..62FF, затем `stay` шагов случайных клавиш; после всех
// объектов — телепорт в следующую комнату (как tour). opts: { seed, stay, keys, p, rooms }
'use strict';
const { rng } = require('../scenario');
module.exports = (opts, S) => {
  const rnd = rng(opts.seed || 1), stay = opts.stay || 40, keys = opts.keys || ['Q', 'A', 'O', 'P', 'Z'];
  const rooms = opts.rooms || [...Array(20).keys()];
  let room = -1, targets = [], wait = 0, held = [], hold = 0, ri = 0;
  return (m, t, poke) => {
    const cur = m.peek(S.cur_room);
    if (cur !== room) {                                     // новая комната: собрать объекты
      room = cur; targets = [];
      for (let a = 0x6040; a < 0x6300; a++) { const v = m.peek(a); if (v >= 0x10 && v <= 0x17) targets.push(a - 0x6000); }
      wait = 20;
    }
    if (wait > 0) wait--;
    else if (targets.length) {
      const c = targets.splice(Math.floor(rnd() * targets.length), 1)[0];
      const row = c >> 5, col = c & 31;
      poke(S.bruce + 6, Math.max(0, Math.min(29, col - 1))); poke(S.bruce + 7, Math.max(2, row - 2));
      poke(S.bruce + 4, 0); poke(S.bruce + 2, 1); poke(S.bruce + 0x0a, 0);
      wait = stay;
    } else {                                                // объекты кончились — в следующую комнату
      const r = rooms[ri++ % rooms.length];
      const desc = m.peek(0x6400 + r * 2) | m.peek(0x6401 + r * 2) << 8;
      poke(S.bruce + 7, 0); poke(S.bruce + 4, 0);
      for (let z = 0; z < 9; z++) { poke(0x6012 + z * 3, r); poke(0x6013 + z * 3, m.peek(desc + 8)); poke(0x6014 + z * 3, m.peek(desc + 9)); }
      wait = 5; room = -2;
    }
    if (hold-- <= 0) { held = keys.filter(() => rnd() < (opts.p || 0.3)); hold = 3 + Math.floor(rnd() * 25); }
    return held;
  };
};
