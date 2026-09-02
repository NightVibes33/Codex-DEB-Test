#!/usr/bin/env python3
import os, struct, sys, zlib

outdir = sys.argv[1] if len(sys.argv) > 1 else os.path.join('app','Resources')
os.makedirs(outdir, exist_ok=True)

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

def write_png(path, size):
    rows=[]
    for y in range(size):
        row=bytearray([0])
        for x in range(size):
            t=(x+y)/(2*(size-1))
            r=int(17 + 40*t); g=int(18 + 36*t); b=int(28 + 78*t)
            # cyan/purple waveform + B/T monogram-like bars
            cx=x/size; cy=y/size
            wave=abs(cy-(0.50 + 0.08*__import__('math').sin(cx*18))) < 0.018
            bar1=(0.28<cx<0.34 and 0.25<cy<0.73)
            bar2=(0.34<cx<0.55 and (abs(cy-0.30)<0.035 or abs(cy-0.49)<0.035 or abs(cy-0.69)<0.035))
            stem=(0.64<cx<0.70 and 0.26<cy<0.71)
            top=(0.58<cx<0.77 and 0.24<cy<0.30)
            if wave or bar1 or bar2 or stem or top:
                r,g,b=91,225,255
            row.extend((r,g,b,255))
        rows.append(bytes(row))
    raw=b''.join(rows)
    png=b'\x89PNG\r\n\x1a\n'
    png+=chunk(b'IHDR', struct.pack('>IIBBBBB', size,size,8,6,0,0,0))
    png+=chunk(b'IDAT', zlib.compress(raw,9))
    png+=chunk(b'IEND', b'')
    with open(path,'wb') as f: f.write(png)

write_png(os.path.join(outdir,'AppIcon60x60@2x.png'),120)
write_png(os.path.join(outdir,'AppIcon60x60@3x.png'),180)
print(outdir)
