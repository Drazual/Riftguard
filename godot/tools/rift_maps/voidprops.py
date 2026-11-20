# Void props for the Rift Creep maps: crystal clusters, monoliths, alien growths, floating street chunks and rubble.
# Everything is drawn from code at the game's one camera angle (true isometric, StyleRig.PITCH 35.264: a ground
# square shows as a diamond 0.577 as tall as wide), in 2x art pixels like Ocean Drive's sprites, with the same finish:
# flat-lit facets, a light top-left, a 1 px dark outline.
#   python3 voidprops.py <out dir>      writes one PNG per prop plus preview.png
import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ISO = math.tan(math.radians(30))           # ground y squash: 0.577
OUTLINE = (34, 18, 52, 255)

# crystal palettes: (light facet, mid facet, dark facet, core glow)
PAL = {
    'violet': ((236, 196, 255), (168, 104, 236), (92, 48, 160), (214, 140, 255)),
    'magenta': ((255, 196, 236), (236, 96, 196), (140, 36, 120), (255, 120, 220)),
    'cyan': ((206, 250, 255), (96, 206, 236), (40, 104, 160), (120, 236, 255)),
    'void': ((150, 120, 210), (74, 50, 128), (30, 18, 60), (176, 110, 255)),
}


def _canvas(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def _outline(im, col=OUTLINE):
    a = np.array(im)
    al = a[..., 3] > 40
    grow = np.zeros_like(al)
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        grow |= np.roll(np.roll(al, dy, 0), dx, 1)
    ring = grow & ~al
    a[ring] = col
    return Image.fromarray(a)


def _glow(im, col, radius=6, strength=0.55):
    a = np.array(im).astype(float)
    m = (a[..., 3] > 40).astype(float)
    g = np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(radius))).astype(float) / 255
    g = np.clip(g * strength * 1.6, 0, strength)
    base = np.zeros_like(a)
    base[..., :3] = col
    base[..., 3] = g * 255
    out = Image.fromarray(base.astype(np.uint8))
    out.alpha_composite(im)
    return out


def _shade(c, k):
    return tuple(int(max(0, min(255, v * k))) for v in c[:3]) + (255,)


def shard(d, base, ang, length, width, pal, rng):
    """One crystal: a 6-sided prism with a pointed tip, seen from the iso camera. base: its foot (px), ang: lean in
    radians from straight up (positive leans right)."""
    lt, md, dk, core = pal
    ux, uy = math.sin(ang), -math.cos(ang)            # up the shard, on screen
    px, py = -uy, ux                                   # across it
    body = length * 0.72
    w = width / 2
    # the near three faces of the prism (left lit, middle, right shaded); the foot is a squashed hexagon
    foot = [(base[0] + px * w * k, base[1] + py * w * k + w * ISO * s) for k, s in ((-1, 0), (-0.5, 0.6), (0.5, 0.6), (1, 0))]
    top = [(x + ux * body, y + uy * body) for x, y in foot]
    tip = (base[0] + ux * length, base[1] + uy * length)
    faces = [(foot[0], foot[1], top[1], top[0], lt), (foot[1], foot[2], top[2], top[1], md), (foot[2], foot[3], top[3], top[2], dk)]
    for a, b, c, e, col in faces:
        d.polygon([a, b, c, e], fill=col + (255,))
    d.polygon([top[0], top[1], tip], fill=_shade(lt, 1.06))
    d.polygon([top[1], top[2], tip], fill=_shade(md, 1.12))
    d.polygon([top[2], top[3], tip], fill=_shade(dk, 1.1))
    # a bright ridge and a glint
    d.line([foot[1], top[1], tip], fill=(255, 255, 255, 200), width=1)
    gx, gy = top[0][0] * 0.6 + top[1][0] * 0.4, top[0][1] * 0.6 + top[1][1] * 0.4
    d.line([(gx, gy + 3), (gx + ux * 6, gy + uy * 6 + 3)], fill=(255, 255, 255, 230), width=1)
    # a glowing seam inside the body
    sx0 = (foot[1][0] + foot[2][0]) / 2; sy0 = (foot[1][1] + foot[2][1]) / 2
    d.line([(sx0, sy0 - 2), (sx0 + ux * body * 0.8, sy0 + uy * body * 0.8)], fill=core + (150,), width=1)


def crystal(size='m', hue='violet', seed=0, ground=True):
    """A cluster of shards on a little patch of broken ground. Sizes: s fits a quarter tile, m one tile, l a 2x2 block."""
    rng = random.Random(seed)
    W, H = {'s': (56, 72), 'm': (96, 120), 'l': (176, 210)}[size]
    n = {'s': 3, 'm': 5, 'l': 8}[size]
    L = {'s': 34, 'm': 62, 'l': 120}[size]
    im = _canvas(W, H)
    d = ImageDraw.Draw(im)
    cx, cy = W / 2, H - W * ISO / 2 - 3
    pal = PAL[hue]
    if ground:   # a broken, dark patch with glowing cracks under the shards
        rx, ry = W * 0.42, W * 0.42 * ISO
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(46, 30, 72, 255))
        d.ellipse([cx - rx * 0.8, cy - ry * 0.8, cx + rx * 0.8, cy + ry * 0.8], fill=(64, 42, 98, 255))
        for _ in range(4):
            a = rng.uniform(0, math.tau)
            d.line([(cx, cy), (cx + math.cos(a) * rx * 0.95, cy + math.sin(a) * ry * 0.95)], fill=pal[3] + (220,), width=1)
    specs = []
    for i in range(n):
        big = i == 0
        lean = rng.uniform(-0.55, 0.55) if not big else rng.uniform(-0.12, 0.12)
        ln = L * (1.0 if big else rng.uniform(0.38, 0.75))
        wd = ln * rng.uniform(0.26, 0.34)
        off = (0, 0) if big else (rng.uniform(-0.32, 0.32) * W, rng.uniform(-0.12, 0.12) * W * ISO)
        specs.append(((cx + off[0], cy + off[1]), lean, ln, wd))
    specs.sort(key=lambda s: s[0][1])          # back to front
    for (b, lean, ln, wd) in specs:
        shard(d, b, lean, ln, wd, pal, rng)
    im = _outline(im)
    return _glow(im, pal[3], radius=7 if size != 's' else 4)


def monolith(seed=0, hue='violet'):
    """A tall black slab of void stone, its faces split by glowing cracks, floating a little over a crater."""
    rng = random.Random(seed)
    W, H = 104, 200
    im = _canvas(W, H)
    d = ImageDraw.Draw(im)
    cx, foot = W / 2 + 2, H - 18
    pal = PAL[hue]
    d.ellipse([cx - 40, foot - 40 * ISO, cx + 40, foot + 40 * ISO], fill=(30, 18, 54, 255))
    d.ellipse([cx - 28, foot - 28 * ISO, cx + 28, foot + 28 * ISO], fill=pal[2] + (255,))
    d.ellipse([cx - 18, foot - 18 * ISO, cx + 18, foot + 18 * ISO], fill=pal[3] + (200,))
    w, dpt, h, lift = 26, 16, 112, 10
    b = foot - lift
    # left and right faces of a box turned 45 degrees, its front edge toward the camera
    L = [(cx - w, b - w * ISO), (cx, b), (cx, b - h), (cx - w, b - w * ISO - h)]
    R = [(cx, b), (cx + dpt, b - dpt * ISO), (cx + dpt, b - dpt * ISO - h), (cx, b - h)]
    T0, T1, T2 = L[3], L[2], R[2]
    T = [T0, T1, T2, (T0[0] + T2[0] - T1[0], T0[1] + T2[1] - T1[1])]
    d.polygon(L, fill=(58, 40, 96, 255))
    d.polygon(R, fill=(32, 20, 60, 255))
    # pointed cap over the top face
    apex = ((T[0][0] + T[2][0]) / 2, (T[1][1] + T[3][1]) / 2 - 34)
    d.polygon([T[0], T[1], apex], fill=(84, 60, 132, 255))
    d.polygon([T[1], T[2], apex], fill=(46, 30, 84, 255))
    d.line([T[1], apex], fill=(150, 120, 210, 255), width=1)
    # glowing runes and cracks
    for k in range(5):
        y = b - 18 - k * 22 - rng.uniform(0, 6)
        x0 = cx - w * 0.85
        d.line([(x0, y - 0.55 * w * ISO * 0.2), (cx - 3, y + w * ISO * 0.45)], fill=pal[3] + (230,), width=1)
    pts = [(cx + 2, b - 6)]
    for _ in range(7):
        pts.append((cx + 2 + rng.uniform(1, dpt - 2), pts[-1][1] - rng.uniform(10, 20)))
    d.line(pts, fill=pal[0] + (255,), width=1)
    im = _outline(im)
    return _glow(im, pal[3], radius=8, strength=0.45)


def growth(seed=0, hue='magenta'):
    """Alien growth: curved, tapering spines pushing out of a dark lump, tipped with glowing pods."""
    rng = random.Random(seed)
    W, H = 150, 126
    im = _canvas(W, H)
    d = ImageDraw.Draw(im)
    cx, cy = W / 2, H - 20
    pal = PAL[hue]
    d.ellipse([cx - 34, cy - 14, cx + 34, cy + 14], fill=(40, 22, 58, 255))
    d.ellipse([cx - 26, cy - 18, cx + 22, cy + 6], fill=(70, 34, 86, 255))
    spines = []
    for i in range(7):
        a = rng.uniform(-0.8, 0.8)
        ln = rng.uniform(40, 78)
        bx = cx + rng.uniform(-20, 20)
        spines.append((bx, a, ln))
    spines.sort(key=lambda s: -abs(s[1]))
    for bx, a, ln in spines:
        pts = []
        steps = 14
        for k in range(steps + 1):
            t = k / steps
            bend = a * t * t * 1.4
            x = bx + math.sin(a * 0.5 + bend) * ln * t
            y = cy - 6 - math.cos(a * 0.5 + bend) * ln * t
            pts.append((x, y, 7 * (1 - t) + 1.2))
        for (x0, y0, r0), (x1, y1, r1) in zip(pts, pts[1:]):
            d.line([(x0, y0), (x1, y1)], fill=(92, 40, 110, 255), width=max(1, int(r0 * 2)))
        for (x0, y0, r0), (x1, y1, r1) in zip(pts, pts[1:]):
            d.line([(x0 - r0 * 0.4, y0), (x1 - r1 * 0.4, y1)], fill=(150, 70, 160, 255), width=1)
        tx, ty, _ = pts[-1]
        d.ellipse([tx - 4, ty - 4, tx + 4, ty + 4], fill=pal[1] + (255,))
        d.ellipse([tx - 2, ty - 3, tx + 1, ty], fill=pal[0] + (255,))
    im = _outline(im)
    return _glow(im, pal[3], radius=6, strength=0.5)


def chunk(seed=0, w_tiles=1.0, crystals=True):
    """A torn-off piece of street floating in the void: a paved iso slab with a jagged rocky underside."""
    rng = random.Random(seed)
    tw = 96 * w_tiles                         # a tile is 96 art px wide
    W, H = int(tw + 24), int(tw * ISO + 120)
    im = _canvas(W, H)
    d = ImageDraw.Draw(im)
    cx, cy = W / 2, 14 + tw * ISO / 2 + (40 if crystals else 4)
    hw, hh = tw / 2, tw * ISO / 2
    top = [(cx - hw, cy), (cx, cy - hh), (cx + hw, cy), (cx, cy + hh)]
    # underside: a ragged cone of rock
    depth = rng.uniform(46, 70) * max(0.7, w_tiles)
    lp, rp = [], []
    for k in range(9):
        t = k / 8
        lp.append((cx - hw + hw * t, cy + hh * t + depth * math.sin(t * math.pi / 2) * rng.uniform(0.7, 1.0)))
        rp.append((cx + hw * t, cy + hh - hh * t + depth * math.cos(t * math.pi / 2) * rng.uniform(0.7, 1.0)))
    d.polygon([(cx - hw, cy)] + lp + [(cx, cy + hh)], fill=(64, 46, 88, 255))
    d.polygon([(cx, cy + hh)] + rp + [(cx + hw, cy)], fill=(40, 28, 62, 255))
    for k in range(5):
        x = cx - hw * 0.8 + k * hw * 0.38
        d.line([(x, cy + hh * 0.4 + 6), (x + 3, cy + hh * 0.4 + depth * 0.5)], fill=(30, 20, 46, 255), width=1)
    # paved top with a broken edge
    d.polygon(top, fill=(196, 160, 196, 255))
    # paving: a grid of small diamonds, a few missing
    n = max(2, int(round(3 * w_tiles)))
    for i in range(n):
        for j in range(n):
            if rng.random() < 0.12:
                continue
            u0, v0 = i / n, j / n
            q = lambda u, v: (cx - hw + (u + v) * hw, cy + (u - v) * hh)
            pts = [q(u0 + 0.06 / n, v0 + 0.06 / n), q(u0 + 0.94 / n, v0 + 0.06 / n), q(u0 + 0.94 / n, v0 + 0.94 / n), q(u0 + 0.06 / n, v0 + 0.94 / n)]
            c = rng.choice([(228, 192, 214), (220, 184, 208), (234, 200, 220)])
            d.polygon(pts, fill=c + (255,))
    d.line([top[0], top[3], top[2]], fill=(242, 138, 199, 255), width=2)
    if crystals:
        c = crystal('s', rng.choice(['violet', 'magenta']), seed + 3, ground=False)
        im.alpha_composite(c, (int(cx - c.width / 2 + rng.uniform(-hw * 0.3, hw * 0.3)), int(cy - c.height + 6)))
    im = _outline(im)
    return im


def rubble(seed=0):
    """Broken paving slabs and a couple of crystal chips: a small flat prop for one tile."""
    rng = random.Random(seed)
    W, H = 96, 64
    im = _canvas(W, H)
    d = ImageDraw.Draw(im)
    for _ in range(6):
        x, y = rng.uniform(18, W - 18), rng.uniform(H - 40, H - 14)
        s = rng.uniform(6, 13)
        a = rng.uniform(0, math.pi)
        pts = [(x + math.cos(a + k * math.pi / 2) * s, y + math.sin(a + k * math.pi / 2) * s * ISO) for k in range(4)]
        d.polygon([(px, py + 4) for px, py in pts], fill=(70, 50, 96, 255))
        d.polygon(pts, fill=(176, 146, 192, 255))
    for k in range(2):
        c = crystal('s', 'violet' if k else 'magenta', seed * 7 + k, ground=False).resize((30, 38), Image.LANCZOS)
        im.alpha_composite(c, (int(rng.uniform(14, W - 44)), int(H - 46 + rng.uniform(-4, 4))))
    return _outline(im)


PROPS = {
    'crystal_s_violet': lambda: crystal('s', 'violet', 1),
    'crystal_s_magenta': lambda: crystal('s', 'magenta', 2),
    'crystal_m_violet': lambda: crystal('m', 'violet', 3),
    'crystal_m_magenta': lambda: crystal('m', 'magenta', 4),
    'crystal_m_cyan': lambda: crystal('m', 'cyan', 5),
    'crystal_l_violet': lambda: crystal('l', 'violet', 6),
    'crystal_l_void': lambda: crystal('l', 'void', 7),
    'monolith_a': lambda: monolith(1),
    'monolith_b': lambda: monolith(2, 'magenta'),
    'growth_a': lambda: growth(1),
    'growth_b': lambda: growth(2, 'violet'),
    'growth_c': lambda: growth(3, 'cyan'),
    'chunk_a': lambda: chunk(1, 1.0),
    'chunk_b': lambda: chunk(2, 0.7, False),
    'chunk_c': lambda: chunk(3, 1.3),
    'rubble_a': lambda: rubble(1),
    'rubble_b': lambda: rubble(2),
}


def build(out):
    os.makedirs(out, exist_ok=True)
    ims = {}
    for k, f in PROPS.items():
        ims[k] = f()
        ims[k].save(os.path.join(out, k + '.png'))
    return ims


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    ims = build(out)
    W = sum(i.width for i in ims.values()) + 8 * len(ims)
    H = max(i.height for i in ims.values())
    sheet = Image.new('RGBA', (W, H), (36, 28, 58, 255))
    x = 0
    for i in ims.values():
        sheet.alpha_composite(i, (x, H - i.height))
        x += i.width + 8
    sheet.save(sys.argv[2] if len(sys.argv) > 2 else os.path.join(out, 'preview.png'))
