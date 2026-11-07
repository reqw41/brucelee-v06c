// Реестр подпрограмм модели для теневой сверки (tools/shadow.js): метка -> (M, регистры) -> выход.
// out — какие регистры/флаги сравнивать (fz, fc — флаги Z и C).
'use strict';
const P = require('./pers'), Rm = require('./room'), G = require('./game'), O = require('./out');
const R = {};
function reg(name, fn, out) { fn.out = out || []; R[name] = fn; }
const hl = (r) => r.h << 8 | r.l, de = (r) => r.d << 8 | r.e, bc = (r) => r.b << 8 | r.c;

reg('pers_size', (M, r) => { const s = P.size(M, r.ix); return { b: s.b, c: s.c }; }, ['b', 'c']);
reg('floor_below', (M, r) => ({ fz: P.floor_below(M, r.ix) }), ['fz']);
reg('ceiling_above', (M, r) => ({ fz: P.ceiling_above(M, r.ix) }), ['fz']);
reg('rope_under', (M, r) => ({ fz: P.rope_under(M, r.ix).z }), ['fz']);
reg('obst_ahead', (M, r) => ({ fz: P.obst_ahead(M, r.ix) }), ['fz']);
reg('obst_left', (M, r) => ({ fz: P.obst_left(M, r.ix) }), ['fz']);
reg('obst_right', (M, r) => ({ fz: P.obst_right(M, r.ix) }), ['fz']);
reg('obst_left_edge', (M, r) => ({ fz: P.obst_left_edge(M, r.ix) }), ['fz']);
reg('obst_right_edge', (M, r) => ({ fz: P.obst_right_edge(M, r.ix) }), ['fz']);
reg('arc_step', (M, r) => ({ a: P.arc(M, r.ix) }), ['a']);
reg('melee_hit', (M, r) => { P.melee(M, r.ix, hl(r), 9); });
reg('melee_kick', (M, r) => { P.melee(M, r.ix, hl(r), 8); });
reg('killcheck', (M, r) => ({ fc: P.killcheck(M, r.ix) }), ['fc']);
reg('pers_revive', (M, r) => { P.revive(M, r.ix); });
reg('pix_collide', (M, r) => ({ fz: !P.pix_collide(M, r.ix, hl(r), de(r)) }), ['fz']);
reg('pers_objects', (M, r) => { P.objects(M, r.ix); });
reg('pers_ai', (M, r) => ({ a: P.ai(M, r.ix) }), ['a']);
reg('pers_step', (M, r) => { P.step(M, r.ix); });
reg('pers_fell', (M, r) => { P.fell(M, r.ix); });
reg('pers_expire', (M, r) => { P.expire(M, r.ix); });
for (const a of Object.keys(P.H)) {
  const h = P.H[a];
  reg('L_' + (+a).toString(16).toUpperCase(), (M, r) => ({ a: h(M, r.ix, r.a) }), ['a']);
}
reg('will_apply', (M, r) => { Rm.will_apply(M, r.a, hl(r)); });
reg('tile_put', (M, r) => { Rm.tile_put(M, r.a, hl(r)); });
reg('tile_redraw', (M, r) => { Rm.tile_redraw(M, hl(r)); });
reg('room_dispatch', (M, r) => { Rm.dispatch(M, hl(r), de(r)); });
reg('room_load', (M) => { Rm.room_load(M); });
reg('cracks', (M) => { Rm.cracks(M); });
reg('mover', (M, r) => { Rm.mover(M, r.ix); });
reg('water_phase', (M) => ({ fz: Rm.water_phase(M) }), ['fz']);
reg('water_rot_a', (M, r) => { Rm.water(M, hl(r), bc(r)); });
reg('anim_strips', (M) => { Rm.strips(M); });
reg('add_score', (M, r) => { G.add_score(M, hl(r)); });
reg('header', (M) => { G.header(M); });
reg('lives_up', (M) => { G.lives_up(M); });
reg('pers_erase', (M, r) => { O.pers_erase(M, r.ix); });
reg('pers_draw', (M, r) => { O.pers_draw(M, r.ix); });
module.exports = { routines: R };
