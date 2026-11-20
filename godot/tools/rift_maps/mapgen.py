# The Rift Creep map generator: Rift Plaza's recipe (Coral Spiral's road and tiles on a 15 x 15 diamond tower grid, at
# the game's one isometric angle) made general, so each map deeper into the rift is a config in maps.py:
#   lanes     one road, or several entries whose roads join (written as layout "paths", all the same length)
#   water     tiles of canal (no building); road tiles over water become bridges
#   islands   the land tiles of a floating-islands map; everything else is the void, and road over it is a light bridge
#   rift      0..1, how far the rift has eaten the city: the ground drains toward violet and cracks open, the borrowed
#             Ocean Drive sprites get the corruption pass (corrupt.py), and void props (voidprops.py) take over
#   scars     tiles on the square where void crystals broke through: no building there
# python3 build.py <map> [...] writes the map's ground.png, glints.png, glow.png, layout.json and spr/ folder.
import json, math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import corrupt, voidprops

W, H = 768, 416          # board px
A = 2                    # art px per board px
TW = 48.0                # a tile (one tower spot) is a diamond TW x TH board px
TH = TW / math.sqrt(3)
N = 15
ISO_Y = TH / TW          # the ground's squash on screen (0.577)
X0, Y0 = (W - N * TW) / 2, H / 2
HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.normpath(os.path.join(HERE, '..', '..', 'assets', 'maps'))
OD_SPR = os.path.join(MAPS, 'map1_miami', 'spr')
OD_RES = 'res://assets/maps/map1_miami/spr/'
PROPS_DIR = os.path.join(MAPS, 'rift_props')
PROPS_RES = 'res://assets/maps/rift_props/'


def tb(u, v):  # tile centre, board px
    return np.array([X0 + (u + v + 1) * TW / 2, Y0 + (u - v) * TH / 2])


def bf(p):     # board px -> field
    return [round(float(p[0]) / 0.8, 3), round((float(p[1]) / 0.8 - 40) / 0.75, 3)]


def fb(f):
    return np.array([f[0] * 0.8, (40 + 0.75 * f[1]) * 0.8])


def ij_of_board(x, y):  # unrounded tile coords of a board point
    dx, dy = x - X0 - TW / 2, y - Y0
    s, d = dx / (TW / 2), dy / (TH / 2)
    return (s + d) / 2, (s - d) / 2


def lerp(a, b, t):
    return tuple(np.array(a) * (1 - t) + np.array(b) * t)


def tiles_of(legs):
    out = []
    for (u0, v0), (u1, v1) in zip(legs, legs[1:]):
        du, dv = np.sign(u1 - u0), np.sign(v1 - v0)
        u, v = u0, v0
        while (u, v) != (u1, v1):
            out.append((u, v)); u += du; v += dv
    out.append(tuple(legs[-1]))
    return out


def steps(legs):
    return sum(abs(b[0] - a[0]) + abs(b[1] - a[1]) for a, b in zip(legs, legs[1:]))


def in_sq(u, v):
    return 0 <= u <= N - 1 and 0 <= v <= N - 1


def ascii_map(cfg):
    """A quick look at a layout, in screen orientation (x = u + v, y = u - v)."""
    lanes = cfg['lanes']
    road = {}
    for k, legs in enumerate(lanes):
        for t in tiles_of(legs):
            road[t] = '#' if t in road and road[t] != str(k) else str(k)
    water = set(cfg.get('water', ()))
    land = cfg.get('islands')
    end = tuple(lanes[0][-1])
    rows = []
    for y in range(-16, 17):
        r = ''
        for x in range(-6, 36):
            if (x + y) % 2:
                r += ' '; continue
            u, v = (x + y) // 2, (x - y) // 2
            t = (u, v)
            if t == end:
                r += 'P'
            elif t in road:
                r += road[t]
            elif t in water:
                r += '~'
            elif land is not None and in_sq(u, v):
                r += '.' if t in land else ' '
            elif in_sq(u, v):
                r += 'x' if t in cfg.get('scars', ()) else '.'
            else:
                r += ' '
        rows.append(r.rstrip())
    return '\n'.join(r for r in rows if r.strip())


def build(cfg, out):
    rng = random.Random(cfg.get('seed', 1))
    c = float(cfg.get('rift', 0.0))
    lanes = [[tuple(p) for p in legs] for legs in cfg['lanes']]
    n0 = steps(lanes[0])
    for k, legs in enumerate(lanes):
        assert steps(legs) == n0, 'lane %d is %d tiles long, lane 0 is %d' % (k, steps(legs), n0)
    road_tiles = set()
    for legs in lanes:
        road_tiles.update(tiles_of(legs))
    END = lanes[0][-1]
    eu, ev = END
    assert lanes[0][-2][0] == eu and lanes[0][-2][1] < ev, 'the last leg must run +v into the portal, like Rift Plaza'
    portal_tiles = {(eu - 1, ev), (eu + 1, ev), (eu - 1, ev + 1), (eu, ev + 1), (eu + 1, ev + 1), (eu - 1, ev + 2), (eu, ev + 2), (eu + 1, ev + 2)}
    water = set(map(tuple, cfg.get('water', ())))
    land = set(map(tuple, cfg['islands'])) if cfg.get('islands') is not None else None
    scars = set(map(tuple, cfg.get('scars', ())))
    void_map = land is not None

    def buildable(t):
        if not in_sq(*t) or t in road_tiles or t in portal_tiles or t in water or t in scars:
            return False
        return land is None or t in land

    PB = [[tb(u, v) for u, v in legs] for legs in lanes]
    path_fields = [[bf(p) for p in pb] for pb in PB]

    # ---------- distance field to the road (any lane) ----------
    def road_field(scale):
        h, w = H * scale, W * scale
        yy, xx = np.mgrid[0:h, 0:w].astype(float)
        xx = (xx + 0.5) / scale; yy = (yy + 0.5) / scale
        best = np.full((h, w), 1e9); S = np.zeros((h, w)); Nn = np.zeros((h, w)); LN = np.zeros((h, w), int)
        cums = []
        for k, pb in enumerate(PB):
            cum = np.concatenate([[0], np.cumsum([np.linalg.norm(b - a) for a, b in zip(pb, pb[1:])])])
            cums.append(cum)
            for i, (a, b) in enumerate(zip(pb, pb[1:])):
                d = b - a; l = np.linalg.norm(d); uu = d / l
                t = np.clip((xx - a[0]) * uu[0] + (yy - a[1]) * uu[1], 0, l)
                dist = np.hypot(xx - a[0] - uu[0] * t, yy - a[1] - uu[1] * t)
                m = dist < best - 1e-6
                best[m] = dist[m]; S[m] = (cum[i] + t)[m]; LN[m] = k
                Nn[m] = ((xx - a[0]) * -uu[1] + (yy - a[1]) * uu[0])[m]
        return xx, yy, best, S, Nn, LN, cums

    CORE, MAG, PINK = 7.0, 8.6, 10.4
    xx, yy, best, S, Nn, LN, cums = road_field(1)
    U, V = ij_of_board(xx, yy)
    iu, iv = np.round(U).astype(int), np.round(V).astype(int)
    fu, fv = U - iu, V - iv
    inside = (iu >= 0) & (iu <= N - 1) & (iv >= 0) & (iv <= N - 1)
    tile_key = iu * 1000 + iv
    def mask_of(tiles):
        keys = np.array([u * 1000 + v for u, v in tiles] or [-999999])
        return np.isin(tile_key, keys)
    wat = mask_of(water)
    on_land = mask_of(land) if void_map else np.ones_like(inside)
    nr = np.random.default_rng(cfg.get('seed', 1))

    # palette: clean (Rift Plaza) -> drained by the rift
    side_c = [lerp(p, q, c) for p, q in zip([(226, 178, 182), (222, 174, 179), (229, 182, 186), (224, 176, 181)],
                                             [(120, 98, 136), (114, 92, 130), (124, 102, 140), (118, 96, 134)])]
    sl_c = lerp((206, 156, 166), (92, 72, 112), c)
    peach_c = [lerp(p, q, c * 0.85) for p, q in zip([(246, 216, 206), (243, 213, 203), (248, 218, 208)],
                                                     [(176, 156, 196), (170, 150, 192), (180, 160, 200)])]
    grout_c = lerp((230, 192, 186), (130, 108, 158), c)
    curb_c = lerp((242, 138, 199), (196, 110, 236), c)
    road_c, road_c2 = lerp((43, 37, 73), (28, 22, 50), c), lerp((52, 45, 85), (38, 30, 64), c)
    mag_c = lerp((105, 57, 105), (88, 44, 120), c)
    dash_c = lerp((90, 206, 236), (160, 236, 255), c * 0.4)

    img = np.zeros((H, W, 3))
    su, sv = U * 2, V * 2
    hs = ((np.floor(su).astype(int) * 73856093) ^ (np.floor(sv).astype(int) * 19349663)) & 0x7fffffff
    img[:] = np.array(side_c)[hs % 4]
    sl = (np.abs(su - np.round(su)) * TH < 0.5) | (np.abs(sv - np.round(sv)) * TH < 0.5)
    img[sl & ~inside] = sl_c
    peach = np.array(peach_c)
    hh = ((iu * 7349) ^ (iv * 1931)) & 0xffff
    pl = peach[hh % 3].astype(float)
    rim = (np.maximum(np.abs(fu), np.abs(fv)) > 0.40)
    pl[rim] = pl[rim] * 0.985 + 4
    grout = np.maximum(np.abs(fu), np.abs(fv)) * TH * 2 > TH - 1.2
    pl[grout] = grout_c
    img[inside] = pl[inside]
    edge = inside & (((iu == 0) & (fu < -0.5 + 1.6 / TH)) | ((iv == 0) & (fv < -0.5 + 1.6 / TH)) |
                     ((iu == N - 1) & (fu > 0.5 - 1.6 / TH)) | ((iv == N - 1) & (fv > 0.5 - 1.6 / TH)))
    img[edge] = curb_c

    # the void: deep space with violet haze and stars, and cliffs under the islands' near edges
    if void_map:
        haze = np.array(Image.fromarray((nr.random((H // 16, W // 16)) * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(float) / 255
        vd = np.zeros((H, W, 3))
        vd[:] = (12, 8, 26)
        vd += haze[..., None] * np.array([34, 14, 52])
        stars = nr.random((H, W))
        vd[stars < 0.004] = (180, 150, 230)
        vd[stars < 0.0012] = (250, 230, 255)
        island_px = on_land & inside
        cliff = np.zeros((H, W), bool); shade = np.zeros((H, W))
        for k in range(1, 15):
            up = np.zeros((H, W), bool); up[k:] = island_px[:-k]
            new = up & ~island_px & ~cliff
            shade[new] = k; cliff |= new
        img[~island_px] = vd[~island_px]
        rock = np.array([(78, 58, 104), (64, 46, 90), (52, 36, 76), (40, 28, 62)])
        cl = cliff & ~island_px
        img[cl] = rock[np.clip((shade[cl] / 4).astype(int), 0, 3)]
        jag = nr.random((H, W)) < 0.25
        img[cl & (shade > 11) & jag] = vd[cl & (shade > 11) & jag]
        img[cl & (shade <= 2)] = (110, 86, 140)

    # water: Coral's sea at the edge of the rift, black void water deeper in
    if water:
        wc = [lerp(p, q, c) for p, q in zip([(54, 168, 196), (44, 150, 182)], [(30, 22, 62), (22, 16, 48)])]
        ripple = ((np.floor(U * 3 + V * 1.3 + nr.random((H, W)) * 0.3) % 3) == 0)
        wimg = np.where(ripple[..., None], np.array(wc[0]), np.array(wc[1]))
        spark = nr.random((H, W)) < 0.01
        wimg[spark] = lerp((200, 250, 255), (190, 120, 255), c)
        img[wat] = wimg[wat]
        # foam / glowing shore one pixel in from land
        shore = wat & ~(np.roll(wat, 1, 0) & np.roll(wat, -1, 0) & np.roll(wat, 1, 1) & np.roll(wat, -1, 1))
        img[shore] = lerp((230, 250, 255), (200, 130, 255), c)
        landpx = ~wat
        wall = np.zeros((H, W), bool); wsh = np.zeros((H, W))
        for k in range(1, 7):
            up = np.zeros((H, W), bool); up[k:] = landpx[:-k]
            new = up & wat & ~wall
            wsh[new] = k; wall |= new
        img[wall] = np.array(lerp((150, 120, 140), (70, 52, 96), c)) * (1 - wsh[wall][:, None] * 0.06)

    # the rift spreads from the portal: the ground drains toward dark violet the closer it is
    if c > 0:
        pc = tb(*END) + [0, TH]
        r = np.hypot(xx - pc[0], (yy - pc[1]) / ISO_Y)
        k = (min(0.8, c * 1.4) * np.clip(1 - r / (160 + 220 * c), 0, 1) ** 1.1)[..., None]
        lum = img.mean(2, keepdims=True)
        dark = np.concatenate([lum * 0.5 + 26, lum * 0.36 + 14, lum * 0.66 + 44], 2)
        img = img * (1 - k) + dark * k

    # rift cracks in the pavement: jagged branching fissures out from the portal and the scars, dark with a glowing core
    crack = np.zeros((H, W), bool)
    if c > 0:
        dk = Image.new('L', (W, H), 0); br = Image.new('L', (W, H), 0)
        ddk, dbr = ImageDraw.Draw(dk), ImageDraw.Draw(br)
        def fissure(x, y, ang, ln, wdt, depth=0):
            pts = [(x, y)]
            t = 0
            while t < ln:
                ang += rng.uniform(-0.32, 0.32)
                x += math.cos(ang) * 2.5; y += math.sin(ang) * 2.5 * 0.62; t += 2.5
                pts.append((x, y))
                if depth < 2 and rng.random() < 0.035:
                    fissure(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.6, 1.1), ln * rng.uniform(0.3, 0.5), max(1, wdt - 1), depth + 1)
            ddk.line(pts, fill=255, width=wdt + 2)
            dbr.line(pts, fill=255, width=max(1, wdt - 1))
        p0 = tb(*END) + [0, TH]
        for a_ in range(int(5 + 7 * c)):
            a0 = a_ * math.tau / int(5 + 7 * c)
            fissure(p0[0] + math.cos(a0) * 44, p0[1] + math.sin(a0) * 26, a_ * math.tau / int(5 + 7 * c) + rng.uniform(-0.3, 0.3), rng.uniform(90, 160) * (0.6 + c), 2 if c > 0.5 else 1)
        for t_ in scars:
            q = tb(*t_)
            for _ in range(3):
                fissure(q[0], q[1], rng.uniform(0, math.tau), rng.uniform(30, 60), 1)
        for _ in range(int(14 * c)):
            fissure(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(0, math.tau), rng.uniform(20, 50), 1)
        keep = (best > PINK + 1) & ~wat
        if void_map:
            keep &= on_land & inside
        dmask = (np.array(dk) > 0) & keep
        crack = (np.array(br) > 0) & keep
        img[dmask] = lerp((96, 70, 110), (34, 16, 58), min(1, c * 1.6))
        img[crack] = lerp((70, 44, 96), (236, 150, 255), min(1, c * 1.5))

    # road: navy with pink neon edges and cyan dashes (Coral's), bridges over water, light bridges over the void
    over_w = wat & (best < PINK + 3)
    over_v = (~(on_land & inside)) & (best < PINK + 3) if void_map else np.zeros_like(wat)
    img[best < PINK] = curb_c if c > 0.5 else (242, 138, 199)
    img[best < MAG] = mag_c
    road = best < CORE
    img[road] = road_c
    img[road & (nr.random((H, W)) < 0.10)] = road_c2
    if water:   # bridge deck railings and posts
        rail = over_w & (best >= MAG) & (best < PINK + 3)
        img[rail] = lerp((236, 220, 230), (196, 170, 226), c)
        post = rail & ((np.floor(S / 8) % 2) == 0) & (best > PINK + 1)
        img[post] = lerp((120, 90, 120), (60, 40, 96), c)
        under = over_w & (best >= PINK + 3) & (best < PINK + 6)
        img[under] = img[under] * 0.6
    if void_map:   # energy bridges: the deck glows and the void shows through its edges
        deck = over_v & road
        img[deck] = (34, 26, 70)
        img[deck & ((np.floor(S / 4) % 2) == 0)] = (44, 34, 90)
        rimv = over_v & (best >= CORE) & (best < PINK + 2)
        img[rimv] = (150, 236, 255)
    per, AK = 12.0, 5

    def dir_at(k, q):
        pb, cum = PB[k], cums[k]
        i = int(np.clip(np.searchsorted(cum, q) - 1, 0, len(pb) - 2)); d = pb[i + 1] - pb[i]; return d / np.linalg.norm(d)
    k_ = np.floor(S / per); f = S - k_ * per
    dash = road & (np.abs(Nn) < 0.9) & (f < 5)
    t = S - np.floor(S / (per * AK)) * per * AK
    t = np.where(t > per * AK - per, t - per * AK, t)
    mid = np.round(S / (per * AK))
    straight = np.zeros_like(road)
    for k in range(len(PB)):
        ok = {m: float(np.dot(dir_at(k, m * per * AK - per - 2), dir_at(k, m * per * AK + 9))) > 0.999 and m * per * AK + 9 < cums[k][-1]
              for m in np.unique(mid[road & (LN == k)])}
        straight |= (LN == k) & np.vectorize(lambda m: ok.get(m, False))(mid)
    arrow = road & straight & (t > -per) & (t < 7) & (((t < 4) & (np.abs(Nn) < 0.9)) |
            ((t >= -1) & (np.abs(np.abs(Nn) - (6.0 - t) * 0.75) < 0.9) & (np.abs(Nn) < 4.2) & (t < 6.5)))
    slot = road & straight & (t > -per) & (t < per)
    img[dash & ~slot] = dash_c
    img[arrow] = dash_c
    # where roads cross (Crossroads), a cyan box marks the junction
    if cfg.get('mark_crossings'):
        for tt in cfg.get('crossings', ()):
            cc = tb(*tt)
            box = (np.abs(xx - cc[0]) / (TW / 2) + np.abs(yy - cc[1]) / (TH / 2) < 0.62) & (np.abs(xx - cc[0]) / (TW / 2) + np.abs(yy - cc[1]) / (TH / 2) > 0.5)
            img[box] = (255, 210, 120)
    ground = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((W * A, H * A), Image.NEAREST)
    os.makedirs(out, exist_ok=True)
    ground.save(os.path.join(out, 'ground.png'))

    # ---------- glints: the road's edge lines, with the distance along the road ----------
    xx2, yy2, best2, S2, _, _, cums2 = road_field(A)
    band = (best2 > MAG) & (best2 < PINK)
    gl = np.zeros((H * A, W * A, 3), np.uint8)
    sv16 = np.clip(S2 / cums2[0][-1] * 65535, 0, 65535).astype(int)
    gl[band, 0] = 255; gl[band, 1] = (sv16 >> 8)[band]; gl[band, 2] = (sv16 & 255)[band]
    Image.fromarray(gl).save(os.path.join(out, 'glints.png'))

    # ---------- scenery ----------
    spr_out = os.path.join(out, 'spr')
    os.makedirs(spr_out, exist_ok=True)
    for f_ in os.listdir(spr_out):
        if f_.endswith('.png'):
            os.remove(os.path.join(spr_out, f_))
    res_dir = 'res://assets/maps/' + os.path.basename(os.path.normpath(out)) + '/spr/'
    files = sorted(f_ for f_ in os.listdir(OD_SPR) if f_.endswith('.png'))
    def group(prefix):
        return [f_ for f_ in files if f_.startswith(prefix + '_') and f_[len(prefix) + 1:].split('.')[0].isdigit()]
    cache = {}
    def od(name):   # an Ocean Drive sprite after the corruption pass: (res path, local file)
        if c <= 0:
            return OD_RES + name, os.path.join(OD_SPR, name)
        if name not in cache:
            im = corrupt.corrupt(Image.open(os.path.join(OD_SPR, name)), c, hash(name) & 0xffff)
            im.save(os.path.join(spr_out, name), optimize=True)
            cache[name] = (res_dir + name, os.path.join(spr_out, name))
        return cache[name]
    def vp(name):
        return PROPS_RES + name + '.png', os.path.join(PROPS_DIR, name + '.png')
    BLD = ['bld_apartments', 'bld_arcade', 'bld_cafe', 'bld_diner', 'bld_hotel', 'bld_motel', 'bld_nightclub',
           'bld_palmhotel', 'bld_records', 'bld_techshop', 'bld_theater']
    FLAT = ['flower_tile', 'fountain_plaza', 'palm_planter_plaza', 'neon_fountain_tile', 'flower_plaza', 'hedge_sidewalk',
            'palms_hedge', 'tool_tile', 'plaza_props']
    STAND = [('palm_planter_a', 'palm'), ('palm_planter_b', 'palm'), ('lamp', 'neon'), ('neon_sign_a', 'neon'),
             ('neon_sign_b', 'neon'), ('bench', 'prop'), ('trash', 'prop'), ('vending', 'prop'), ('phone_booth', 'prop')]
    sprites = []
    def put(tex, kind, bottom, key, fit=None, label=None):
        res, local = tex
        im = Image.open(local).convert('RGBA')
        a_ = np.array(im)[..., 3]; ys, xs = np.where(a_ > 8)
        (w, h), (x0, y0, x1, y1) = im.size, (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
        s_ = 1.0 if fit is None else fit / (x1 - x0)
        tl = [round(bottom[0] * A - s_ * (x0 + x1) / 2, 1), round(bottom[1] * A - s_ * y1, 1)]
        if tl[0] > W * A or tl[0] + s_ * w < 0 or tl[1] > H * A or tl[1] + s_ * h < 0:
            return
        it = {'tex': res, 'tl': tl, 'key': round(key * A, 2), 'kind': kind, 'name': label or os.path.basename(local).rsplit('.', 1)[0], '_local': local}
        if s_ != 1.0:
            it['scale'] = round(s_, 4)
        sprites.append(it)
    def void_prop(u, v, size='m'):
        cc = tb(u, v)
        if size == 'l':
            name = rng.choice(['crystal_l_violet', 'crystal_l_void', 'monolith_a', 'monolith_b'])
            put(vp(name), 'prop', cc + [0, TH / 2 + 2], cc[1] + TH / 2, fit=TW * 2 * A * (0.6 if 'monolith' in name else 0.9))
        else:
            name = rng.choice(['crystal_m_violet', 'crystal_m_magenta', 'crystal_m_violet', 'growth_a', 'growth_b', 'rubble_a', 'rubble_b', 'crystal_m_cyan'])
            put(vp(name), 'prop', cc + [0, TH / 2 - 2], cc[1] + 2, fit=TW * A * (0.95 if 'rubble' not in name else 0.9))
    def flat_tile(u, v):
        cc = tb(u, v)
        put(od(rng.choice(group(rng.choice(FLAT)))), 'prop', cc + [0, TH / 2], cc[1] - TH / 2, fit=TW * A * 0.98)
    def stand(u, v, which=None):
        cc = tb(u, v)
        pre, kind = which or rng.choice(STAND)
        put(od(rng.choice(group(pre))), kind, cc + [0, 3], cc[1] + 3)

    # the portal (Ocean Drive's, same offset from the road's end as on Rift Plaza)
    e = tb(*END) * A
    sprites.append({'tex': OD_RES + 'portal_68.png', 'tl': [round(e[0] - 63.4, 1), round(e[1] - 217.3, 1)], 'key': round(e[1] + 39.3, 1),
                    'kind': 'portal', 'name': 'portal', 'ring': [round(e[0] + 61.5, 1), round(e[1] - 137.9, 1)], 'ring_r': [45.4, 65.2],
                    '_local': os.path.join(OD_SPR, 'portal_68.png')})
    # scars: void crystals that broke through the square
    for (u, v) in sorted(scars):
        void_prop(u, v)
    def on_board(u, v, m=40):
        cc = tb(u, v); return -m < cc[0] < W + m and -m < cc[1] < H + m * 1.5
    used = set(road_tiles) | portal_tiles | scars
    # entry streets stay open: the first legs of every lane, off the square
    for legs in lanes:
        for tt in tiles_of(legs):
            if in_sq(*tt):
                break
            for du in (-1, 0, 1):
                for dv in (-1, 0, 1):
                    used.add((tt[0] + du, tt[1] + dv))
    cands = [(u, v) for u in range(-12, N + 12) for v in range(-12, N + 12)
             if not in_sq(u, v) and on_board(u, v, 70) and (u, v) not in used]
    cands.sort(key=lambda q: (abs(q[0] - 7) + abs(q[1] - 7), q))
    types = BLD[:]; rng.shuffle(types); ti = 0
    voidiness = max(0.0, (c - 0.3) / 0.7)
    if void_map:
        # floating street chunks and void growths drift round the islands; nothing stands on the void itself
        for (u, v) in cands:
            if (u, v) in used or not on_board(u, v, 20) or rng.random() > 0.16:
                continue
            used.add((u, v))
            cc = tb(u, v)
            name = rng.choice(['chunk_a', 'chunk_b', 'chunk_c', 'chunk_a', 'monolith_a', 'crystal_l_void'])
            fit = TW * A * {'chunk_a': 1.0, 'chunk_b': 0.75, 'chunk_c': 1.3, 'monolith_a': 0.7, 'crystal_l_void': 1.1}[name]
            put(vp(name), 'prop', cc + [0, TH / 2 + 20], cc[1] + 18, fit=fit)
        # border tiles inside the square that aren't island get void crystals now and then
        for u in range(N):
            for v in range(N):
                tt = (u, v)
                if tt in used or tt in land or not on_board(u, v, 10) or rng.random() > 0.05:
                    continue
                used.add(tt)
                cc = tb(u, v)
                put(vp(rng.choice(['chunk_b', 'growth_c', 'crystal_s_violet'])), 'prop', cc + [0, TH / 2 + 10], cc[1] + 8, fit=TW * A * 0.7)
    else:
        for (u, v) in cands:
            blk = [(u, v), (u + 1, v), (u, v + 1), (u + 1, v + 1)]
            if any(b in used or in_sq(*b) for b in blk):
                continue
            cc = (tb(u, v) + tb(u + 1, v + 1)) / 2
            if not (-50 < cc[0] < W + 50 and -40 < cc[1] < H + 90):
                continue
            used.update(blk)
            r = rng.random()
            if r < 0.14:   # a little park
                for b in blk:
                    flat_tile(*b)
                continue
            if r < 0.14 + 0.35 * voidiness:   # the rift broke through: a big crystal or a monolith instead of a block
                void_prop(u + 0.5, v + 0.5, 'l')
                continue
            ty = types[ti % len(types)]; ti += 1
            if ti % len(types) == 0:
                rng.shuffle(types)
            put(od(rng.choice(group(ty))), 'bld', cc + [0, TH], cc[1], fit=TW * 2 * A * 0.96)
        for (u, v) in cands:
            if (u, v) in used or not on_board(u, v, 30):
                continue
            used.add((u, v))
            r = rng.random()
            if r < 0.3 * voidiness + 0.08 * c:
                void_prop(u, v)
            elif r < 0.45:
                flat_tile(u, v)
            elif r < 0.85:
                stand(u, v)
    # lamps along the entry streets
    if not void_map:
        for legs in lanes:
            ts = [tt for tt in tiles_of(legs) if not in_sq(*tt)]
            if len(ts) < 2:
                continue
            d = (ts[1][0] - ts[0][0], ts[1][1] - ts[0][1])
            side = (d[1], d[0])
            for i, tt in enumerate(ts):
                if i % 2 or not on_board(*tt, 10):
                    continue
                for sgn in (1, -1):
                    q = (tt[0] + side[0] * sgn, tt[1] + side[1] * sgn)
                    if q not in road_tiles and not in_sq(*q):
                        stand(*q, ('lamp', 'neon') if i % 4 == 0 else ('palm_planter_b', 'palm'))
    sprites.sort(key=lambda s_: s_['key'])

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
            elif q in portal_tiles or q in scars:
                r.append('2')
            elif buildable(q):
                r.append('0')
            else:
                r.append('3')
        rows.append(''.join(r))

    # ---------- glow: the sprites' neon, a faint road edge and the cracks ----------
    comp = np.zeros((H * A, W * A, 3))
    for s_ in sprites:
        im = Image.open(s_['_local']).convert('RGBA')
        sc = s_.get('scale', 1.0)
        if sc != 1.0:
            im = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.BILINEAR)
        a_ = np.array(im).astype(float)
        x0, y0 = int(round(s_['tl'][0])), int(round(s_['tl'][1]))
        xs, ys = max(0, -x0), max(0, -y0); xe, ye = min(im.width, W * A - x0), min(im.height, H * A - y0)
        if xe <= xs or ye <= ys:
            continue
        sub = a_[ys:ye, xs:xe]; al = sub[..., 3:4] / 255
        reg = comp[y0 + ys:y0 + ye, x0 + xs:x0 + xe]; reg[:] = reg * (1 - al) + sub[..., :3] * al
    mx, mn = comp.max(2), comp.min(2)
    gr = (comp[..., 1] > comp[..., 0]) & (comp[..., 1] > comp[..., 2])
    neon = ((mx > 170) & (mx - mn > 80) & ~gr)[..., None] * comp
    neon += band[..., None] * np.array([120, 50, 95])
    if c > 0:
        ck = np.array(Image.fromarray(crack.astype(np.uint8) * 255).resize((W * A, H * A), Image.NEAREST)) > 0
        neon += ck[..., None] * np.array([200, 110, 255]) * min(1, c * 1.3)
    g = np.array(Image.fromarray(np.clip(neon, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))).astype(float)
    g *= 200 / max(1, g.max())
    Image.fromarray(np.clip(g, 0, 255).astype(np.uint8)).resize((480, 260), Image.BILINEAR).save(os.path.join(out, 'glow.png'))

    for s_ in sprites:
        del s_['_local']
    o, a_, b_ = bf(tb(0, 0)), bf(tb(1, 0)), bf(tb(0, 1))
    hero = cfg.get('hero')
    layout = {
        'art_scale': A, 'size': [W * A, H * A], 'ground': 'ground.png', 'glow': 'glow.png', 'glints': 'glints.png', 'period': 4.0,
        'path': path_fields[0],
        'build': {'step': step, 'w': bw, 'h': bh, 'codes': {'0': 'build', '1': 'road', '2': 'object', '3': 'edge'}, 'rows': rows},
        'snap': {'origin': o, 'a': [round(a_[0] - o[0], 4), round(a_[1] - o[1], 4)], 'b': [round(b_[0] - o[0], 4), round(b_[1] - o[1], 4)]},
        'sprites': sprites,
        'rift': c,
    }
    if len(lanes) > 1:
        layout['paths'] = path_fields
    if hero:
        layout['hero'] = bf(tb(*hero))
    json.dump(layout, open(os.path.join(out, 'layout.json'), 'w'), separators=(',', ':'))
    spots = sum(1 for u in range(N) for v in range(N) if buildable((u, v)))
    L = sum(math.dist(p, q) for p, q in zip(path_fields[0], path_fields[0][1:]))
    return {'sprites': len(sprites), 'spots': spots, 'road': round(L), 'lanes': len(lanes), 'corrupted': len(cache)}
