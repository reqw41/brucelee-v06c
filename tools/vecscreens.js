#!/usr/bin/env node
// Регресс экрана и звука боевого образа (build/vec/brucelee.bin) против эталона tests/screens.json.
//   node tools/vecscreens.js [образ] [--update]
// 1) Титул и меню без клавиш: экран (3 плоскости) каждые 10 кадров и все записи в порты звука (ВИ53 08..0B,
//    спрайт-бит ВВ55 через 00) по кадрам — хеши.
// 2) Игра: клавиши по номеру шага логики (не по кадру — так ускорение вывода не сдвигает игру), ИИ врагов — ветка ZX
//    (как run80 --ship), экран в начале каждого шага — хеш. Сменилось намеренно — `--update` и сверка глазами.
// Эталон 06.11.2026 снят со сборки c180e50 (до ускорения вывода и ИИ CPC); с него пойман мусор на титрах (zero8).
'use strict';
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const ROOT = path.join(__dirname, '..');
const args = process.argv.slice(2), UPDATE = args.includes('--update');
const ROM = args.find((a) => !a.startsWith('--')) || path.join(ROOT, 'build/vec/brucelee.bin');
const SYMF = ROM.replace(/\.bin$/, '.sym');
const REF = path.join(ROOT, 'tests/screens.json');
const E = require('./vec_emu'), VK = require('./vecshot_keys');
const mk = (rom) => { const m = E.mk(rom);                // NEG=метка+смещение:байт — негативный контроль (порча образа)
  if (process.env.NEG) { const q = process.env.NEG.match(/^([\w.]+)\+(\d+):(\d+)$/); m.wr(sym[q[1]] + +q[2], +q[3]); }
  return m; };
const sym = {};
for (const l of fs.readFileSync(SYMF, 'latin1').split('\n')) { const q = l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (q) sym[q[1]] = parseInt(q[2], 16); }
const TITLE = 1150, STEPS = +(process.env.STEPS || 1500);
const h = (b) => crypto.createHash('md5').update(b).digest('hex').slice(0, 12);
const scr = (m) => { const b = Buffer.alloc(0x6000); for (let a = 0; a < 0x6000; a++) b[a] = m.rd(0xA000 + a); return b; };

function zxAI(m) {                                   // ветка ZX в образе с ИИ CPC (как tools/run80.js --ship)
  if (sym['ai.nzx'] === undefined) return;            // ИИ CPC нет (до 06.11) — нечего возвращать
  const a = sym['ai.near'], t = sym['ai.nzx'];
  m.wr(a + 1, t & 255); m.wr(a + 2, t >> 8); m.wr(sym['ai.tdly'] + 1, 0x32); m.wr(sym['ai.ytol'], 0);
  m.wr(sym.rsp_ninja + 1, 0x32); m.wr(sym.rsp_yamo + 1, 0x32); m.wr(sym['revive.app'] + 1, 0x4B);
}
const got = { title: [], sound: [], steps: [], sfx: [] }; 
const shots = {};
{ // 1) титул и меню
  const m = mk(ROM);
  const o = m.io.output.bind(m.io);
  // звук — то, что звучит: счётчики 1, 2 (управляющее слово и данные) и бит спикера (BSR C0); защёлки секундомера
  // (счётчик 0) и опрос клавиатуры зависят от тактов — не сравниваются
  m.io.output = (p, v) => { p &= 0xFF; v &= 0xFF;
    if ((p === 0x08 && (v & 0xC0) && (v & 0xC0) !== 0xC0) || p === 0x09 || p === 0x0A || (p === 0x00 && v <= 1)) {
      if (f0 < 0 && (p === 0x09 || p === 0x0A)) f0 = curF;   // кадры — от первой ноты (старт титула может сдвинуться)
      if (f0 < 0) return o(p, v);
      got.sound.push((curF - f0) + ':' + p.toString(16) + '=' + v.toString(16));
    } 
    return o(p, v); };
  let prev = null, f0 = -1, curF = 0;
  for (let f = 1; f <= TITLE; f++) {
    curF = f; m.frame(); const s = scr(m);
    if (f % 10 === 0) {                                // экран — только установившийся (как кадр назад): титул и меню
      const stable = prev && s.equals(prev);           // рисуются несколько кадров, момент зависит от тактов
      got.title.push(stable ? h(s) : '-'); shots['t' + f] = s;
    }
    prev = s;
  }
  for (let f = TITLE; f < 2 * 936 + 60; f++) m.frame();   // музыка титула — два прохода (2 x 936 кадров), потом тишина
  got.titleMus = m.rd(sym.mus_on) ? 'играет' : 'тихо';
}
function game(noDefer) {                             // 2) игра по шагам
  const m = mk(ROM); zxAI(m);
  if (noDefer && sym['show_late.lim'] !== undefined) m.wr(sym['show_late.lim'] + 1, 0xFF);   // рисунок — без откладывания показа
  let defs = 0, inj = false, iff0 = false, tickOk = false, sndOk = false;
  let step = 0, started = false, sd = 5; const rnd = () => (sd = (sd * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  let rs = 12345;                                      // plat_rand на Векторе — из таймера (зависит от тактов): в тесте —
  m.onInstr = (pc) => {                                // своя последовательность, иначе любое ускорение меняет игру
    if (pc === sym.plat_rand) {
      rs = (rs * 1103515245 + 12345) & 0x7fffffff; m.cpu.regs[7] = (rs >> 16) & 0xFF;
      m.cpu.pc = m.rd(m.cpu.sp) | m.rd(m.cpu.sp + 1) << 8; m.cpu.sp = (m.cpu.sp + 2) & 0xFFFF; return;
    }
    if (noDefer && pc === sym.vcode && started && step <= STEPS) { const c = m.cpu.regs[7];                   // тон — делителем (номер в snd_divs меняется при новых нотах)
      const v = c >= 1 && c < 0x80 ? 'd' + (m.rd(sym.snd_divs + 2 * c - 2) | m.rd(sym.snd_divs + 2 * c - 1) << 8) : c.toString(16);
      got.sfx.push(step + ':' + m.cpu.regs[0].toString(16) + ':' + v); }
    if (noDefer && pc === sym.snd_tick && started) {   // звук игры: тик раз на шаг (как game_tick), голоса — что играть
      if (sndOk) { sndOk = false; return; }
      m.cpu.pc = m.rd(m.cpu.sp) | m.rd(m.cpu.sp + 1) << 8; m.cpu.sp = (m.cpu.sp + 2) & 0xFFFF; return;
    }
    if (noDefer && pc === sym.game_tick && started) {
      if (tickOk) { tickOk = false; return; }
      m.cpu.pc = m.rd(m.cpu.sp) | m.rd(m.cpu.sp + 1) << 8; m.cpu.sp = (m.cpu.sp + 2) & 0xFFFF; return;
    }
    if (pc !== sym.pass) return;
    if (inj) { inj = false; m.cpu.iff = iff0; return; }   // вернулись из vec_scan + zx_build
    if (started && m.rd(sym.sh_def)) defs++; started = true;
    if (noDefer && step < STEPS) { const s = scr(m); got.steps.push(h(s)); shots['s' + step] = s; }
    step++;
    if (step % 6 === 1) for (const k of ['left', 'right', 'up', 'down', 'space']) VK.apply(m, [[k, rnd() < 0.3]]);
    // клавиатуру опрашивает прерывание — когда шаг увидит нажатие, зависит от тактов; здесь опрос сразу:
    // vec_scan -> zx_build -> pass под DI (регистры в начале прохода не живые)
    // игровая часть прерывания (game_tick: ввод игроков FE11/FE12, счётчики ZX) — у ZX раз за шаг; на Векторе — раз
    // за кадр, игра зависит от тактов. В тесте — ровно один раз на шаг, здесь; из прерывания — пропуск
    if (!noDefer) return;
    iff0 = m.cpu.iff; m.cpu.iff = false; inj = true; tickOk = true; sndOk = true;
    const push = (w) => { m.cpu.sp = (m.cpu.sp - 2) & 0xFFFF; m.wr(m.cpu.sp, w & 255); m.wr(m.cpu.sp + 1, w >> 8); };
    push(sym.pass); push(sym.snd_tick); push(sym.game_tick); push(sym.zx_build); m.cpu.pc = sym.vec_scan;
  };
  const plan = VK.parse('160:space+ 200:space-');
  for (let f = 0; step <= STEPS && f < STEPS * 8; f++) { if (!started) VK.apply(m, plan[f]); m.frame(); }
  return { defs, frames: m.frames };
}
game(true);
{ // 3) экран GAME OVER (06.11: «GAME  OVER» посередине поля, без мигания): игра до 700-го кадра -> plat_game_over
  const m = mk(ROM); zxAI(m); let go = false;
  const snd = []; let f0 = -1;                         // проигрыш: записи в счётчики 1, 2 после GAME OVER от первой ноты
  const o = m.io.output.bind(m.io);
  m.io.output = (p, v) => { p &= 0xFF; v &= 0xFF;
    if (go && ((p === 0x08 && (v & 0xC0) && (v & 0xC0) !== 0xC0) || p === 0x09 || p === 0x0A)) {
      if (f0 < 0 && (p === 0x09 || p === 0x0A)) f0 = m.frames;
      if (f0 >= 0) snd.push((m.frames - f0) + ':' + p.toString(16) + '=' + v.toString(16));
    } return o(p, v); };
  m.onInstr = (pc) => { if (!go && m.frames >= 700 && pc === sym.pass) { go = true; m.cpu.pc = sym.plat_game_over; } };
  const plan = VK.parse('160:space+ 200:space-');
  for (let f = 0; f < 760; f++) { VK.apply(m, plan[f]); m.frame(); }
  const a = scr(m);
  for (let f = 0; f < 120; f++) m.frame(); const b = scr(m);   // без мигания: через 120 кадров тот же
  got.over = [h(a), a.equals(b) ? 'стоит' : 'мигает', h(Buffer.from(snd.join(' ')))]; shots.over = a;
}
{ const t = game(false); got.defs = t.defs; got.frames = t.frames; }   // темп: отложенные показы врагов и кадры
if (UPDATE || !fs.existsSync(REF)) {
  fs.mkdirSync(path.dirname(REF), { recursive: true }); fs.writeFileSync(REF, JSON.stringify(got));
  console.log(`экраны: эталон записан (${got.title.length} кадров титула, ${got.steps.length} шагов) -> tests/screens.json`); process.exit(0);
}
const PAL8 = [0x00, 0x07, 0x38, 0x3F, 0xC0, 0xC7, 0xF8, 0xFF]; // номер = биты A000 C000 E000 (условные цвета)
function saveShot(s, out) { VK.shot({ rd: (a) => (a >= 0xA000 ? s[a - 0xA000] : 0) }, out, PAL8.concat(PAL8)); }
if (process.env.SAVE) for (const k of process.env.SAVE.split(',')) if (shots[k]) saveShot(shots[k], process.env.SAVEDIR + '/' + k + '.png');
const ref = JSON.parse(fs.readFileSync(REF, 'utf8'));
let bad = 0;
const first = (name, a, b, key) => {
  const n = Math.max(a.length, b.length); let cnt = 0, i0 = -1;
  for (let i = 0; i < n; i++) if (a[i] !== b[i] && a[i] !== '-' && b[i] !== '-') { cnt++; if (i0 < 0) i0 = i; }
  if (cnt) {
    bad++; console.log(`экраны: ${name}: расхождений ${cnt} из ${n}, первое — ${key(i0)}` + (process.env.ALL ? ' ' + [...Array(n).keys()].filter((i) => a[i] !== b[i] && a[i] !== '-' && b[i] !== '-').map((i) => key(i).split(' ')[0]).join(',') : ''));
    const s = shots[key(i0).split(' ')[0]];
    if (s) { const out = path.join(ROOT, 'build/vecscreens_' + key(i0).split(' ')[0] + '.png'); try { saveShot(s, out); console.log('  снимок ' + out); } catch (e) {} }
  }
};
first('титул/меню', got.title, ref.title, (i) => 't' + (i + 1) * 10 + ' (кадр)');
first('звук титула', got.sound, ref.sound, (i) => `запись ${i}: ${got.sound[i]} (эталон ${ref.sound[i]})`);
first('игра', got.steps, ref.steps, (i) => 's' + i + ' (шаг)');
if (ref.titleMus && got.titleMus !== ref.titleMus) { bad++; console.log(`экраны: музыка титула после двух проходов — ${got.titleMus} (эталон ${ref.titleMus})`); }
if (ref.over) first('GAME OVER', got.over, ref.over, (i) => ['over', 'неподвижность', 'проигрыш'][i]);
if (ref.sfx) first('звук игры', got.sfx, ref.sfx, (i) => `команда ${i}: шаг:голос:код ${got.sfx[i]} (эталон ${ref.sfx[i]})`);
if (ref.defs !== undefined) {
  const dd = (got.defs - ref.defs) / ref.defs, df = (got.frames - ref.frames) / ref.frames;
  console.log(`экраны: темп — отложенных показов врагов ${got.defs} (эталон ${ref.defs}), кадров ${got.frames} (эталон ${ref.frames})`);
  if (dd > 0.10 || df > 0.03) { bad++; console.log('экраны: темп ХУЖЕ эталона (допуск: показы +10 %, кадры +3 %)'); }
}
console.log(`экраны: титул ${got.title.length} кадров, звук титула, игра ${got.steps.length} шагов, звук игры ${got.sfx.length} команд — ${bad ? 'ЕСТЬ РАСХОЖДЕНИЯ' : 'совпадают'}`);
process.exit(bad ? 1 : 0);
