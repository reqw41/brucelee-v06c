// Проигрыватель сценария для стендов ZX (zx_trace.js, shadow.js): меню по кадрам, потом клавиши на каждый
// шаг игры (steps, затем random или политика). Шаг = проход главного цикла (play_loop C7A4).
//
// Сценарий: { "name", "menu": [{"frames": n, "keys": [...]}], "ticks": N,
//   "steps": [{"ticks": n, "keys": [...]}], "random": {"seed", "keys": [...], "p": 0.3, "hold": [a, b]},
//   "policy": {"name": ...}, "pokes": [{"tick": t, "every": n?, "set": {"метка или hex": значение | "@метка"}}],
//   "tour": {"every": n, "rooms": [..], "from": t0} — телепорт: Брюс на строку 0, все 9 выходов комнаты (6012..602C)
//   -> [комната, X, Y точки появления этой комнаты]; смену комнаты делает сама игра (C875). }
// По умолчанию меню: ENTER обрывает мелодию титула, второй ENTER в меню — старт (1 игрок, клавиатура).
'use strict';
const path = require('path');
const ZX = require('./zx48');
const { SYM } = require('./sym');

function rng(seed) { let s = seed >>> 0 || 1; return () => { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; }; }

function start(sc, opts) {
  opts = opts || {};
  const m = new ZX().loadGame();
  if (opts.onCreate) opts.onCreate(m);
  const step = opts.step || ((mm) => mm.step());
  const frames = (n) => { const f = m.frames + n; while (m.frames < f) step(m); };
  const menu = sc.menu || [{ frames: 30, keys: [] }, { frames: 6, keys: ['ENTER'] }, { frames: 10, keys: [] }, { frames: 6, keys: ['ENTER'] }, { frames: 4, keys: [] }];
  for (const st of menu) { m.keysOnly(st.keys || []); frames(st.frames); }
  m.keysOnly([]);
  const lim = m.total + ZX.T_FRAME * 3000;
  while (!(m.pc === SYM.play_loop && !m.inIsr)) { if (m.total > lim) throw new Error('игра не началась'); step(m); }
  const plan = [];
  for (const st of sc.steps || []) for (let i = 0; i < st.ticks; i++) plan.push(st.keys || []);
  const rnd = sc.random ? rng(sc.random.seed) : null;
  let hold = 0, rkeys = [];
  const policy = sc.policy ? require(path.join(__dirname, 'policies', sc.policy.name + '.js'))(sc.policy, SYM) : null;
  const N = sc.ticks || plan.length;
  const pokes = new Map();
  for (const p of sc.pokes || []) {
    if (p.every) { for (let t = p.tick || 0; t < N; t += p.every) pokes.set(t, Object.assign({}, pokes.get(t), p.set)); }
    else pokes.set(p.tick, Object.assign({}, pokes.get(p.tick), p.set));
  }
  const applied = [];
  const tour = sc.tour ? new Map(sc.tour.rooms.map((r, i) => [(sc.tour.from || 0) + i * sc.tour.every, r])) : new Map();
  function teleport(room) {
    const desc = m.peek(0x6400 + room * 2) | m.peek(0x6401 + room * 2) << 8;
    const x = m.peek(desc + 8), y = m.peek(desc + 9);
    const set = [[SYM.bruce + 7, 0], [SYM.bruce + 4, 0]];
    for (let z = 0; z < 9; z++) set.push([0x6012 + z * 3, room], [0x6013 + z * 3, x], [0x6014 + z * 3, y]);
    for (const [a, v] of set) { m.poke(a, v); applied.push([a, v]); }
  }
  function keysFor(t) {
    if (t >= N) return null;
    applied.length = 0;
    if (tour.has(t)) teleport(tour.get(t));
    const pk = pokes.get(t);
    if (pk) for (const [k, v] of Object.entries(pk)) {
      const a = k in SYM ? SYM[k] : parseInt(k, 16);
      const val = typeof v === 'string' && v[0] === '@' ? m.peek(SYM[v.slice(1)]) : v;
      m.poke(a, val); applied.push([a, val & 0xff]);
    }
    if (t < plan.length) return plan[t];
    if (policy) return policy(m, t, (a, v) => { m.poke(a, v); applied.push([a, v & 0xff]); });
    if (!rnd) return null;
    if (hold <= 0) {
      rkeys = sc.random.keys.filter(() => rnd() < (sc.random.p || 0.3));
      hold = sc.random.hold[0] + Math.floor(rnd() * (sc.random.hold[1] - sc.random.hold[0] + 1));
    }
    hold--; return rkeys;
  }
  return { m, keysFor, N, applied };
}

module.exports = { start, rng };
