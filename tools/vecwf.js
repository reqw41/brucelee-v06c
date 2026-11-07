// Вспышка оружия (D98D): в 19 кадрах игры (план build/randplan.txt) wf_on = 1 и перерисовка области 3..10 x 11..20;
// сверка с моделью: чернила XOR 7, точки персонажей — номер 0 палитры (кадры CPC, дырок нет). NEG=1 — модель без вспышки (должно краснеть).
//   node tools/vecwf.js
'use strict';
const fs = require('fs'), path = require('path'), R = path.join(__dirname, '..');
const E=require(R+'/tools/vec_emu'), VK=require(R+'/tools/vecshot_keys');
const sym={}; for (const l of fs.readFileSync(R+'/build/vec/brucelee.sym','latin1').split('\n')) { const m=l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i); if (m) sym[m[1]]=parseInt(m[2],16); }
const plan=VK.parse(fs.readFileSync(R+'/build/randplan.txt','utf8').trim());
const NEG = +(process.env.NEG||0);
const pix=(m,x,y)=>{const a=((x>>3)<<8)|(255-y),b=7-(x&7);return((m.rd(0xA000+a)>>b)&1)<<2|((m.rd(0xC000+a)>>b)&1)<<1|((m.rd(0xE000+a)>>b)&1);};
let tot=0, bad=0, sprCells=0;
for (let F=700; F<=4300; F+=200) {
  const m=E.mk(R+'/build/vec/brucelee.bin');
  for (let f=0; f<F; f++){ VK.apply(m,plan[f]); m.frame(); }
  let st=0, done=false;
  m.onInstr=(pc)=>{ const cpu=m.cpu;
    if (st===0 && pc===sym.pass) { st=1; m.wr(sym.wf_on,1); m.wr(sym.ar0,3); m.wr(sym.ar1,10); m.wr(sym.ac0,11); m.wr(sym.ac1,20);
      for (const [i,x,y] of [[0,15,5],[1,11,7],[2,13,6]]) if (m.rd(sym.disp+8*i)) { m.wr(sym.disp+8*i+1,x); m.wr(sym.disp+8*i+2,y); }   // персонажи — в область вспышки
      cpu.sp=(cpu.sp-2)&0xffff; m.wr(cpu.sp,sym.pass&255); m.wr(cpu.sp+1,sym.pass>>8); cpu.pc=sym.repaint; }
    else if (st===1 && pc===sym.pass) { st=2; done=true; snap=m.dump(); } };
  let snap=null;
  for (let f=0; f<30 && !done; f++) m.frame();
  if (!done) { console.log('кадр', F, 'нет возврата'); continue; }
  const mm={rd:(a)=>snap[a]};
  // модель: disp + атрибуты, в области чернила ^7, спрайт чёрный
  const gfx=mm.rd(0x6000)|mm.rd(0x6001)<<8, fl=mm.rd(sym.flash_ph); const spr=new Int8Array(256*192).fill(-1);
  const en=new Uint8Array(256*192);   // точки персонажей (во вспышке — номер 0), кадры CPC: заголовок vx, vw, vy, vh, строки по 2 байта
  for (let i=0;i<3;i++){const d=sym.disp+8*i; if(!mm.rd(d)) continue;
    const x=(mm.rd(d+1)<<24)>>24,y=mm.rd(d+2),yo=mm.rd(d+3),blk=(mm.rd(d)&0x80)?sym.mbuf+i*sym.SPR_MAXB:mm.rd(d+6)|mm.rd(d+7)<<8;
    const vx=(mm.rd(blk)<<24)>>24,vw=mm.rd(blk+1),vy=(mm.rd(blk+2)<<24)>>24,vh=mm.rd(blk+3);
    for(let j=0;j<vw;j++)for(let sl=0;sl<vh;sl++){const q=blk+4+2*(j*vh+sl),L=y*8+yo+vy+sl; if(L<16||L>=192)continue;
      const v=mm.rd(q)|mm.rd(q+1);
      for(let b=0;b<8;b++){const X=(x+vx+j)*8+b; if(X<0||X>=256)continue; if((v>>(7-b))&1) en[L*256+X]=1;}}}
  for (let r=3;r<=10;r++) for (let c=11;c<=20;c++){ tot++;
    const t=mm.rd(0x6000+r*32+c), at=mm.rd(sym.amap+r*32+c); let ink=at&7,paper=(at>>3)&7; if((at&0x80)&&fl)[ink,paper]=[paper,ink]; if(!NEG) ink^=7;
    let e=false, hs=false;
    for(let k=0;k<8;k++){const L=r*8+k,row=mm.rd(gfx+t*8+k); for(let b=0;b<8;b++){const X=c*8+b,o=L*256+X,sp=spr[o]; if(sp>=0||en[o])hs=true;
      const want=en[o]?(NEG?7:0):sp===0?paper:((row>>(7-b))&1?ink:paper); if(pix(mm,X,L+32)!==want) e=true;}}
    if(hs) sprCells++; if(e) bad++; }
}
console.log(`клеток ${tot}, со спрайтом ${sprCells}, расхождений ${bad}`);
