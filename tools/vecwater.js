#!/usr/bin/env node
// Проверка воды (plat_water): 20 комнат телепортом по 300 кадров игры; экран до и после каждого вызова — каждая
// клетка-плоскость воды либо сдвинута ровно на 2 строки в сторону FE9C (06.11: сдвиг через SP), либо не тронута —
// клетка с узором только под показанным персонажем (wr_rects).
//   node tools/vecwater.js [образ]
'use strict';
const R=require('path').join(__dirname,'..'),fs=require('fs');
const E=require(R+'/tools/vec_emu'),VK=require(R+'/tools/vecshot_keys');
const sym={};for(const l of fs.readFileSync(R+'/build/vec/brucelee.sym','latin1').split('\n')){const q=l.match(/^([\w.]+):\s+EQU\s+0x([0-9A-F]+)/i);if(q)sym[q[1]]=parseInt(q[2],16);}
const m=E.mk(process.argv[2]||R+'/build/vec/brucelee.bin'); if(process.env.NEG) m.wr(sym.water_cell,0xC9); /* негативный контроль: вода не крутится */ let room=0,state='title',tourEnd=0; const ROOMS=[...Array(20).keys()];
let pend=null; const st={calls:0,rot:0,same:0,bad:0,ex:[]};
m.onInstr=pc=>{
  if(pend&&pc===pend.ret&&m.cpu.sp===pend.sp+2){ // проверка
    const {pre,r0,c0,nc,nr,dn}=pend; st.calls++;
    for(let r=r0;r<r0+nr&&r<24;r++)for(let c=c0;c<c0+nc;c++)for(const P of [0xA000,0xC000,0xE000]){
      const a0=P+(c<<8)+223-r*8; const o=[],n=[]; for(let k=0;k<8;k++){o.push(pre[a0-k-0xA000]); n.push(m.rd(a0-k));}
      const exp=o.map((_,k)=>dn?o[(k+6)%8]:o[(k+2)%8]);
      if(n.every((v,k)=>v===o[k])){ st.same++;
        // не тронута клетка с узором (сдвиг бы её изменил) — только под персонажем (wr_rects: есть, r0, r1, c0, c1 x 3)
        if(!o.every((v,k)=>v===o[(k+2)%8])||!o.every((v,k)=>v===o[(k+6)%8])){ let under=false; for(let i=0;i<3;i++){const w=sym.wr_rects+5*i; if(m.rd(w)&&r>=m.rd(w+1)&&r<=m.rd(w+2)&&c>=m.rd(w+3)&&c<=m.rd(w+4)) under=true;}
          if(under) st.under=(st.under||0)+1; else {st.bad++; if(st.ex.length<3) st.ex.push({r,c,P:P.toString(16),o,n,why:'не сдвинута'});} } }
      else if(n.every((v,k)=>v===exp[k])) st.rot++; else {st.bad++; if(st.ex.length<3) st.ex.push({r,c,P:P.toString(16),o,n});}
    }
    pend=null; }
  if(pc===sym.plat_water&&!pend){ const sp=m.cpu.sp; const pre=new Uint8Array(0x6000); for(let a=0;a<0x6000;a++)pre[a]=m.rd(0xA000+a);
    const g=m.regs().split(',').map(Number); // pc,sp,iff,f, b,c,d,e,h,l,?,a (порядок regs ядра)
    const B=g[4],C=g[5],H=g[8],L=g[9]; const h=H&0x5F;
    pend={sp,ret:m.rd(sp)|m.rd(sp+1)<<8,pre,r0:(h&0x18)|(L>>5),c0:L&31,nc:B,nr:C,dn:(m.rd(sym.zv_FE9C)&0x80)?1:0}; }
  if(pc!==sym.pass) return; if(state==='title') state='go';
  if(state==='tour'&&m.frames>=tourEnd){ room++; state=room<20?'go':'done'; }
  if(state==='loaded'){ state='tour'; tourEnd=m.frames+300; }
  if(state==='go'){ m.wr(sym.zv_FE0E,room); m.wr(sym.zv_FE04,1); m.wr(sym.zv_FED0,0x30); m.wr(sym.zv_FED1,0x39); m.cpu.pc=sym.next_player; state='loaded'; } };
const plan=VK.parse('160:space+ 200:space-'); let sd=5; const rnd=()=>(sd=(sd*1103515245+12345)&0x7fffffff)/0x7fffffff;
for(let f=0;f<20000&&state!=='done';f++){ if(state==='tour'&&f%10===0) for(const k of ['left','right','up','down','space']) VK.apply(m,[[k,rnd()<0.3]]); VK.apply(m,plan[f]); m.frame(); }
console.log(`вода: вызовов ${st.calls}, сдвинуто ${st.rot}, не тронуто ${st.same} (с узором под персонажами ${st.under||0}), неверно ${st.bad}`+(st.ex.length?' '+JSON.stringify(st.ex[0]):'')); process.exit(st.bad||!st.calls?1:0);
