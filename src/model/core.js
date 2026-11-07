// Ядро JS-модели логики Bruce Lee (docs/PLAN.md, этап 1). Образец — aticatac-v06c/src/model/core.js.
//
// Память — 64 КБ в раскладке ZX (адреса как в игре). Адреса, которые пишет прерывание (owned), читаются
// из очередей эталона (по адресу, по порядку; кончилась — последнее значение), как и порты (inq) и
// `ld a,r` (rq): их значения посреди шага знает только эталон. Звук — список входов в звуковые
// подпрограммы [имя, b, c] и записей в порт FE (щелчки шагов).
'use strict';
const { SYM } = require('../../tools/sym');

class Mem {
  constructor(ram) {
    this.ram = ram;                   // Uint8Array(0x10000), владеет вызывающий
    this.owned = null;                // Set адресов прерывания
    this.q = new Map();               // адрес -> [значения]
    this.inq = [];                    // [порт, байт] по порядку
    this.rq = [];                     // ld a,r
    this.snd = [];                    // [имя, b, c]
    this.out = [];                    // записи в порт FE (вне звуковых подпрограмм)
    this.writes = null;               // Set адресов, записанных моделью
    this.halts = 0;                   // число HALT (ожидание кадра), для сведения
  }
  rd(a) {
    a &= 0xffff;
    if (this.owned && this.owned.has(a)) {
      const q = this.q.get(a);
      if (q && q.length) { const v = q.length > 1 ? q.shift() : q[0]; this.ram[a] = v; return v; }
    }
    return this.ram[a];
  }
  wr(a, v) { a &= 0xffff; this.ram[a] = v & 0xff; if (this.writes) this.writes.add(a); }
  rd16(a) { return this.rd(a) | this.rd(a + 1) << 8; }
  wr16(a, v) { this.wr(a, v); this.wr(a + 1, v >> 8); }
  inc(a) { const v = (this.rd(a) + 1) & 0xff; this.wr(a, v); return v; }
  dec(a) { const v = (this.rd(a) - 1) & 0xff; this.wr(a, v); return v; }
  in(port) {
    if (!this.inq.length) throw new Error('модель: нет значения порта ' + port.toString(16));
    const [p, v] = this.inq.shift();
    if (p !== port) throw new Error(`модель: порт ${port.toString(16)}, в эталоне ${p.toString(16)}`);
    return v;
  }
  ldar() { if (!this.rq.length) throw new Error('модель: нет значения ld a,r'); return this.rq.shift(); }
  sound(name, b, c) { this.snd.push([name, b & 0xff, c & 0xff]); }
  outFE(v) { this.out.push(v & 0xff); }
}

class NotModeled extends Error { constructor(m) { super(m); this.notModeled = true; } }

module.exports = { Mem, S: SYM, NotModeled };
