"""Builds the Canal Crossing backdrop, six 768x416 frames (the water, palms, umbrellas, lamps, signs, fans, boats,
the entry gate and the rift move between them), and its logic grid from the Neon City sheets."""
import json, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.abspath(__file__))
os.chdir(ROOT)
COLS, ROWS = 24, 15
CW, CH, TD = 64, 48, 64          # 2x art: a cell is 64x48 on screen, 64x64 before the 3/4 squash
OY = 64                           # 2x art: the grid starts below the back wall
W2, H2 = 1536, 832
PRE = 2                           # rows drawn above the grid (top-down canvas starts at row -2)
TDH = (ROWS + PRE + 1) * TD       # top-down canvas height (rows -2..15)

rng = random.Random(7)

# ---------- logic ----------
path = [(3, r) for r in range(0, 11)] + [(c, 10) for c in range(4, 19)] + [(18, r) for r in range(9, 2, -1)] + [(c, 3) for c in range(17, 9, -1)]
pset = set(path)
water = set()
for r in range(ROWS):
    for c in (13, 14):
        if (c, r) not in pset:
            water.add((c, r))
for r in range(12, ROWS):
    for c in range(15, COLS):
        water.add((c, r))
blocked = set()


def td(c, r):
    """top-left of a cell on the top-down canvas"""
    return c * TD, (r + PRE) * TD


# ---------- ground (top-down) ----------
def plaza():
    a = np.zeros((TDH, W2, 3), np.float32)
    base = np.array([238, 186, 196], np.float32)
    a[:] = base
    sq = 32
    jit = np.random.RandomState(3).uniform(-7, 7, (TDH // sq + 1, W2 // sq + 1))
    yy, xx = np.mgrid[0:TDH, 0:W2]
    a += jit[yy // sq, xx // sq][..., None] * np.array([1, 0.8, 0.8])
    noise = np.random.RandomState(4).normal(0, 4, (TDH, W2))[..., None]
    a += noise
    grout = ((yy % 64) < 2) | ((xx % 64) < 2)
    a[grout] = a[grout] * 0.45 + np.array([186, 148, 188]) * 0.55
    fine = (((yy % 64) == 32) | ((xx % 64) == 32)) & ~grout
    a[fine] = a[fine] * 0.75 + np.array([206, 166, 196]) * 0.25
    light = ((yy % 64) == 2) | ((xx % 64) == 2)
    a[light] += 6
    # specks and stains
    rs = np.random.RandomState(5)
    for _ in range(900):
        x, y = rs.randint(0, W2 - 3), rs.randint(0, TDH - 3)
        a[y:y + 2, x:x + 2] -= rs.uniform(10, 25)
    return a


g = plaza()
img = Image.fromarray(np.clip(g, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(img)




def is_water(c, r):
    if r < 0:
        r = 0
    if r >= ROWS:
        r = ROWS - 1
    return (c, r) in water or ((c, r) in pset and c in (13, 14))


# water (including under the bridges and the rows past the grid edges): painted in a key colour here and filled
# with the animated water frames at the end
KEY = (255, 0, 255)
CHANNEL = (13, 14)


def channel_side(c, n):
    """the canal's long walls come with the animated wall tiles, so no stone lip or railing is drawn there"""
    return c in CHANNEL and n[0] not in CHANNEL and n[0] in (12, 15)

for r in range(-PRE, ROWS + 1):
    for c in range(COLS):
        if is_water(c, r):
            x, y = td(c, r)
            d.rectangle((x, y, x + TD - 1, y + TD - 1), fill=KEY)

# canal walls: a stone lip on every water edge that meets land
STONE = (214, 186, 206)
STONE_D = (120, 96, 140)
SHADE = (10, 62, 92)
for r in range(-PRE, ROWS + 1):
    for c in range(COLS):
        if not is_water(c, r):
            continue
        x, y = td(c, r)
        for dc, dr in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            n = (c + dc, r + dr)
            if n[0] < 0 or n[0] >= COLS or is_water(*n) or channel_side(c, n):
                continue
            if dr == -1:
                d.rectangle((x, y, x + TD - 1, y + 5), fill=STONE); d.rectangle((x, y + 6, x + TD - 1, y + 10), fill=SHADE)
            if dr == 1:
                d.rectangle((x, y + TD - 6, x + TD - 1, y + TD - 1), fill=STONE); d.rectangle((x, y + TD - 7, x + TD - 1, y + TD - 7), fill=STONE_D)
            if dc == -1:
                d.rectangle((x, y, x + 5, y + TD - 1), fill=STONE); d.rectangle((x + 6, y, x + 9, y + TD - 1), fill=SHADE)
            if dc == 1:
                d.rectangle((x + TD - 6, y, x + TD - 1, y + TD - 1), fill=STONE); d.rectangle((x + TD - 10, y, x + TD - 7, y + TD - 1), fill=SHADE)

# wooden pier in the harbour
for c in range(19, 22):
    for r in (12, 13):
        x, y = td(c, r)
        for i in range(0, TD, 8):
            d.rectangle((x, y + i, x + TD - 1, y + i + 6), fill=(150, 102, 92))
            d.line((x, y + i + 7, x + TD - 1, y + i + 7), fill=(92, 58, 66))
for c in (19, 21):
    x, y = td(c, 14)
    d.rectangle((x + 4, y, x + 14, y + 40), fill=(92, 58, 66))
    x2 = x + TD - 14
    d.rectangle((x2, y, x2 + 10, y + 40), fill=(92, 58, 66))

# parking lots
def lot(c0, r0, c1, r1, slots_v=True):
    x0, y0 = td(c0, r0)
    x1, y1 = td(c1 + 1, r1 + 1)
    d.rectangle((x0 + 4, y0 + 4, x1 - 5, y1 - 5), fill=(46, 48, 88))
    d.rectangle((x0 + 4, y0 + 4, x1 - 5, y1 - 5), outline=(214, 186, 206), width=3)
    for c in range(c0, c1 + 2):
        x = c * TD
        if c0 < c <= c1:
            d.line((x, y0 + 8, x, y1 - 30), fill=(240, 230, 240), width=3)
    for c in range(c0, c1 + 1):
        blocked.update((c, r) for r in range(r0, r1 + 1))


lot(20, 0, 23, 1)
lot(4, 12, 6, 14)

# ---------- the road ----------
road_layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
rd = ImageDraw.Draw(road_layer)


def ctr(c, r):
    x, y = td(c, r)
    return x + TD // 2, y + TD // 2


pts = [ctr(3, -PRE - 1)] + [ctr(*p) for p in path]
# corner points only (straight runs merged)
cp = [pts[0]]
for i in range(1, len(pts) - 1):
    a, b, e = pts[i - 1], pts[i], pts[i + 1]
    if (b[0] - a[0], b[1] - a[1]) != (e[0] - b[0], e[1] - b[1]):
        cp.append(b)
cp.append(pts[-1])
rd.line(cp, fill=(222, 196, 214, 255), width=62, joint='curve')
rd.line(cp, fill=(120, 96, 140, 255), width=56, joint='curve')
rd.line(cp, fill=(38, 44, 86, 255), width=52, joint='curve')
for p in (cp[-1],):
    rd.ellipse((p[0] - 31, p[1] - 31, p[0] + 31, p[1] + 31), fill=(222, 196, 214, 255))
    rd.ellipse((p[0] - 26, p[1] - 26, p[0] + 26, p[1] + 26), fill=(38, 44, 86, 255))
ra = np.asarray(road_layer).astype(np.float32)
asph = ra[..., :3] == np.array([38, 44, 86])
asph = asph.all(-1)
noise = np.random.RandomState(9).normal(0, 5, ra.shape[:2])
ra[..., :3][asph] += noise[asph][:, None]
rs = np.random.RandomState(10)
ys, xs = np.nonzero(asph)
for i in rs.choice(len(ys), 2500):
    ra[ys[i], xs[i], :3] += 22
road_layer = Image.fromarray(np.clip(ra, 0, 255).astype(np.uint8), 'RGBA')

# bridge railings over the canal (road is horizontal there)
br = ImageDraw.Draw(road_layer)
for row in (3, 10):
    xa, _ = td(13, row)
    xb, yb = td(15, row)
    for yr in (yb + 1, yb + TD - 5):
        br.rectangle((xa - 6, yr, xb + 5, yr + 3), fill=(226, 214, 236, 255))
        for x in range(xa - 6, xb + 6, 14):
            br.rectangle((x, yr - 1, x + 3, yr + 4), fill=(120, 96, 140, 255))
img.paste(road_layer, (0, 0), road_layer)

# lane markings: cyan dashes, and arrows pointing the way enemies walk
CY = (98, 226, 242)
CYD = (40, 120, 150)
dirs = {}
for i, p in enumerate(path):
    nxt = path[i + 1] if i + 1 < len(path) else None
    prv = path[i - 1] if i > 0 else (3, -1)
    dv = (nxt[0] - p[0], nxt[1] - p[1]) if nxt else (p[0] - prv[0], p[1] - prv[1])
    dirs[p] = dv
corner = set()
for i in range(1, len(path) - 1):
    a, b, e = path[i - 1], path[i], path[i + 1]
    if (b[0] - a[0], b[1] - a[1]) != (e[0] - b[0], e[1] - b[1]):
        corner.add(b)
arrow_at = set()
run = 0
for i, p in enumerate(path):
    near_corner = any(path[j] in corner for j in range(max(0, i - 1), min(len(path), i + 2)))
    run += 1
    if 1 <= i < len(path) - 2 and not near_corner and run >= 3 and p[0] not in (13, 14):
        arrow_at.add(p)
        run = 0
for i, p in enumerate(path):
    if p in corner:
        continue
    cx, cy = ctr(*p)
    dx, dy = dirs[p]
    if p in arrow_at:
        tip = (cx + dx * 18, cy + dy * 18)
        tail = (cx - dx * 16, cy - dy * 16)
        px, py = -dy, dx
        base = (cx + dx * 4, cy + dy * 4)
        head = [tip, (base[0] + px * 10, base[1] + py * 10), (base[0] - px * 10, base[1] - py * 10)]
        d.line((tail, base), fill=CYD, width=8)
        d.polygon([(h[0] + dx * 2, h[1] + dy * 2) for h in head], fill=CYD)
        d.line((tail, base), fill=CY, width=4)
        d.polygon(head, fill=CY)
        continue
    if i == len(path) - 1:
        continue
    for k in (-24, 4):
        a = (cx + dx * k, cy + dy * k)
        b = (cx + dx * (k + 18), cy + dy * (k + 18))
        d.line((a, b), fill=CY, width=3)
for r in range(-PRE, 0):  # dashes on the road coming in from off the map
    cx, cy = ctr(3, r)
    d.line(((cx, cy - 24), (cx, cy - 6)), fill=CY, width=3)
    d.line(((cx, cy + 4), (cx, cy + 22)), fill=CY, width=3)

# railings along the canal and harbour on the land side
for r in range(ROWS):
    for c in range(COLS):
        if is_water(c, r) or (c, r) in pset:
            continue
        x, y = td(c, r)
        for dc, dr in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            n = (c + dc, r + dr)
            if not (0 <= n[0] < COLS) or not is_water(*n) or n in pset or channel_side(n[0], (c, r)):
                continue
            if dr == 1:
                ry = y + TD - 8
                d.rectangle((x, ry, x + TD - 1, ry + 3), fill=(226, 214, 236))
                for px_ in range(x + 2, x + TD, 16):
                    d.rectangle((px_, ry - 3, px_ + 4, ry + 5), fill=(120, 96, 140))
            if dc == 1:
                rx = x + TD - 8
                d.rectangle((rx, y, rx + 3, y + TD - 1), fill=(226, 214, 236))
                for py_ in range(y + 2, y + TD, 16):
                    d.rectangle((rx - 2, py_, rx + 5, py_ + 4), fill=(120, 96, 140))
            if dc == -1:
                rx = x + 4
                d.rectangle((rx, y, rx + 3, y + TD - 1), fill=(226, 214, 236))
                for py_ in range(y + 2, y + TD, 16):
                    d.rectangle((rx - 2, py_, rx + 5, py_ + 4), fill=(120, 96, 140))

def spr(name):
    p = 'spr/%s.png' % name
    return Image.open(p if os.path.exists(p) else name + '.png').convert('RGBA')


NF = 6


def frames(name):
    """an animated sprite: 'anim:palm_box' is the six frames in spr/anim_palm_box.png"""
    s = spr('anim_' + name)
    w = s.width // NF
    return [s.crop((i * w, 0, (i + 1) * w, s.height)) for i in range(NF)]


props = []  # (sort key, frames, phase, x, y, shadow, cx, by, fw)


def place(name, c0, r0, c1, r1, width=None, flip=False, rot=0, block=True, dy=0, shadow=True, height=None, phase=0, dx=0):
    fs = frames(name[5:]) if name.startswith('anim:') else [spr(name)]
    if rot:
        fs = [f.rotate(rot, expand=True) for f in fs]
    if flip:
        fs = [f.transpose(Image.FLIP_LEFT_RIGHT) for f in fs]
    fw = (c1 - c0 + 1) * CW
    sc = height / fs[0].height if height else (width or fw * 0.9) / fs[0].width
    fs = [f.resize((max(1, round(f.width * sc)), max(1, round(f.height * sc))), Image.LANCZOS) for f in fs]
    cx = c0 * CW + fw / 2 + dx
    by = OY + (r1 + 1) * CH - 4 + dy
    props.append(((r1, c0), fs, phase, round(cx - fs[0].width / 2), round(by - fs[0].height), shadow, cx, by, fw))
    if block:
        for c in range(c0, c1 + 1):
            for r in range(max(0, r0), min(ROWS - 1, r1) + 1):
                blocked.add((c, r))


# rift portal at the base and the entry gate where the road comes in
place('anim:rift_ring', 10, 3, 10, 3, width=62, block=False, dy=4, shadow=False)
place('anim:entry', 3, -1, 3, -1, width=52, rot=180, block=False, shadow=False)
place('anim:arrow', 3, 0, 3, 0, height=40, block=False, shadow=False, dy=-6, phase=2)

# left edge
place('b4', 0, 0, 1, 3, width=128)        # apartment block
place('anim:palm_box', 0, 4, 1, 4, width=112, phase=0)
place('b3', 0, 5, 1, 8, width=128)        # clinic
place('vendD', 0, 9, 0, 9, height=70)
place('vendS', 1, 9, 1, 9, height=70)
place('anim:palm_box', 0, 10, 1, 11, width=112, phase=4)
place('anim:diner_front', 0, 12, 1, 13, width=132, phase=2)    # diner
place('anim:umbrella', 2, 13, 2, 13, height=64, phase=3)
place('tree', 2, 14, 2, 14, height=58)
# top edge
place('anim:palm_pot', 4, 0, 4, 0, height=80, phase=1)
place('anim:arcade_front', 5, 0, 7, 1, width=176)    # arcade, its sign and windows flicker
place('anim:fan', 8, 1, 8, 1, width=56, phase=1)
place('b1', 9, 0, 11, 1, width=172)       # convenience store
place('lampB', 12, 1, 12, 1, height=78)
place('anim:lamp', 12, 2, 12, 2, height=74, phase=4)
place('anim:lamp', 15, 2, 15, 2, height=74, phase=2)
place('b5', 16, 0, 18, 1, width=150)      # police
place('tree', 19, 0, 19, 0, height=60)
place('policeE', 20, 0, 21, 0, width=104, block=False)
place('coupeN', 22, 0, 22, 1, height=92, block=False)
place('taxiN', 23, 0, 23, 1, height=92, block=False)
place('anim:flowerbed', 20, 2, 20, 2, width=60, phase=5)
place('hydrant', 21, 2, 21, 2, height=44)
# right edge
place('b6', 20, 3, 22, 6, width=184)      # office
place('anim:palm_pot', 23, 4, 23, 4, height=80, phase=0)
place('anim:lamp', 23, 6, 23, 6, height=74, phase=3)
place('ramen', 20, 8, 22, 9, width=184)
place('anim:ramen_sign', 20, 9, 22, 9, width=124, block=False, shadow=False, dy=-74, phase=3)
place('anim:umbrella', 23, 8, 23, 8, height=64, phase=1)
place('cafe', 20, 11, 21, 11, width=96)
place('anim:umbrella', 22, 11, 22, 11, height=64, phase=4)
place('anim:flowerbed', 23, 11, 23, 11, width=60, phase=2)
place('anim:lamp', 15, 11, 15, 11, height=74, phase=5)
place('anim:lamp', 12, 11, 12, 11, height=74, phase=0)
# bottom edge
place('coupeN', 4, 12, 4, 13, height=92, block=False)
place('sportN', 5, 12, 5, 13, height=92, block=False)
place('vanN', 6, 13, 6, 14, height=96, block=False)
place('b7', 7, 12, 9, 14, width=184, dy=150)   # parking garage roof, running off the bottom
place('foodcart', 10, 12, 10, 12, width=70)
place('b1', 10, 13, 12, 14, width=172, dy=170, flip=True)
place('anim:palm_box', 11, 12, 12, 12, width=104, phase=3)
# inside the loop
place('fountain', 7, 6, 8, 7, width=124)
place('bench', 5, 8, 5, 8, width=60)
place('anim:palm_box', 10, 8, 11, 8, width=104, phase=1)
place('anim:lamp', 12, 5, 12, 5, height=74, phase=4)
place('neonpalm', 16, 6, 16, 6, height=104)
place('bench', 9, 2, 9, 2, width=60)
place('anim:flowerbed', 6, 2, 6, 2, width=60, phase=2)
place('trash', 4, 2, 4, 2, height=40)
place('succulent', 12, 7, 12, 7, height=40)
place('hydrant', 15, 7, 15, 7, height=44)
place('bikerack', 16, 9, 16, 9, width=56)
place('anim:flowerbed', 19, 1, 19, 1, width=60, phase=5)
place('anim:fan', 19, 11, 19, 11, width=52, phase=4)
place('bollard', 2, 0, 2, 0, height=36)
place('hedge', 4, 11, 4, 11, width=60)
place('lampB', 8, 11, 8, 11, height=78)
place('succulent', 2, 6, 2, 6, height=40)
place('atm', 23, 3, 23, 3, height=60)
# boats on the water
place('anim:boat', 13, 6, 14, 7, height=96, block=False, shadow=False, phase=1)
place('anim:speedboat', 16, 13, 17, 13, width=104, block=False, shadow=False, dy=10, phase=4)
place('anim:boat', 22, 12, 22, 13, height=88, block=False, shadow=False, flip=True, phase=0)

props.sort(key=lambda p: (p[0][0], p[0][1]))
sh = Image.new('RGBA', (W2, H2), (0, 0, 0, 0))
shd = ImageDraw.Draw(sh)
for key, fs, ph, x, y, shadow, cx, by, fw in props:
    if shadow:
        rx = min(fw, fs[0].width) * 0.45
        shd.ellipse((cx - rx, by - 9, cx + rx, by + 5), fill=(16, 18, 35, 90))
sh = sh.filter(ImageFilter.GaussianBlur(2))

for p in pset:
    blocked.discard(p)
for w_ in water:
    blocked.discard(w_)


def water_tiles(name, size):
    s = spr('anim_water_' + name).convert('RGB')
    w = s.width // NF
    return [s.crop((i * w, 0, (i + 1) * w, s.height)).resize((size, size), Image.LANCZOS) for i in range(NF)]


open_w = water_tiles('open', 128)
wall_l, wall_r = water_tiles('wall_l', TD), water_tiles('wall_r', TD)
key = (np.asarray(img)[..., :3] == np.array(KEY)).all(-1)
os.makedirs('out', exist_ok=True)
for k in range(NF):
    wat = Image.new('RGB', img.size)
    for y in range(0, TDH, 128):
        for x in range(0, W2, 128):
            wat.paste(open_w[k], (x, y))
    for r in range(-PRE, ROWS + 1):  # the canal itself: its walls are part of the animated tiles
        wat.paste(wall_l[k], td(13, r))
        wat.paste(wall_r[k], td(14, r))
    top = Image.fromarray(np.where(key[..., None], np.asarray(wat), np.asarray(img)[..., :3]).astype(np.uint8))
    ground = top.resize((W2, int(TDH * 0.75)), Image.LANCZOS)
    canvas = Image.new('RGBA', (W2, H2), (16, 18, 35, 255))
    canvas.paste(ground, (0, OY - PRE * CH))
    canvas.alpha_composite(sh)
    for key_, fs, ph, x, y, shadow, cx, by, fw in props:
        f = fs[(k + ph) % len(fs)]
        fx = x + round((fs[0].width - f.width) / 2)
        if y < 0:
            canvas.alpha_composite(f.crop((0, -y, f.width, f.height)), (max(0, fx), 0))
        else:
            canvas.alpha_composite(f, (max(0, fx), y))
    canvas.resize((768, 416), Image.LANCZOS).save('out/canal_%d.png' % k)
    if k == 0:
        canvas.save('out/canal_2x.png')
json.dump({'path': path, 'water': sorted(water), 'blocked': sorted(blocked)}, open('canal_layout.json', 'w'))
print('blocked', len(blocked), 'water', len(water), 'path', len(path))
