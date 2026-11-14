# Builds map 2 (Diamond Spiral) as a hand-painted art layout, reusing Ocean Drive's ground tiles and sprites.
import json, math, os, sys
import numpy as np
from PIL import Image, ImageFilter
REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
M1 = REPO + '/assets/maps/map1_miami/'
OUT = REPO + '/assets/maps/map2_spiral/'
os.makedirs(OUT, exist_ok=True)
W, H = 1536, 832
C30, S30 = math.cos(math.radians(30)), math.sin(math.radians(30))
L1 = json.load(open(M1 + 'layout.json'))

def to_field(X, Y): return (X / 1.6, (Y / 1.6 - 40) / 0.75)
def to_art(x, y): return (x * 1.6, (40 + 0.75 * y) * 1.6)

P = dict(CX=768, CY=float(sys.argv[1]) if len(sys.argv) > 1 else 410, R=262, G=128, FIL=46)
CX, CY, R, G = P['CX'], P['CY'], P['R'], P['G']
def scr(u, v): return (CX + (u - v) * C30, CY + (u + v) * S30)
def gnd(X, Y):  # screen -> ground uv
    a = (X - CX) / C30; b = (Y - CY) / S30
    return ((a + b) / 2, (b - a) / 2)

# ---- path in ground uv: entry straight up the top-left edge, a clockwise lap, a second lap, then up-right into the portal
x0, x1, y0, y1 = -R, R, -R, R
uv = [(-R, R + 520), (-R, -R), (R, -R), (R, R)]  # entry (off-screen down-left) -> top -> right -> bottom
x0 += G; y0 += G
uv.append((x0, R))          # bottom leg (up-left) to lap 2's left corner
x1 -= G
uv.append((x0, y0))         # up-right to lap 2's top
y1 -= G
uv.append((x1, y0))         # down-right to lap 2's right
uv.append((x1, y1))         # down-left to lap 2's bottom
END_U = float(sys.argv[3]) if len(sys.argv) > 3 else 0
uv.append((END_U, y1))      # up-left
END_V = float(sys.argv[2]) if len(sys.argv) > 2 else 0
uv.append((END_U, END_V))   # up-right into the portal steps

def fillet(pts, r, n=14):
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        a, b, c = map(np.array, pts[i - 1:i + 2])
        d1 = np.linalg.norm(a - b); d2 = np.linalg.norm(c - b)
        rr = min(r, d1 / 2.05 if i > 1 else d1, d2 / 2.05 if i < len(pts) - 2 else d2 * 0.6)
        p = b + (a - b) * rr / d1; q = b + (c - b) * rr / d2
        for k in range(n + 1):
            t = k / n
            out.append(tuple((1 - t) ** 2 * p + 2 * t * (1 - t) * b + t * t * q))
    out.append(pts[-1]); return out

def resample(pts, step):
    pts = np.array(pts, float); seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)]); ts = np.arange(0, s[-1], step)
    return np.stack([np.interp(ts, s, pts[:, 0]), np.interp(ts, s, pts[:, 1])], -1), s[-1]

guv = fillet(uv, P['FIL'])
dense, total = resample(guv, 1.0)
print('ground path length', round(total))

# ---- clean plaza: Ocean Drive's ground with its road (and pink halo) filled from the repeating tile pattern
g1 = np.array(Image.open(M1 + 'ground.png').convert('RGB')).astype(np.float32)
p1 = np.array([to_art(*p) for p in L1['path']])
ys, xs = np.mgrid[0:H, 0:W]
def dist_to_poly(px, py, poly, scale_y=1 / math.tan(math.radians(30))):
    best = np.full(px.shape, 1e9, np.float32)
    for a, b in zip(poly, poly[1:]):
        ax, ay = a[0], a[1] * scale_y; bx, by = b[0], b[1] * scale_y
        dx, dy = bx - ax, by - ay; L2 = dx * dx + dy * dy
        qx = px; qy = py * scale_y
        t = np.clip(((qx - ax) * dx + (qy - ay) * dy) / max(L2, 1e-9), 0, 1)
        best = np.minimum(best, np.hypot(qx - ax - t * dx, qy - ay - t * dy))
    return best
d1 = dist_to_poly(xs.astype(np.float32), ys.astype(np.float32), p1)
hole = d1 < 105
plaza = g1.copy()
offs = sorted([(dx * 123, dy * 71) for dx in range(-6, 7) for dy in range(-6, 7) if (dx, dy) != (0, 0)], key=lambda o: o[0] ** 2 + (o[1] * 1.7) ** 2)
todo = hole.copy()
for ox, oy in offs:
    if not todo.any(): break
    yy, xx = np.nonzero(todo)
    sx, sy = xx + ox, yy + oy
    ok = (sx >= 0) & (sx < W) & (sy >= 0) & (sy < H)
    ok[ok] &= ~hole[sy[ok], sx[ok]]
    plaza[yy[ok], xx[ok]] = g1[sy[ok], sx[ok]]
    todo[yy[ok], xx[ok]] = False
print('unfilled', todo.sum())

# ---- road: per pixel, ground distance to the path, which side, and how far along
gu, gv = gnd(xs.astype(np.float32), ys.astype(np.float32))
best = np.full((H, W), 1e9, np.float32); along = np.zeros((H, W), np.float32); side = np.zeros((H, W), np.float32)
seg_s = np.arange(len(dense)) * 1.0
for i in range(len(dense) - 1):
    a = dense[i]; b = dense[i + 1]
    sa = scr(*a)
    x_lo, x_hi = int(max(0, sa[0] - 90)), int(min(W, sa[0] + 90)); y_lo, y_hi = int(max(0, sa[1] - 60)), int(min(H, sa[1] + 60))
    if x_lo >= x_hi or y_lo >= y_hi: continue
    U = gu[y_lo:y_hi, x_lo:x_hi]; V = gv[y_lo:y_hi, x_lo:x_hi]
    dx, dy = b[0] - a[0], b[1] - a[1]; L2 = dx * dx + dy * dy
    t = np.clip(((U - a[0]) * dx + (V - a[1]) * dy) / L2, 0, 1)
    pu = U - a[0] - t * dx; pv = V - a[1] - t * dy
    d = np.hypot(pu, pv)
    blk = best[y_lo:y_hi, x_lo:x_hi]; m = d < blk
    blk[m] = d[m]
    along[y_lo:y_hi, x_lo:x_hi][m] = (seg_s[i] + t * math.sqrt(L2))[m]
    side[y_lo:y_hi, x_lo:x_hi][m] = (pu + pv)[m]  # < 0: the far (upper) side of the road
D = best; far = side < 0

img = plaza.copy()
# pink halo on the tiles beside the road
halo = np.clip((70 - D) / 30, 0, 1) * (D > 14)
pink = np.array([252, 158, 210], np.float32)
img = img * (1 - 0.78 * halo[..., None]) + pink * (0.78 * halo[..., None])
def put(mask, col, a=1.0):
    global img
    m = mask.astype(np.float32)[..., None] * a
    img = img * (1 - m) + np.array(col, np.float32) * m
rng = np.random.default_rng(7)
noise = rng.normal(0, 3.2, (H, W)).astype(np.float32)
# raised curb on the far side
put(far & (D >= 16.5) & (D < 20.5), (236, 230, 205))
put(far & (D >= 19.5) & (D < 20.5), (175, 112, 124))
# asphalt
asp = D < 16.5
base = np.stack([68 + noise, 48 + noise * 0.8, 105 + noise], -1)
img[asp] = base[asp]
put((D >= 14.2) & (D < 16.5), (28, 17, 62))          # dark edge
put((D >= 15.8) & (D < 17.5) & ~far, (40, 22, 70))
edge_dash = (np.mod(along, 24) < 15)
put((D >= 11.2) & (D < 12.9) & edge_dash, (232, 226, 240))     # white edge lines
yellow = (D < 1.25) & (np.mod(along, 20) < 9)
put(yellow, (248, 196, 52))
img = np.clip(img, 0, 255).astype(np.uint8)

# ---- glints: white edge lines, red = strength, green/blue = distance along (16 bit)
gl = np.zeros((H, W, 3), np.uint8)
lm = (D >= 10.5) & (D < 13.6)
sN = np.clip(along / total, 0, 1); q = (sN * 65535).astype(np.int64)
gl[..., 0][lm] = np.where(edge_dash[lm], 255, 110)
gl[..., 1][lm] = (q[lm] >> 8).astype(np.uint8); gl[..., 2][lm] = (q[lm] & 255).astype(np.uint8)

# ---- portal: the road ends on the bottom step's front edge (same offsets as Ocean Drive)
por = [s for s in L1['sprites'] if s['kind'] == 'portal'][0]
end_scr = scr(*guv[-1])
end1 = to_art(*L1['path'][-1])
dx_, dy_ = end_scr[0] - end1[0], end_scr[1] - end1[1]
PS = 0.8
os.makedirs(OUT + 'spr', exist_ok=True)
pim = Image.open(M1 + 'spr/' + por['tex'])
pim = pim.resize((round(pim.width * PS), round(pim.height * PS)), Image.LANCZOS); pim.save(OUT + 'spr/portal.png')
rel_end = (end1[0] - por['tl'][0], end1[1] - por['tl'][1])
tl = (end_scr[0] - rel_end[0] * PS, end_scr[1] - rel_end[1] * PS)
portal = dict(por); portal['tex'] = 'res://assets/maps/map2_spiral/spr/portal.png'
portal['tl'] = [round(tl[0]), round(tl[1])]
portal['key'] = round(tl[1] + (por['key'] - por['tl'][1]) * PS, 1)
portal['ring'] = [round(tl[0] + (por['ring'][0] - por['tl'][0]) * PS, 1), round(tl[1] + (por['ring'][1] - por['tl'][1]) * PS, 1)]
portal['ring_r'] = [round(r * PS, 1) for r in por['ring_r']]

# ---- sprites: keep Ocean Drive's edge buildings and props that stay clear of the new road
Dsm = D
keep = []
for s in L1['sprites']:
    if s['kind'] in ('portal', 'arch', 'tlight'): continue
    im = Image.open(M1 + 'spr/' + s['tex']); w, h = im.size
    al = np.array(im)[..., 3] > 40
    key = s['key']; tl = s['tl']
    # ground footprint: opaque pixels in the band just above the sort line
    clash = False
    for yy in range(int(key) - int(w * 0.32), int(key) + 10):
        r = yy - tl[1]
        if r < 0 or r >= h or yy < 0 or yy >= H: continue
        cols = np.nonzero(al[r])[0]
        if len(cols) == 0: continue
        xx = np.clip(cols + tl[0], 0, W - 1)
        if (Dsm[yy, xx] < 34).any(): clash = True; break
    if not clash: keep.append(s)
print('sprites kept', len(keep), 'of', len(L1['sprites']))
sprites = keep + [portal]

def spr_path(s): return s['tex'].replace('res://', REPO + '/') if s['tex'].startswith('res://') else M1 + 'spr/' + s['tex']
# ---- glow: soft neon from the bright saturated pixels of the sprites, at quarter-ish res like Ocean Drive's
comp = Image.new('RGB', (W, H))
for s in sorted(sprites, key=lambda s: s['key']):
    im = Image.open(spr_path(s)).convert('RGBA')
    a = np.array(im).astype(np.float32); rgb = a[..., :3]; al = a[..., 3:] / 255
    mx = rgb.max(-1); mn = rgb.min(-1); sat = (mx - mn) / np.maximum(mx, 1)
    neon = ((mx > 200) & (sat > 0.45)).astype(np.float32)[..., None] * al
    layer = Image.fromarray(np.clip(rgb * neon, 0, 255).astype(np.uint8))
    comp.paste(layer, (int(s['tl'][0]), int(s['tl'][1])), Image.fromarray((neon[..., 0] * 255).astype(np.uint8)))
glow = comp.filter(ImageFilter.GaussianBlur(14)).resize((480, 260), Image.BILINEAR)
gref = np.array(Image.open(M1 + 'glow.png')).astype(np.float32)
ga = np.array(glow).astype(np.float32)
ga *= (gref.mean() / max(ga.mean(), 1e-3)) if ga.mean() > 0 else 1
glow = Image.fromarray(np.clip(ga, 0, 255).astype(np.uint8))

# ---- build mask (240x150 cells of 4 field units, looked up at the tower's foot)
B = L1['build']; M1mask = np.array([[int(c) for c in r] for r in B['rows']])
cy_, cx_ = np.mgrid[0:150, 0:240]
fx = cx_ * 4 + 2; fy = cy_ * 4 + 2
ax_, ay_ = to_art(fx, fy)
mu, mv = gnd(ax_, ay_ + 14.4)
def gdist(mu, mv):
    bestm = np.full(mu.shape, 1e9)
    for a, b in zip(dense[::3], dense[3::3]):
        dx, dy = b[0] - a[0], b[1] - a[1]; L2 = dx * dx + dy * dy
        t = np.clip(((mu - a[0]) * dx + (mv - a[1]) * dy) / L2, 0, 1)
        bestm = np.minimum(bestm, np.hypot(mu - a[0] - t * dx, mv - a[1] - t * dy))
    return bestm
Dm = gdist(mu, mv)
mask = np.where(M1mask == 3, 3, 0)
# kept sprites only: Ocean Drive's objects (portal, arch, lights) were code 2 there and are gone now
mask[Dm < 33] = 1
pu_, pv_ = gnd(*portal['ring'])
pr_u, pr_v = gnd(ax_, ay_)
# portal: its footprint around the platform centre
pc = (portal['tl'][0] + 124 * PS, portal['key'] - 40 * PS)
pcu, pcv = gnd(*pc)
dpor = np.hypot(pr_u - pcu, pr_v - pcv)
mask[(dpor < 92 * PS) & (mask != 1)] = 2
# screen border (art px): 70 at the sides, 150 at the top, 40 at the bottom
bx = (ax_ < 70) | (ax_ > W - 70) | (ay_ < 150) | (ay_ > H - 40)
mask[bx & (mask == 0)] = 3
# drop small pockets
lab = np.zeros(mask.shape, int); n = 0
for y in range(150):
    for x in range(240):
        if mask[y, x] == 0 and lab[y, x] == 0:
            n += 1; st = [(y, x)]; lab[y, x] = n; cells = []
            while st:
                cy0, cx0 = st.pop(); cells.append((cy0, cx0))
                for dy2, dx2 in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    yy2, xx2 = cy0 + dy2, cx0 + dx2
                    if 0 <= yy2 < 150 and 0 <= xx2 < 240 and mask[yy2, xx2] == 0 and lab[yy2, xx2] == 0:
                        lab[yy2, xx2] = n; st.append((yy2, xx2))
            if len(cells) < 60:
                for c in cells: mask[c] = 3
print('mask counts', np.bincount(mask.ravel(), minlength=4))

# ---- hero start: open ground just right of the portal
tgt = (pc[0] + 120, pc[1] - 10)
cand = [(math.dist(to_art(x * 4 + 2, y * 4 + 2 - 12), tgt), x, y) for y in range(150) for x in range(240) if mask[y, x] == 0]
_, hx_, hy_ = min(cand)
hero = [hx_ * 4 + 2, hy_ * 4 + 2 - 12]
print('hero', hero)
path_field = [[round(a, 2), round(b, 2)] for a, b in (to_field(*scr(u, v)) for u, v in guv[::2] + [guv[-1]])]
layout = dict(art_scale=2, size=[W, H], ground='ground.png', glow='glow.png', glints='glints.png', spr='res://assets/maps/map1_miami/spr/',
              path=path_field, build=dict(step=4, w=240, h=150, rows=[''.join(str(int(c)) for c in r) for r in mask]),
              sprites=sprites, period=L1.get('period', 4.0), hero=hero, hero_spawn=hero)
Image.fromarray(img).save(OUT + 'ground.png')
Image.fromarray(gl).save(OUT + 'glints.png')
glow.save(OUT + 'glow.png')
json.dump(layout, open(OUT + 'layout.json', 'w'), separators=(',', ':'))
fl = sum(math.dist(a, b) for a, b in zip(path_field, path_field[1:]))
f1 = sum(math.dist(a, b) for a, b in zip(L1['path'], L1['path'][1:]))
print('field path', round(fl), 'vs Ocean Drive', round(f1))

# ---- preview: ground + sprites + mask overlay
pv = Image.fromarray(img).convert('RGBA')
for s in sorted(sprites, key=lambda s: s['key']):
    im = Image.open(spr_path(s)).convert('RGBA'); pv.alpha_composite(im, (0, 0)) if False else pv.paste(im, (int(s['tl'][0]), int(s['tl'][1])), im)
pv.convert('RGB').save('/tmp/map2_preview.png')
from PIL import ImageDraw; ov = Image.new('RGBA', pv.size, (0,0,0,0)); dr = ImageDraw.Draw(ov)
cols = {0: (0, 255, 0, 60), 1: (255, 0, 0, 80), 2: (0, 0, 255, 110), 3: (0, 0, 0, 90)}
for y in range(150):
    for x in range(240):
        X, Y = to_art(x * 4, y * 4); dr.rectangle([X, Y, X + 6.4, Y + 4.8], fill=cols[int(mask[y, x])])
dr.line([to_art(*p) for p in path_field], fill=(255, 255, 0, 255), width=2)
Image.alpha_composite(pv, ov).convert('RGB').save('/tmp/map2_preview_mask.png')
