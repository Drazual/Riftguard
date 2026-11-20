# The corruption pass: turns one of Ocean Drive's clean neon sprites into a rift-touched one. The colours drain toward
# violet and darken, the neon shifts to magenta, cracks with a glowing core split the walls, and from about halfway
# small void crystals push up round its foot. The sprite keeps its exact size, so its layout position is unchanged.
#   corrupt(image, level 0..1, seed) -> image
import colorsys, math, random
import numpy as np
from PIL import Image, ImageDraw

import voidprops

VIOLET = 0.76


def _hsv(a):
    rgb = a[..., :3] / 255.0
    mx, mn = rgb.max(-1), rgb.min(-1)
    v = mx
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) / 6
    return h, s, v


def _rgb(h, s, v):
    i = np.floor(h * 6).astype(int) % 6
    f = h * 6 - np.floor(h * 6)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    out = np.zeros(h.shape + (3,))
    for k, (r, g, b) in enumerate(((v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q))):
        m = i == k
        out[m, 0], out[m, 1], out[m, 2] = r[m], g[m], b[m]
    return out * 255


def _toward(h, target, k):
    dh = ((target - h + 0.5) % 1.0) - 0.5
    return (h + dh * k) % 1.0


def corrupt(im, level, seed=0):
    rng = random.Random(seed)
    a = np.array(im.convert('RGBA')).astype(float)
    alpha = a[..., 3]
    h, s, v = _hsv(a)
    neon = (s > 0.45) & (v > 0.72)
    c = level
    h2 = np.where(neon, _toward(h, 0.86, c * 0.6), _toward(h, VIOLET, c * 0.85 * np.clip(s * 1.6, 0.3, 1)))
    s2 = np.where(neon, s, s * (1 - 0.25 * c) + 0.12 * c)
    v2 = np.where(neon, v, v * (1 - 0.5 * c))
    out = a.copy()
    out[..., :3] = _rgb(h2, np.clip(s2, 0, 1), np.clip(v2, 0, 1))
    img = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    solid = alpha > 200
    ys, xs = np.where(solid)
    if len(xs) == 0:
        return img
    # cracks: short branching random walks across the solid part
    area = len(xs)
    n = int(c * c * area / 1600) + (1 if c > 0.2 else 0)
    core = (226, 130, 255, 255)
    for _ in range(n):
        k = rng.randrange(len(xs))
        x, y = float(xs[k]), float(ys[k])
        ang = rng.uniform(0, math.tau)
        pts = [(x, y)]
        for _ in range(rng.randint(6, 18)):
            ang += rng.uniform(-0.8, 0.8)
            x += math.cos(ang) * 2.2
            y += math.sin(ang) * 2.2
            xi, yi = int(x), int(y)
            if not (0 <= xi < img.width and 0 <= yi < img.height) or not solid[yi, xi]:
                break
            pts.append((x, y))
        if len(pts) < 3:
            continue
        d.line(pts, fill=(24, 10, 40, 255), width=3)
        d.line(pts, fill=core if c >= 0.45 else (70, 40, 96, 255), width=1)
    # crystals round the foot
    if c >= 0.45:
        foot = {}
        for x, y in zip(xs, ys):
            if y > foot.get(x, -1):
                foot[x] = y
        cols = sorted(foot)
        cnt = 1 + int((c - 0.45) * 7 * min(1.5, len(cols) / 90))
        for i in range(cnt):
            x = rng.choice(cols[len(cols) // 8: -len(cols) // 8 or None])
            y = foot[x]
            hgt = int((rng.randint(20, 30) + 14 * c) * min(1.0, 0.4 + len(cols) / 120))
            cr = voidprops.crystal('s', rng.choice(['violet', 'violet', 'magenta']), rng.randrange(1000), ground=False)
            cr = cr.resize((max(8, int(cr.width * hgt / cr.height)), hgt), Image.LANCZOS)
            px, py = int(x - cr.width / 2), int(y - cr.height + 4)
            px = max(0, min(img.width - cr.width, px))
            py = max(0, py)
            img.alpha_composite(cr, (px, py))
    # keep the original silhouette (crystals may poke out only inside it) plus anything the crystals added
    return img
