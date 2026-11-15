# Rift Plaza: a new first map. A long road spirals in to the rift portal in the middle of a diamond plaza; tower spots
# are the plaza's diamond tiles (layout "snap"), so towers line up with the road. Buildings and props come from
# Ocean Drive (map1_miami/spr) and fill everything outside the diamond.
# python3 gen.py <out dir>   (needs numpy and Pillow)
import json, math, os, sys, random
import numpy as np
from PIL import Image, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
SPR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(OUT.rstrip('/'))), 'map1_miami', 'spr')
SPR_RES = 'res://assets/maps/map1_miami/spr/'
W, H = 768, 416          # board px
A = 2                    # art px per board px
TW = 48.0                # a tile (one tower spot) is a diamond TW x TH board px
TH = TW / math.sqrt(3)
N = 15                   # the plaza diamond is N x N tiles; tiles 1..N-2 are the playfield
X0, Y0 = (W - N * TW) / 2, H / 2
rng = random.Random(11)

def tb(u, v):  # tile centre, board px
    return np.array([X0 + (u + v + 1) * TW / 2, Y0 + (u - v) * TH / 2])
def bf(p):     # board px -> field
    return [round(float(p[0]) / 0.8, 3), round((float(p[1]) / 0.8 - 40) / 0.75, 3)]
def fb(f):
    return np.array([f[0] * 0.8, (40 + 0.75 * f[1]) * 0.8])
def ij_of_board(x, y):  # unrounded tile coords of a board point
    dx, dy = x - X0 - TW / 2, y - Y0
    s, d = dx / (TW / 2), dy / (TH / 2)   # s = u+v, d = u-v
    return (s + d) / 2, (s - d) / 2

# ---------- the road ----------
LEGS = [(1, -4), (1, 13), (13, 13), (13, 1), (4, 1), (4, 10), (10, 10), (10, 4), (7, 4), (7, 7)]
road_tiles = set()
for (u0, v0), (u1, v1) in zip(LEGS, LEGS[1:]):
    du, dv = np.sign(u1 - u0), np.sign(v1 - v0)
    u, v = u0, v0
    while (u, v) != (u1, v1):
        road_tiles.add((u, v)); u += du; v += dv
    road_tiles.add((u1, v1))
END = LEGS[-1]
PB = [tb(u, v) for u, v in LEGS]           # board px polyline
path_field = [bf(p) for p in PB]
# the portal stands just past the road's end (as on Ocean Drive) and covers these tiles
portal_tiles = {(6, 7), (8, 7), (6, 8), (7, 8), (8, 8), (6, 9), (7, 9), (8, 9)}
HERO = (5, 6)

def playfield(u, v):  # every tile of the square is a tower spot, so towers fit on both sides of the outer road
    return 0 <= u <= N - 1 and 0 <= v <= N - 1
def in_diamond(u, v):
    return 0 <= u <= N - 1 and 0 <= v <= N - 1

# ---------- distance field to the road (board px, at 1x and 2x) ----------
def road_field(scale):
    h, w = H * scale, W * scale
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    xx = (xx + 0.5) / scale; yy = (yy + 0.5) / scale
    best = np.full((h, w), 1e9); S = np.zeros((h, w)); Nn = np.zeros((h, w))
    cum = np.concatenate([[0], np.cumsum([np.linalg.norm(b - a) for a, b in zip(PB, PB[1:])])])
    for i, (a, b) in enumerate(zip(PB, PB[1:])):
        d = b - a; l = np.linalg.norm(d); uu = d / l
        t = np.clip((xx - a[0]) * uu[0] + (yy - a[1]) * uu[1], 0, l)
        dist = np.hypot(xx - a[0] - uu[0] * t, yy - a[1] - uu[1] * t)
        m = dist < best
        best[m] = dist[m]; S[m] = (cum[i] + t)[m]; Nn[m] = ((xx - a[0]) * -uu[1] + (yy - a[1]) * uu[0])[m]
    return xx, yy, best, S, Nn, cum

CORE, MAG, PINK = 7.0, 8.6, 10.4

# ---------- ground (1x, scaled up without smoothing) ----------
xx, yy, best, S, Nn, cum = road_field(1)
U, V = ij_of_board(xx, yy)
iu, iv = np.round(U).astype(int), np.round(V).astype(int)
fu, fv = U - iu, V - iv                      # -0.5..0.5 inside a tile
inside = (iu >= 0) & (iu <= N - 1) & (iv >= 0) & (iv <= N - 1)
img = np.zeros((H, W, 3))
# outside the plaza: Coral's small sidewalk tiles in a deeper rose
su, sv = U * 2, V * 2
hs = ((np.floor(su).astype(int) * 73856093) ^ (np.floor(sv).astype(int) * 19349663)) & 0x7fffffff
side = np.array([(226, 178, 182), (222, 174, 179), (229, 182, 186), (224, 176, 181)])
img[:] = side[hs % 4]
sl = (np.abs(su - np.round(su)) * TH < 0.5) | (np.abs(sv - np.round(sv)) * TH < 0.5)
img[sl & ~inside] = (206, 156, 166)
# the plaza: one big peach diamond per tower spot, with a lighter rim and a grout line
peach = np.array([(246, 216, 206), (243, 213, 203), (248, 218, 208)])
h = ((iu * 7349) ^ (iv * 1931)) & 0xffff
pl = peach[h % 3].astype(float)
rim = (np.maximum(np.abs(fu), np.abs(fv)) > 0.40)
pl[rim] = pl[rim] * 0.985 + 4
grout = np.maximum(np.abs(fu), np.abs(fv)) * TH * 2 > TH - 1.2
pl[grout] = (230, 192, 186)
img[inside] = pl[inside]
# a pink curb round the plaza
edge = inside & (((iu == 0) & (fu < -0.5 + 1.6 / TH)) | ((iv == 0) & (fv < -0.5 + 1.6 / TH)) |
                 ((iu == N - 1) & (fu > 0.5 - 1.6 / TH)) | ((iv == N - 1) & (fv > 0.5 - 1.6 / TH)))
img[edge] = (242, 138, 199)
# road: navy with pink neon edges, cyan dashes and an arrow on each straight stretch (Coral's road)
img[best < PINK] = (242, 138, 199)
img[best < MAG] = (105, 57, 105)
road = best < CORE
img[road] = (43, 37, 73)
nr = np.random.default_rng(5)
img[road & (nr.random((H, W)) < 0.10)] = (52, 45, 85)
img[road & (nr.random((H, W)) < 0.06)] = (44, 38, 74)
CY = (90, 206, 236)
per, AK = 12.0, 5
k = np.floor(S / per); f = S - k * per
dash = road & (np.abs(Nn) < 0.9) & (f < 5)
def dir_at(q):
    i = int(np.clip(np.searchsorted(cum, q) - 1, 0, len(PB) - 2)); d = PB[i + 1] - PB[i]; return d / np.linalg.norm(d)
t = S - np.floor(S / (per * AK)) * per * AK
t = np.where(t > per * AK - per, t - per * AK, t)
mid = np.round(S / (per * AK))
ok = {m: float(np.dot(dir_at(m * per * AK - per - 2), dir_at(m * per * AK + 9))) > 0.999 and m * per * AK + 9 < cum[-1] for m in np.unique(mid[road])}
straight = np.vectorize(lambda m: ok.get(m, False))(mid)
arrow = road & straight & (t > -per) & (t < 7) & (((t < 4) & (np.abs(Nn) < 0.9)) |
        ((t >= -1) & (np.abs(np.abs(Nn) - (6.0 - t) * 0.75) < 0.9) & (np.abs(Nn) < 4.2) & (t < 6.5)))
slot = road & straight & (t > -per) & (t < per)
img[dash & ~slot] = CY
img[arrow] = CY
ground = Image.fromarray(img.astype(np.uint8)).resize((W * A, H * A), Image.NEAREST)
ground.save(os.path.join(OUT, 'ground.png'))

# ---------- glints: the road's edge lines, with the distance along the road ----------
xx2, yy2, best2, S2, _, cum2 = road_field(A)
band = (best2 > MAG) & (best2 < PINK)
gl = np.zeros((H * A, W * A, 3), np.uint8)
sv16 = np.clip(S2 / cum2[-1] * 65535, 0, 65535).astype(int)
gl[band, 0] = 255; gl[band, 1] = (sv16 >> 8)[band]; gl[band, 2] = (sv16 & 255)[band]
Image.fromarray(gl).save(os.path.join(OUT, 'glints.png'))

# ---------- scenery ----------
def bbox(name):
    im = Image.open(os.path.join(SPR, name)).convert('RGBA')
    a = np.array(im)[..., 3]; ys, xs = np.where(a > 8)
    return im.size, (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
files = sorted(f for f in os.listdir(SPR) if f.endswith('.png'))
def group(prefix):
    return [f for f in files if f.startswith(prefix + '_') and f[len(prefix) + 1:].split('.')[0].isdigit()]
BLD = ['bld_apartments', 'bld_arcade', 'bld_cafe', 'bld_diner', 'bld_hotel', 'bld_motel', 'bld_nightclub',
       'bld_palmhotel', 'bld_records', 'bld_techshop', 'bld_theater']
FLAT = ['flower_tile', 'fountain_plaza', 'palm_planter_plaza', 'neon_fountain_tile', 'flower_plaza', 'hedge_sidewalk',
        'palms_hedge', 'tool_tile', 'plaza_props']
STAND = [('palm_planter_a', 'palm'), ('palm_planter_b', 'palm'), ('lamp', 'neon'), ('neon_sign_a', 'neon'),
         ('neon_sign_b', 'neon'), ('bench', 'prop'), ('trash', 'prop'), ('vending', 'prop'), ('phone_booth', 'prop')]
sprites = []
def put(name, kind, bottom, key, fit=None, label=None):
    (w, h), (x0, y0, x1, y1) = bbox(name)
    s = 1.0 if fit is None else fit / (x1 - x0)
    tl = [round(bottom[0] * A - s * (x0 + x1) / 2, 1), round(bottom[1] * A - s * y1, 1)]
    if tl[0] > W * A or tl[0] + s * w < 0 or tl[1] > H * A or tl[1] + s * h < 0:
        return
    it = {'tex': SPR_RES + name, 'tl': tl, 'key': round(key * A, 2), 'kind': kind, 'name': label or name.rsplit('_', 1)[0]}
    if s != 1.0:
        it['scale'] = round(s, 4)
    sprites.append(it)

def flat_tile(u, v, name=None):
    c = tb(u, v)
    name = name or rng.choice(group(rng.choice(FLAT)))
    put(name, 'prop', c + [0, TH / 2], c[1] - TH / 2, fit=TW * A * 0.98)
def stand(u, v, which=None):
    c = tb(u, v)
    pre, kind = which or rng.choice(STAND)
    put(rng.choice(group(pre)), kind, c + [0, 3], c[1] + 3)

# the portal: Ocean Drive's, at the same offset from the road's end
e = tb(*END) * A
it = {'tex': SPR_RES + 'portal_68.png', 'tl': [round(e[0] - 63.4, 1), round(e[1] - 217.3, 1)], 'key': round(e[1] + 39.3, 1),
      'kind': 'portal', 'name': 'portal', 'ring': [round(e[0] + 61.5, 1), round(e[1] - 137.9, 1)], 'ring_r': [45.4, 65.2]}
sprites.append(it)
# the entry arch over the first leg, at the same offset from the road as on Ocean Drive (whose road also runs up-right there)
an = (tb(1, -2) * A + tb(1, -3) * A) / 2
sprites.append({'tex': SPR_RES + 'arch_iso_a.png', 'tl': [round(an[0] - 108, 1), round(an[1] - 144.8, 1)], 'key': round(an[1] + 19.1, 1), 'kind': 'arch', 'name': 'arch_iso_a'})
sprites.append({'tex': SPR_RES + 'arch_iso_b.png', 'tl': [round(an[0] + 38, 1), round(an[1] - 144.8, 1)], 'key': round(an[1] + 40.2, 1), 'kind': 'arch', 'name': 'arch_iso_b'})
arch_tiles = {(0, -2), (0, -3), (2, -2), (2, -3), (0, -1), (2, -1), (0, -4), (2, -4), (1, -5), (0, -5), (2, -5)}

def on_board(u, v, m=40):
    c = tb(u, v); return -m < c[0] < W + m and -m < c[1] < H + m * 1.5
used = set(road_tiles) | arch_tiles
for u in range(-1, 4):
    for v in range(-12, 0):
        used.add((u, v))          # the entry street stays open
# outside the diamond: 2x2 blocks of buildings (with the odd little park), then single tiles of props
cands = [(u, v) for u in range(-12, N + 12) for v in range(-12, N + 12)
         if not in_diamond(u, v) and on_board(u, v, 70) and (u, v) not in used]
types = BLD[:]; rng.shuffle(types); ti = 0
cands.sort(key=lambda q: (abs(q[0] - 7) + abs(q[1] - 7), q))
for (u, v) in cands:
    blk = [(u, v), (u + 1, v), (u, v + 1), (u + 1, v + 1)]
    if any(b in used or in_diamond(*b) for b in blk):
        continue
    c = (tb(u, v) + tb(u + 1, v + 1)) / 2
    if not (-50 < c[0] < W + 50 and -40 < c[1] < H + 90):
        continue
    used.update(blk)
    if rng.random() < 0.18:   # a little park
        for b in blk:
            flat_tile(*b)
        continue
    t = types[ti % len(types)]; ti += 1
    if ti % len(types) == 0:
        rng.shuffle(types)
    put(rng.choice(group(t)), 'bld', c + [0, TH], c[1], fit=TW * 2 * A * 0.96)
for (u, v) in cands:
    if (u, v) in used or not on_board(u, v, 30):
        continue
    used.add((u, v))
    r = rng.random()
    if r < 0.45:
        flat_tile(u, v)
    elif r < 0.85:
        stand(u, v)
# lamps along the entry street
for v in (-1, -3, -5, -7):
    for u in (0, 2):
        if on_board(u, v, 10):
            stand(u, v, ('lamp', 'neon') if v % 4 == 3 else ('palm_planter_b', 'palm'))
sprites.sort(key=lambda s: s['key'])

# ---------- build mask: what's under a tower's foot (12 field units below where it stands) ----------
step, bw, bh = 4, 240, 160
rows = []
for j in range(bh):
    r = []
    for i in range(bw):
        fx, fy = (i + 0.5) * step, (j + 0.5) * step + 12
        b = fb([fx, fy]); uu, vv = ij_of_board(b[0], b[1]); q = (int(round(uu)), int(round(vv)))
        if q in road_tiles:
            r.append('1')
        elif q in portal_tiles or q in arch_tiles:
            r.append('2')
        elif playfield(*q):
            r.append('0')
        else:
            r.append('3')
    rows.append(''.join(r))

# ---------- glow: the sprites' neon and a faint road edge ----------
comp = np.zeros((H * A, W * A, 3))
for s in sprites:
    im = Image.open(os.path.join(SPR, s['tex'].rsplit('/', 1)[1])).convert('RGBA')
    sc = s.get('scale', 1.0)
    if sc != 1.0:
        im = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.BILINEAR)
    a = np.array(im).astype(float)
    x0, y0 = int(round(s['tl'][0])), int(round(s['tl'][1]))
    xs, ys = max(0, -x0), max(0, -y0); xe, ye = min(im.width, W * A - x0), min(im.height, H * A - y0)
    if xe <= xs or ye <= ys:
        continue
    sub = a[ys:ye, xs:xe]; al = sub[..., 3:4] / 255
    reg = comp[y0 + ys:y0 + ye, x0 + xs:x0 + xe]; reg[:] = reg * (1 - al) + sub[..., :3] * al
mx, mn = comp.max(2), comp.min(2)
gr = (comp[..., 1] > comp[..., 0]) & (comp[..., 1] > comp[..., 2])
neon = ((mx > 170) & (mx - mn > 80) & ~gr)[..., None] * comp
neon += band[..., None] * np.array([120, 50, 95])
g = np.array(Image.fromarray(np.clip(neon, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(float)
g *= 200 / max(1, g.max())
Image.fromarray(np.clip(g, 0, 255).astype(np.uint8)).resize((480, 260), Image.BILINEAR).save(os.path.join(OUT, 'glow.png'))

o, a_, b_ = bf(tb(0, 0)), bf(tb(1, 0)), bf(tb(0, 1))
layout = {
    'art_scale': A, 'size': [W * A, H * A], 'ground': 'ground.png', 'glow': 'glow.png', 'glints': 'glints.png', 'period': 4.0,
    'path': path_field,
    'build': {'step': step, 'w': bw, 'h': bh, 'codes': {'0': 'build', '1': 'road', '2': 'object', '3': 'edge'}, 'rows': rows},
    'snap': {'origin': o, 'a': [round(a_[0] - o[0], 4), round(a_[1] - o[1], 4)], 'b': [round(b_[0] - o[0], 4), round(b_[1] - o[1], 4)]},
    'hero': bf(tb(*HERO)),
    'sprites': sprites,
}
json.dump(layout, open(os.path.join(OUT, 'layout.json'), 'w'), separators=(',', ':'))
spots = sum(1 for u in range(N) for v in range(N) if playfield(u, v) and (u, v) not in road_tiles and (u, v) not in portal_tiles)
L = sum(math.dist(p, q) for p, q in zip(path_field, path_field[1:]))
print('sprites', len(sprites), 'tower spots', spots, 'road length', round(L), 'snap', layout['snap'])
