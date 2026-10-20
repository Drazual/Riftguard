"""Builds the Coral Spiral backdrop: six 768x416 frames (water, foam, palms, umbrellas, flags, boats, signs and
fans move between them) and the logic grid. The road spirals clockwise from the entry gate on the left beach
in to the core in the middle of the plaza."""
import json, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = os.path.dirname(os.path.abspath(__file__))
os.chdir(ROOT)
CANAL = os.path.join(ROOT, '..', 'canal_art', 'spr')
COLS, ROWS = 24, 15
CW, CH, TD = 64, 48, 64          # 2x art: a cell is 64x48 on screen, 64x64 before the 3/4 squash
OY = 64                           # 2x art: the grid starts below the back wall
W2, H2 = 1536, 832
PRE = 2                           # rows drawn above the grid (top-down canvas starts at row -2)
TDH = (ROWS + PRE + 1) * TD       # top-down canvas height (rows -2..15)
NF = 6
FONT = os.path.join(ROOT, '..', '..', 'assets', 'fonts', 'Oxanium.ttf')


def td(c, r):
    return c * TD, (r + PRE) * TD


def ctr(c, r):
    x, y = td(c, r)
    return x + TD // 2, y + TD // 2


def seg(a, b):
    """cells from a to b inclusive along a row or column"""
    (c0, r0), (c1, r1) = a, b
    dc, dr = (c1 > c0) - (c1 < c0), (r1 > r0) - (r1 < r0)
    out = [a]
    while out[-1] != b:
        out.append((out[-1][0] + dc, out[-1][1] + dr))
    return out


# ---------- logic: the spiral ----------
legs = [((0, 5), (5, 5)), ((5, 4), (5, 2)), ((6, 2), (19, 2)), ((19, 3), (19, 12)), ((18, 12), (8, 12)),
        ((8, 11), (8, 5)), ((9, 5), (16, 5)), ((16, 6), (16, 9)), ((15, 9), (12, 9)), ((12, 8), (12, 7))]
path = []
for a, b in legs:
    path += seg(a, b)
pset = set(path)
assert len(pset) == len(path)
for i, p in enumerate(path):  # the road must be one line: no tile touches a road tile other than its neighbours
    for q in path[i + 2:]:
        assert abs(p[0] - q[0]) + abs(p[1] - q[1]) > 1, (p, q)

# island: sand from column 1 to 22 and row -1 to 14, with a bay for the boats on the lower left
X0, X1 = 64, 1472
Y0, Y1 = td(0, -1)[1] + 24, td(0, 15)[1]
BAY = (X0, td(0, 8)[1], 128, td(0, 14)[1])
yy, xx = np.mgrid[0:TDH, 0:W2]
island = (xx >= X0) & (xx < X1) & (yy >= Y0) & (yy < Y1)
island &= ~((xx >= BAY[0]) & (xx < BAY[2]) & (yy >= BAY[1]) & (yy < BAY[3]))
# round the corners a little
island = ndimage.binary_opening(island, structure=np.ones((3, 3)), iterations=10)
water = set()
for r in range(ROWS):
    for c in range(COLS):
        x, y = td(c, r)
        if island[y + 8:y + TD - 8, x + 8:x + TD - 8].mean() < 0.5 and (c, r) not in pset:
            water.add((c, r))
blocked = set()
rs = np.random.RandomState(3)

# ---------- static ground (top-down) ----------
g = np.zeros((TDH, W2, 3), np.float32)
# beach sand
g[:] = np.array([246, 204, 160], np.float32)
g += rs.normal(0, 5, (TDH, W2, 1))
for _ in range(1600):
    x, y = rs.randint(0, W2 - 3), rs.randint(0, TDH - 3)
    g[y:y + 2, x:x + 2] = g[y:y + 2, x:x + 2] * 0.5 + np.array([236, 120, 150]) * 0.5
# the plaza: pale pink-cream tiles
PX0, PY0 = td(2, 0)
PX1, PY1 = td(22, 14)
pl = (xx >= PX0) & (xx < PX1) & (yy >= PY0) & (yy < PY1)
pa = np.zeros((TDH, W2, 3), np.float32)
pa[:] = np.array([244, 214, 204], np.float32)
jit = rs.uniform(-6, 6, (TDH // 32 + 1, W2 // 32 + 1))
pa += jit[yy // 32, xx // 32][..., None] * np.array([1, 0.85, 0.8])
pa += rs.normal(0, 3, (TDH, W2, 1))
grout = ((yy % 64) < 2) | ((xx % 64) < 2)
pa[grout] = pa[grout] * 0.5 + np.array([214, 170, 178]) * 0.5
fine = (((yy % 64) == 32) | ((xx % 64) == 32)) & ~grout
pa[fine] = pa[fine] * 0.8 + np.array([222, 184, 190]) * 0.2
g[pl] = pa[pl]
img = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(img)
# plaza kerb: a pink stone edge with a shadow onto the sand
d.rectangle((PX0 - 6, PY0 - 6, PX1 + 5, PY1 + 5), outline=(226, 150, 176), width=6)
d.rectangle((PX0 - 9, PY0 - 9, PX1 + 8, PY1 + 8), outline=(170, 110, 140), width=3)

# rocks on the beach corners
def rock(cx, cy, s):
    for k in range(3):
        ox, oy = rs.randint(-s, s), rs.randint(-s // 2, s // 2)
        r = rs.randint(s // 2, s)
        d.ellipse((cx + ox - r, cy + oy - r * 0.8, cx + ox + r, cy + oy + r * 0.8), fill=(86, 78, 120))
        d.ellipse((cx + ox - r + 3, cy + oy - r * 0.8 + 2, cx + ox + r - 5, cy + oy + r * 0.4), fill=(128, 118, 160))
        d.ellipse((cx + ox - r * 0.4, cy + oy - r * 0.6, cx + ox + r * 0.1, cy + oy - r * 0.2), fill=(170, 160, 196))

for c, r in ((1, 7), (1, 14), (22, 14), (22, 8), (12, 14), (1, -1), (6, 14)):
    x, y = ctr(c, r)
    rock(x, y + 14, 14)
# starfish and shells
for _ in range(26):
    c, r = rs.choice([1, 22]), rs.randint(-1, 15)
    if rs.rand() < 0.5:
        c, r = rs.randint(1, 23), rs.choice([14, -1])
    x, y = ctr(c, r)
    x += rs.randint(-24, 24); y += rs.randint(-20, 20)
    col = [(248, 120, 150), (255, 170, 120), (250, 236, 220)][rs.randint(3)]
    for a in range(5):
        t = a * 2 * math.pi / 5
        d.line((x, y, x + 6 * math.cos(t), y + 6 * math.sin(t)), fill=col, width=3)

# docks in the bay and the pier the road takes over the water
WOOD, WOOD_D = (176, 116, 96), (104, 64, 70)
for r in (9, 12):
    x0, y0 = 0, td(0, r)[1] + 20
    for x in range(x0, 132, 10):
        d.rectangle((x, y0, x + 8, y0 + 26), fill=WOOD)
        d.line((x + 9, y0, x + 9, y0 + 26), fill=WOOD_D)
    for x in (6, 60, 112):
        d.rectangle((x, y0 + 24, x + 8, y0 + 34), fill=WOOD_D)
static_ground = img.convert('RGBA')
static_ground.putalpha(Image.fromarray((island * 255).astype(np.uint8)))
docks = Image.new('RGBA', img.size, (0, 0, 0, 0))
docks.paste(img.crop((0, td(0, 9)[1], 132, td(0, 13)[1])), (0, td(0, 9)[1]))
dk = np.asarray(docks).copy()
dmask = np.zeros(dk.shape[:2], bool)
for r in (9, 12):
    y0 = td(0, r)[1] + 20
    dmask[y0:y0 + 35, 0:132] = True
dk[..., 3] = np.where(dmask & ~island, 255, 0)
docks = Image.fromarray(dk, 'RGBA')

# ---------- the road ----------
road = Image.new('RGBA', img.size, (0, 0, 0, 0))
rd = ImageDraw.Draw(road)
pts = [ctr(-1, 5)] + [ctr(*p) for p in path]
cp = [pts[0]]
for i in range(1, len(pts) - 1):
    a, b, e = pts[i - 1], pts[i], pts[i + 1]
    if (b[0] - a[0], b[1] - a[1]) != (e[0] - b[0], e[1] - b[1]):
        cp.append(b)
cp.append(pts[-1])
rd.line(cp, fill=(250, 150, 206, 255), width=62, joint='curve')
rd.line(cp, fill=(150, 70, 130, 255), width=56, joint='curve')
rd.line(cp, fill=(44, 38, 74, 255), width=52, joint='curve')
ra = np.asarray(road).astype(np.float32)
asph = (ra[..., :3] == np.array([44, 38, 74])).all(-1)
noise = rs.normal(0, 4, ra.shape[:2])
ra[..., :3][asph] += noise[asph][:, None]
road = Image.fromarray(np.clip(ra, 0, 255).astype(np.uint8), 'RGBA')
br = ImageDraw.Draw(road)
# railings on the pier over the water
xa, yb = td(-1, 5)
xb = td(1, 5)[0]
for yr in (yb + 1, yb + TD - 5):
    br.rectangle((0, yr, xb, yr + 3), fill=(240, 226, 236, 255))
    for x in range(0, xb, 14):
        br.rectangle((x, yr - 1, x + 3, yr + 4), fill=(150, 70, 130, 255))

# lane markings: cyan dashes and arrows the way enemies walk
CY, CYD = (98, 226, 242), (40, 120, 150)
marks = Image.new('RGBA', img.size, (0, 0, 0, 0))
md = ImageDraw.Draw(marks)
dirs = {}
for i, p in enumerate(path):
    nxt = path[i + 1] if i + 1 < len(path) else None
    prv = path[i - 1] if i > 0 else (-1, 5)
    dirs[p] = (nxt[0] - p[0], nxt[1] - p[1]) if nxt else (p[0] - prv[0], p[1] - prv[1])
corner = {path[i] for i in range(1, len(path) - 1)
          if (path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]) != (path[i + 1][0] - path[i][0], path[i + 1][1] - path[i][1])}
arrow_at, run = set(), 0
for i, p in enumerate(path):
    near = any(path[j] in corner for j in range(max(0, i - 1), min(len(path), i + 2)))
    run += 1
    if 1 <= i < len(path) - 2 and not near and run >= 3:
        arrow_at.add(p)
        run = 0
for i, p in enumerate(path):
    if p in corner or i == len(path) - 1:
        continue
    cx, cy = ctr(*p)
    dx, dy = dirs[p]
    if p in arrow_at:
        tip = (cx + dx * 18, cy + dy * 18)
        tail = (cx - dx * 16, cy - dy * 16)
        px, py = -dy, dx
        base = (cx + dx * 4, cy + dy * 4)
        head = [tip, (base[0] + px * 10, base[1] + py * 10), (base[0] - px * 10, base[1] - py * 10)]
        md.line((tail, base), fill=CYD, width=8)
        md.polygon([(h[0] + dx * 2, h[1] + dy * 2) for h in head], fill=CYD)
        md.line((tail, base), fill=CY, width=4)
        md.polygon(head, fill=CY)
        continue
    for k in (-24, 4):
        md.line(((cx + dx * k, cy + dy * k), (cx + dx * (k + 18), cy + dy * (k + 18))), fill=CY, width=3)
road.alpha_composite(marks)


# ---------- animated sheets ----------
def frames(name, folder=None):
    s = Image.open(os.path.join(folder or 'spr', name + '.png')).convert('RGBA')
    w = s.width // NF
    return [s.crop((i * w, 0, (i + 1) * w, s.height)) for i in range(NF)]


def water_tex(name, size=128):
    s = Image.open('spr/water_%s.png' % name).convert('RGB')
    w = s.width // NF
    return [np.asarray(s.crop((i * w, 0, (i + 1) * w, s.height)).resize((size, size), Image.LANCZOS)).astype(np.float32) for i in range(NF)]


deep, mid = water_tex('deep'), water_tex('mid')
dist = ndimage.distance_transform_edt(~island)
near_t = np.clip(1 - dist / 110, 0, 1)[..., None]
foams = {k: frames('foam_' + k) for k in ('top', 'bottom', 'left', 'right')}


def tile(t):
    reps = (TDH // t.shape[0] + 1, W2 // t.shape[1] + 1, 1)
    return np.tile(t, reps)[:TDH, :W2]


def foam_layer(k):
    lay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    j = 0

    def stamp(kind, x, y):
        nonlocal j
        f = foams[kind][(k + j) % NF]
        j += 1
        if kind in ('top', 'bottom'):
            f = f.resize((136, round(f.height * 136 / f.width)), Image.LANCZOS)
            lay.alpha_composite(f, (int(x), int(y - f.height + 12 if kind == 'top' else y - 12)))
        else:
            f = f.resize((round(f.width * 136 / f.height), 136), Image.LANCZOS)
            lay.alpha_composite(f, (int(x - f.width + 12 if kind == 'left' else x - 12), int(y)))

    for x in range(X0 - 8, X1, 120):
        stamp('top', x, Y0)
        stamp('bottom', x, Y1)
    for y in range(Y0 - 8, Y1, 120):
        stamp('right', X1, y)
        if not (BAY[1] - 60 < y < BAY[3]):
            stamp('left', X0, y)
    for y in range(BAY[1], BAY[3] - 60, 120):
        stamp('left', BAY[2], y)
    stamp('bottom', X0 - 40, BAY[1])
    stamp('top', X0 - 40, BAY[3])
    return lay


# ---------- props (upright, drawn after the 3/4 squash) ----------
props = []  # sort key, frames or image, x, y, shadow info


def scaled(im, sc):
    return im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.LANCZOS)


def place(src, c0, r0, c1, r1, width=None, height=None, flip=False, block=True, dy=0, dx=0, shadow=True, phase=0, sort_dr=0):
    fs = src if isinstance(src, list) else [src]
    fw = (c1 - c0 + 1) * CW
    sc = height / fs[0].height if height else (width or fw * 0.9) / fs[0].width
    fs = [scaled(f.transpose(Image.FLIP_LEFT_RIGHT) if flip else f, sc) for f in fs]
    cx = c0 * CW + fw / 2 + dx
    by = OY + (r1 + 1) * CH - 4 + dy
    props.append(((r1 + sort_dr, c0, len(props)), fs, phase, round(cx - fs[0].width / 2), round(by - fs[0].height), shadow, cx, by, fw))
    if block:
        for c in range(c0, c1 + 1):
            for r in range(max(0, r0), min(ROWS - 1, r1) + 1):
                blocked.add((c, r))


def canal(name):
    return Image.open(os.path.join(CANAL, name + '.png')).convert('RGBA')


def font(sz):
    return ImageFont.truetype(FONT, sz)


def neon_sign(text, w, h, col=(255, 90, 190), glow=(98, 226, 242)):
    s = Image.new('RGBA', (w + 8, h + 8), (0, 0, 0, 0))
    sd = ImageDraw.Draw(s)
    sd.rounded_rectangle((2, 2, w + 5, h + 5), 5, fill=(30, 22, 56, 255), outline=col, width=3)
    f = font(int(h * 0.62))
    sd.text(((w + 8) / 2, (h + 8) / 2 + 1), text, font=f, fill=glow, anchor='mm', stroke_width=1, stroke_fill=glow)
    return s


def relabel(b, text, box):
    b = b.copy()
    x0, y0, x1, y1 = box
    b.alpha_composite(neon_sign(text, x1 - x0, y1 - y0), (x0 - 4, y0 - 4))
    return b


def lifeguard():
    s = Image.new('RGBA', (130, 190), (0, 0, 0, 0))
    sd = ImageDraw.Draw(s)
    for x in (18, 100):
        sd.rectangle((x, 90, x + 10, 186), fill=(150, 96, 84), outline=(80, 48, 60))
    sd.line((24, 186, 104, 100), fill=(120, 76, 72), width=5)
    sd.line((24, 100, 104, 186), fill=(120, 76, 72), width=5)
    sd.rectangle((8, 84, 122, 96), fill=(196, 132, 108), outline=(80, 48, 60))
    sd.rectangle((18, 34, 112, 86), fill=(246, 240, 236), outline=(80, 48, 60), width=2)
    sd.rectangle((30, 46, 62, 70), fill=(98, 200, 232), outline=(60, 90, 140), width=2)
    sd.rectangle((80, 46, 92, 76), fill=(255, 60, 110))
    sd.rectangle((70, 56, 102, 66), fill=(255, 60, 110))
    sd.polygon([(4, 38), (65, 6), (126, 38)], fill=(255, 92, 168), outline=(120, 40, 90))
    sd.rectangle((4, 36, 126, 42), fill=(214, 60, 140))
    # ladder
    for y in range(100, 186, 14):
        sd.line((52, y, 76, y), fill=(196, 150, 120), width=3)
    sd.line((52, 96, 52, 186), fill=(150, 96, 84), width=3)
    sd.line((76, 96, 76, 186), fill=(150, 96, 84), width=3)
    return s


def aquarium():
    s = Image.new('RGBA', (180, 124), (0, 0, 0, 0))
    sd = ImageDraw.Draw(s)
    sd.ellipse((20, 4, 160, 120), fill=(40, 120, 190), outline=(30, 40, 90), width=3)
    sd.ellipse((30, 12, 150, 112), fill=(60, 170, 220))
    sd.ellipse((40, 20, 140, 104), fill=(90, 206, 236))
    for fx, fy, col in ((70, 40, (255, 170, 60)), (104, 58, (255, 110, 170)), (60, 70, (255, 230, 120)), (120, 36, (255, 140, 90))):
        sd.ellipse((fx, fy, fx + 14, fy + 8), fill=col)
        sd.polygon([(fx + 14, fy + 4), (fx + 20, fy), (fx + 20, fy + 8)], fill=col)
    sd.arc((44, 18, 110, 80), 200, 260, fill=(230, 250, 255), width=4)
    sd.rectangle((6, 78, 174, 122), fill=(240, 220, 226), outline=(110, 60, 110), width=3)
    sd.rectangle((70, 96, 110, 122), fill=(70, 200, 230), outline=(40, 60, 110), width=2)
    s.alpha_composite(neon_sign('AQUA', 112, 24, glow=(120, 240, 255)), (34, 70))
    return s


def entry_sign():
    s = Image.new('RGBA', (150, 120), (0, 0, 0, 0))
    sd = ImageDraw.Draw(s)
    for x in (10, 128):
        sd.rectangle((x, 30, x + 12, 118), fill=(232, 210, 230), outline=(110, 60, 120), width=2)
        sd.rectangle((x + 3, 40, x + 9, 110), fill=(255, 90, 190))
    s.alpha_composite(neon_sign('ENTRY', 136, 34), (3, 0))
    return s


# the core at the end of the road, with neon palms either side
place(canal('rift'), 12, 7, 12, 7, width=62, block=False, shadow=False, dy=-4)
place(frames('neonpalm'), 11, 7, 11, 7, height=86, phase=0)
place(frames('neonpalm'), 13, 7, 13, 7, height=86, phase=3, flip=True)

# top row: surf shop, diner, arcade, lifeguard tower, with palms and umbrellas between
surf = relabel(canal('b1'), 'SURF', (52, 142, 124, 168))
place(surf, 2, 0, 4, 1, width=166)
place(frames('palm_pink'), 5, 0, 5, 1, height=110, phase=1)
place(canal('b0'), 6, 0, 8, 1, width=172)
place(frames('fan'), 9, 0, 9, 0, width=50, phase=2)
place(frames('umbrella'), 9, 1, 9, 1, height=70, phase=2)
place(frames('palm_teal'), 10, 0, 10, 0, height=104, phase=4)
arc = canal('b2')
place(arc, 11, 0, 13, 1, width=166)
place(frames('arcadesign'), 11, 0, 13, 0, width=124, block=False, shadow=False, dy=-24, sort_dr=1)
place(frames('palm_pink'), 14, 1, 14, 1, height=104, phase=3)
place(frames('lamp'), 15, 1, 15, 1, height=62, phase=0)
place(frames('palm_teal'), 16, 0, 16, 0, height=104, phase=2)
place(frames('umbrella'), 17, 1, 17, 1, height=70, phase=5)
place(frames('palm_pink'), 18, 0, 18, 0, height=104, phase=0)
place(frames('flag'), 19, 1, 19, 1, height=64, phase=1)
place(lifeguard(), 20, 0, 21, 1, height=132)
place(frames('flag'), 21, 0, 21, 0, height=60, phase=4, block=False, dy=-92, dx=30, sort_dr=1, shadow=False)
place(frames('palm_teal'), 22, 0, 22, 0, height=100, phase=5)

# right beach and the open water past it
place(frames('umbrella'), 22, 3, 22, 3, height=66, phase=1)
place(frames('palm_pink'), 22, 5, 22, 5, height=100, phase=2)
place(frames('flag'), 22, 9, 22, 9, height=60, phase=3)
place(frames('umbrella'), 22, 11, 22, 11, height=66, phase=4)
place(frames('palm_teal'), 22, 13, 22, 13, height=100, phase=1)
place(frames('buoy'), 23, 2, 23, 2, height=50, phase=0, block=False, shadow=False)
place(frames('jetski'), 23, 5, 23, 5, height=62, phase=2, block=False, shadow=False)
place(frames('pad'), 23, 8, 23, 8, width=60, phase=4, block=False, shadow=False)
place(frames('speedboat'), 23, 11, 23, 12, height=96, phase=1, block=False, shadow=False)
place(frames('buoy'), 23, 14, 23, 14, height=48, phase=3, block=False, shadow=False)

# left beach: entry sign over the road, palms, and the boats in the bay
place(entry_sign(), 1, 4, 2, 4, width=104, block=True)
place(frames('flag'), 1, 6, 1, 6, height=60, phase=2)
place(frames('palm_teal'), 1, 1, 1, 1, height=100, phase=3)
place(frames('umbrella'), 1, 3, 1, 3, height=62, phase=0, dx=-4)
place(frames('palm_pink'), 1, 7, 1, 7, height=96, phase=5)
place(frames('speedboat'), 0, 9, 0, 10, height=94, phase=3, block=False, shadow=False, dx=2, dy=4)
place(frames('jetski'), 1, 11, 1, 11, height=58, phase=1, block=False, shadow=False, dy=10)
place(frames('buoy'), 0, 13, 0, 13, height=44, phase=5, block=False, shadow=False)
place(frames('pad'), 0, 0, 0, 0, width=50, phase=2, block=False, shadow=False, dy=-20)

# bottom: the aquarium, palms and umbrellas on the sand
place(aquarium(), 14, 14, 16, 14, height=96, dy=6)
place(frames('fan'), 17, 14, 17, 14, width=50, phase=4)
place(frames('palm_teal'), 2, 14, 2, 14, height=96, phase=0)
place(frames('umbrella'), 4, 14, 4, 14, height=64, phase=3)
place(frames('palm_pink'), 6, 14, 6, 14, height=96, phase=1)
place(frames('umbrella'), 9, 14, 9, 14, height=64, phase=5)
place(frames('palm_teal'), 11, 14, 11, 14, height=96, phase=2)
place(frames('flag'), 13, 14, 13, 14, height=58, phase=0)
place(frames('umbrella'), 18, 14, 18, 14, height=64, phase=2)
place(frames('palm_pink'), 20, 14, 20, 14, height=96, phase=4)
place(frames('lamp'), 2, 13, 2, 13, height=58, phase=3)
place(frames('lamp'), 21, 13, 21, 13, height=58, phase=1)

# the plaza: a fountain and a few lamps, leaving the ground by the road free for towers
place(frames('fountain'), 3, 9, 4, 10, width=118, phase=0)
place(frames('lamp'), 2, 6, 2, 6, height=58, phase=4)
place(frames('lamp'), 21, 6, 21, 6, height=58, phase=2)
place(frames('lamp'), 14, 7, 14, 7, height=58, phase=5)
place(frames('lamp'), 10, 7, 10, 7, height=58, phase=1)

props.sort(key=lambda p: p[0])
for p in pset:
    blocked.discard(p)
for w_ in water:
    blocked.discard(w_)

# ---------- render the frames ----------
shadows = Image.new('RGBA', (W2, H2), (0, 0, 0, 0))
shd = ImageDraw.Draw(shadows)
for key, fs, ph, x, y, shadow, cx, by, fw in props:
    if shadow:
        rx = min(fw, fs[0].width) * 0.42
        shd.ellipse((cx - rx, by - 8, cx + rx, by + 5), fill=(60, 30, 60, 80))
shadows = shadows.filter(ImageFilter.GaussianBlur(2))
os.makedirs('out', exist_ok=True)
for k in range(NF):
    wa = tile(deep[k]) * (1 - near_t) + tile(mid[k]) * near_t
    top = Image.fromarray(np.clip(wa, 0, 255).astype(np.uint8)).convert('RGBA')
    top.alpha_composite(docks)
    top.alpha_composite(static_ground)
    top.alpha_composite(foam_layer(k))
    top.alpha_composite(road)
    ground = top.resize((W2, int(TDH * 0.75)), Image.LANCZOS)
    canvas = Image.new('RGBA', (W2, H2), (16, 18, 35, 255))
    canvas.paste(ground, (0, OY - PRE * CH))
    canvas.alpha_composite(shadows)
    for key, fs, ph, x, y, shadow, cx, by, fw in props:
        f = fs[(k + ph) % len(fs)]
        fx = x + round((fs[0].width - f.width) / 2)
        if y < 0:
            canvas.alpha_composite(f.crop((0, -y, f.width, f.height)), (fx, 0))
        else:
            canvas.alpha_composite(f, (fx, y))
    canvas.resize((768, 416), Image.LANCZOS).save('out/coral_%d.png' % k)
    if k == 0:
        canvas.save('out/coral_2x.png')
json.dump({'path': path, 'water': sorted(water), 'blocked': sorted(blocked)}, open('coral_layout.json', 'w'))
print('blocked', len(blocked), 'water', len(water), 'path', len(path))
