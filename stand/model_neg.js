// Негативный контроль model_run: BREAK=score|tile|ai — порча модели, ожидается красный.
'use strict';
const P = require('../src/model/pers'), G = require('../src/model/game'), R = require('../src/model/room');
const k = process.env.BREAK || 'score';
if (k === 'score') { const f = G.add_score; G.add_score = (M, hl) => { f(M, hl); M.wr(0xFEF7, M.rd(0xFEF7) ^ 1); }; }
if (k === 'tile') { const f = R.R[0xDA63]; R.R[0xDA63] = (M, de) => { f(M, de); M.wr(0x6100, 0x55); }; }
if (k === 'ai') { const f = P.ai; P.ai = (M, ix) => f(M, ix) ^ 1; }
require('../tools/model_run.js');
