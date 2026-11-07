// Меню: какие клавиши что ставят. node stand/menuvars.js "A,B,C"
'use strict';
const ZX = require('../tools/zx48');
const { SYM } = require('../tools/sym');
const seq = (process.argv[2] || '').split(',').filter(Boolean);
const m = new ZX().loadGame();
const fr = (n, k) => { m.keysOnly(k); m.runFrames(n); };
fr(30, []); fr(6, ['ENTER']); fr(20, []);
for (const k of seq) { fr(6, k.split('+')); fr(8, []); }
const v = (a) => m.peek(a).toString(16);
console.log(seq.join(','), 'FE07', v(0xFE07), 'FE08', v(0xFE08), 'FE09', v(0xFE09), 'FE0A', v(0xFE0A), 'FE15', v(0xFE15), 'FE9A', v(0xFE9A));
fr(6, ['ENTER']); fr(30, []);
console.log('  после старта: pc', m.pc.toString(16), 'FE04', v(0xFE04), 'FE07', v(0xFE07), 'FE08', v(0xFE08), 'FE0A', v(0xFE0A), 'FE15', v(0xFE15), 'жизни', String.fromCharCode(m.peek(0xFED0), m.peek(0xFED1)));
