# SCREEN 2 (TMS9918 Graphics II) + спрайты из VRAM и регистров -> PNG
import sys
from PIL import Image
PAL=[(0,0,0),(0,0,0),(33,200,66),(94,220,120),(84,85,237),(125,118,252),(212,82,77),(66,235,245),(252,85,84),(255,121,120),(212,193,84),(230,206,128),(33,176,59),(201,91,186),(204,204,204),(255,255,255)]
def render(vram, regs, sprites=True):
    r0,r1=regs[0],regs[1]
    name=(regs[2]&0x0F)<<10
    m2 = r0&2
    col=(regs[3]&0x80)<<6 if m2 else regs[3]<<6
    pat=(regs[4]&0x04)<<11 if m2 else (regs[4]&7)<<11
    bd=regs[7]&15
    im=Image.new('RGB',(256,192))
    px=im.load()
    for y in range(192):
        for x in range(256):
            cy,cx=y>>3,x>>3; t=vram[name+cy*32+cx]
            if m2:
                third=(cy>>3)*256
                pa=pat+((third+t)<<3)+(y&7); ca=col+((third+t)<<3)+(y&7)
                if not (regs[4]&3)==3: pa=pat+(((third+t)&((regs[4]&3)<<8|0xFF))<<3)+(y&7)
                if not (regs[3]&0x7F)==0x7F: ca=col+(((third+t)&((regs[3]&0x7F)<<3|7))<<3)+(y&7)
                p=vram[pa]; c=vram[ca]
            else:
                p=vram[pat+t*8+(y&7)]; c=vram[col+(t>>3)]
            fg,bg=c>>4,c&15
            v = fg if (p>>(7-(x&7)))&1 else bg
            px[x,y]=PAL[v if v else bd]
    if sprites:
        sat=(regs[5]&0x7F)<<7; spg=(regs[6]&7)<<11; big=r1&2; mag=r1&1
        sz=16 if big else 8
        for i in range(32):
            yy=vram[sat+i*4]
            if yy==208: break
            xx=vram[sat+i*4+1]; nm=vram[sat+i*4+2]; cl=vram[sat+i*4+3]
            if cl&0x80: xx-=32
            yy=(yy+1)&255
            if yy>=192+32: yy-=256
            c=cl&15
            if not c: continue
            if big: nm&=0xFC
            for dy in range(sz):
                for dx in range(sz):
                    b = vram[spg+nm*8+(dx>>3)*16+dy] if big else vram[spg+nm*8+dy]
                    if (b>>(7-(dx&7)))&1:
                        X,Y=xx+dx,yy+dy
                        if 0<=X<256 and 0<=Y<192: px[X,Y]=PAL[c]
    return im
if __name__=='__main__':
    for n in sys.argv[1:]:
        v=open(n+'_vram.bin','rb').read(); r=open(n+'_regs.bin','rb').read()
        render(v,r).resize((512,384),Image.NEAREST).save(n+'.png'); print(n,'regs',r.hex())
