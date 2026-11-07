// Негативный контроль сверки: портит модель (флаг пола, урон, очки, щелчок шагов) и запускает shadow.
'use strict';
const P = require('../src/model/pers'), G = require('../src/model/game');
const kind = process.env.BREAK || 'floor';
if (kind === 'floor') { const f = P.floor_below; P.floor_below = (M, ix) => !f(M, ix); }
if (kind === 'score') { const f = G.add_score; G.add_score = (M, hl) => { f(M, hl); M.wr(0xFEF7, 0x39); }; }
if (kind === 'click') { const f = P.H[0xCE48]; P.H[0xCE48] = (M, ix, a) => { const r = f(M, ix, a); M.outFE(0); return r; }; }

require('../tools/shadow.js');
