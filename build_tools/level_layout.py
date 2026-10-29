"""Independent Mode 1 planes; precomputed relative row/column lookups.

PL, version 2, FG width/height, BG width/height (six big-endian words).
Each plane has 32 word row offsets and 256 word column offsets. Offsets
are relative to that plane's lookup table. Cells are unsigned word chunk IDs.
Foreground outside its authored rectangle is empty; background repeats.
No RAM addresses, runtime relocation, multiplication or validation is needed.
"""
from pathlib import Path
import struct
from convert_s1_ss_background import kosinski_plus, kosinski_plus_decode
MAGIC=0x504C
VERSION=2
ROWS=32
COLS=256
HEADER=12
PLANE=ROWS*2+COLS*2
DATA=HEADER+PLANE*2
CAPACITY=0x8000
CHUNKS=0x400

def dimensions(plane):
    h=len(plane);w=len(plane[0]) if h else 0
    if not (1<=w<=COLS and 1<=h<=ROWS) or any(len(row)!=w for row in plane):
        raise ValueError('Plane dimensions must be 1..256 by 1..32')
    if any(not 0<=v<CHUNKS for row in plane for v in row):
        raise ValueError('Chunk ID exceeds the 1024-chunk Mode 1 bank')
    return w,h

def encode(fg,bg):
    fw,fh=dimensions(fg);bw,bh=dimensions(bg)
    out=bytearray(struct.pack('>6H',MAGIC,VERSION,fw,fh,bw,bh)+bytes(PLANE*2))
    for n,plane in enumerate((fg,bg)):
        w,h=dimensions(plane);base=HEADER+n*PLANE;start=len(out)
        for row in plane:
            out.extend(struct.pack('>'+str(w)+'H',*row))
            if not n:out.extend(b'\0\0')
        blank=len(out)
        if not n:out.extend(bytes((w+1)*2))
        for y in range(ROWS):
            row=start+(y%h)*w*2 if n else (start+y*(w+1)*2 if y<h else blank)
            struct.pack_into('>H',out,base+y*2,row-base)
        for x in range(COLS):
            column=x%w if n else min(x,w)
            struct.pack_into('>H',out,base+ROWS*2+x*2,column*2)
    if len(out)>CAPACITY:raise ValueError('Layout exceeds the CD plane allocation')
    return bytes(out)

def decode(data,validate=True):
    if len(data)<DATA or struct.unpack_from('>2H',data)!=(MAGIC,VERSION):
        raise ValueError('Expected a version-2 independent-plane layout')
    fw,fh,bw,bh=struct.unpack_from('>4H',data,4)
    planes=[]
    for n,(w,h) in enumerate(((fw,fh),(bw,bh))):
        if not (1<=w<=COLS and 1<=h<=ROWS):raise ValueError('Invalid plane dimensions')
        base=HEADER+n*PLANE;plane=[]
        for y in range(h):
            row=base+struct.unpack_from('>H',data,base+y*2)[0]
            if row<DATA or row+w*2>len(data):raise ValueError('Row points outside cell data')
            plane.append(list(struct.unpack_from('>'+str(w)+'H',data,row)))
        planes.append(plane)
    if validate and encode(*planes)!=data:raise ValueError('Noncanonical or damaged plane lookup tables')
    return tuple(planes)

def load(path):return decode(kosinski_plus_decode(Path(path).read_bytes())[0])
def save(path,fg,bg):Path(path).write_bytes(kosinski_plus(encode(fg,bg)))

def compact_background(plane):
    """One complete old background span, excluding workaround copies/padding.

    This is an explicit import/migration operation, not a save-time rule.
    """
    dimensions(plane)
    width = max((x + 1 for row in plane for x, value in enumerate(row) if value), default=1)
    height = max((y + 1 for y, row in enumerate(plane) if any(row)), default=1)
    cells = [row[:width] for row in plane[:height]]
    period_x = next(n for n in range(1, width + 1)
                    if all(row[x] == row[x % n] for row in cells for x in range(width)))
    period_y = next(n for n in range(1, height + 1)
                    if all(cells[y] == cells[y % n] for y in range(height)))
    return [row[:period_x] for row in cells[:period_y]]


def from_s2(data):
    if len(data)!=4096:raise ValueError('Expected the former 128x16 S2 layout')
    fg=[list(data[y*256:y*256+128]) for y in range(16)]
    bg=[list(data[y*256+128:y*256+256]) for y in range(16)]
    fw=max((x+1 for row in fg for x,v in enumerate(row) if v),default=1)
    fh=max((y+1 for y,row in enumerate(fg) if any(row)),default=1)
    bw=next(w for w in range(1,129) if all(row[x]==row[x%w] for row in bg for x in range(128)))
    bh=next(h for h in (1,2,4,8,16) if all(bg[y]==bg[y%h] for y in range(16)))
    return [row[:fw] for row in fg[:fh]],compact_background([row[:bw] for row in bg[:bh]])

def to_s2(fg,bg):
    """Expand old-world coordinates for importers/oracles; never a runtime fallback."""
    fw,fh=dimensions(fg);bw,bh=dimensions(bg)
    if fw>128 or fh>16 or any(v>255 for p in (fg,bg) for row in p for v in row):
        raise ValueError('Layout does not fit the old S2 fixture format')
    out=bytearray(4096)
    for y in range(16):
        for x in range(128):
            out[y*256+x]=fg[y][x] if y<fh and x<fw else 0
            out[y*256+128+x]=bg[y%bh][x%bw]
    return bytes(out)


def project_s2(data):
    """Old-world fixture/oracle projection, accepting either source revision."""
    if data[:2] == b'PL':
        return to_s2(*decode(data))
    if len(data) != 4096:
        raise ValueError('Expected a plane layout or former S2 fixture')
    return data
