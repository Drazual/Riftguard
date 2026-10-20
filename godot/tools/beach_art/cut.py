"""Cuts the animated sprites out of the Coral Spiral sheets (6 frames a row, on a blurred gradient background).

The background is smooth, so each frame's cell gets a fitted background surface (a quadratic per colour
channel, fitted to the cell's border) and anything that differs from it enough is the sprite."""
import json, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/beach'

# name: (sheet, y0, y1, threshold, anchor)  anchor 'base' keeps the bottom centre still between frames
ANIMS = {
    'palm_teal': ('props.png', 10, 262, 34, 'base'),
    'palm_pink': ('props.png', 265, 520, 34, 'base'),
    'umbrella': ('props.png', 530, 775, 34, 'base'),
    'flag': ('props.png', 780, 975, 34, 'base'),
    'neonpalm': ('city.png', 50, 320, 20, 'base'),
    'arcadesign': ('city.png', 360, 515, 34, 'base'),
    'fan': ('city.png', 545, 725, 34, 'base'),
    'lamp': ('city.png', 760, 965, 34, 'base'),
    'jetski': ('boats.png', 20, 235, 30, 'centre'),
    'speedboat': ('boats.png', 250, 520, 30, 'centre'),
    'buoy': ('boats.png', 545, 735, 30, 'centre'),
    'pad': ('boats.png', 780, 975, 30, 'centre'),
    'fountain': ('water.png', 745, 990, 30, 'centre'),
}


def fit_bg(a, border=6):
    h, w, _ = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.zeros((h, w), bool)
    m[:border] = m[-border:] = True
    m[:, :border] = m[:, -border:] = True
    X = lambda x, y: np.stack([np.ones_like(x), x, y, x * x, y * y, x * y], -1).astype(np.float64)
    A = X(xx[m] / w, yy[m] / h)
    out = np.zeros_like(a)
    full = X(xx / w, yy / h)
    for ch in range(3):
        coef, *_ = np.linalg.lstsq(A, a[..., ch][m], rcond=None)
        out[..., ch] = full @ coef
    return out


def cut_cell(a, thr, core=0):
    bg = fit_bg(a)
    diff = np.abs(a - bg).max(-1)
    fg = diff > thr
    if core:
        # only keep what sits close to the strongly contrasting body (drops soft glow haze around it)
        c = ndimage.binary_opening(diff > core, iterations=1)
        cl, cn = ndimage.label(c)
        if cn:
            cs = ndimage.sum(c, cl, range(1, cn + 1))
            body = ndimage.binary_fill_holes(ndimage.binary_closing(np.isin(cl, [i + 1 for i in range(cn) if cs[i] >= cs.max() * 0.03]), iterations=3))
            fg &= ndimage.binary_dilation(body, iterations=4)
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(fg)
    if n == 0:
        return None
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    # the sprite is the biggest piece plus the bits right next to it (sparkles, ripples); far blobs are background
    main_ = lab == (int(np.argmax(sizes)) + 1)
    near = ndimage.binary_dilation(main_, iterations=5)
    lum = a.mean(-1)
    big = int(np.argmax(sizes)) + 1
    keep = [i + 1 for i in range(n) if i + 1 == big or ((near & (lab == i + 1)).any() and lum[lab == i + 1].mean() > 150)]
    fg = np.isin(lab, keep)
    fg = ndimage.binary_fill_holes(ndimage.binary_closing(np.pad(fg, 4), iterations=2))[4:-4, 4:-4]
    # soften the edge: pixels that are only a little off the background become see-through
    alpha = np.clip((diff - thr * 0.6) / (thr * 0.8), 0, 1)
    inner = ndimage.binary_erosion(fg, iterations=2)
    alpha = np.where(inner, 1.0, np.where(fg, np.maximum(alpha, 0.5), 0.0))
    rgba = np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(rgba, 'RGBA')


def cut_strip(path, y0, y1, thr, anchor, core=0):
    """One row of 6 frames from a sheet, cut out and lined up in a strip of equal cells."""
    im = np.asarray(Image.open(path).convert('RGB')).astype(np.float64)
    frames = []
    for i in range(6):
        x0, x1 = i * 256 + 4, (i + 1) * 256 - 4
        f = cut_cell(im[y0:y1, x0:x1], thr, core)
        frames.append((f, f.getbbox()))
    # one box for every frame, lined up on the anchor
    W = max(bb[2] - bb[0] for _, bb in frames)
    H = max(bb[3] - bb[1] for _, bb in frames)
    out = Image.new('RGBA', (W * 6, H), (0, 0, 0, 0))
    for i, (f, bb) in enumerate(frames):
        w, h = bb[2] - bb[0], bb[3] - bb[1]
        y = H - h if anchor == 'base' else round((H - h) / 2)
        out.alpha_composite(f.crop(bb), (i * W + round((W - w) / 2), y))
    return out


def main():
    meta = {}
    for name, (sheet, y0, y1, thr, anchor) in ANIMS.items():
        out = cut_strip(os.path.join(SRC, sheet), y0, y1, thr, anchor, 80 if anchor == 'centre' and name != 'fountain' else 0)
        out.save(os.path.join(ROOT, 'spr', name + '.png'))
        meta[name] = [out.width // 6, out.height]
        print(name, out.width // 6, out.height)
    # water tiles and shore pieces are taken as they are (no background to remove inside them)
    wat = Image.open(os.path.join(SRC, 'water.png')).convert('RGB')
    for name, (y0, y1) in {'deep': (66, 264), 'mid': (296, 498), 'shallow': (532, 724)}.items():
        strip = Image.new('RGB', (200 * 6, 190))
        xs = [52, 298, 544, 790, 1036, 1282]
        for i, x in enumerate(xs):
            strip.paste(wat.crop((x + 4, y0 + 4, x + 204, y0 + 194)), (i * 200, 0))
        strip.save(os.path.join(ROOT, 'spr', 'water_' + name + '.png'))
    # shore foam: white and cyan over a teal glow, kept as a soft alpha of how much brighter than the glow it is
    # named after the island edge each one lines: sand above the 'bottom' strip, sand right of the 'left' strip...
    foam = np.asarray(Image.open(os.path.join(SRC, 'foam.png')).convert('RGB')).astype(np.float64)
    for name, (y0, y1) in {'foam_bottom': (80, 210), 'foam_left': (262, 502), 'foam_top': (590, 730), 'foam_right': (748, 982)}.items():
        cells = []
        for i in range(6):
            a = foam[y0:y1, i * 256 + 4:(i + 1) * 256 - 4]
            bg = fit_bg(a, 4)
            lift = (a - bg).max(-1)
            # the soft glow is smooth, the foam is crisp: measure brightness against a blurred copy too
            local = (a - ndimage.gaussian_filter(a, (6, 6, 0))).max(-1)
            alpha = np.clip((lift - 45) / 70, 0, 1) * np.clip((local + 10) / 30, 0, 1)
            alpha[ndimage.label(alpha > 0)[0] == 0] = 0
            img = Image.fromarray(np.dstack([np.clip(a, 0, 255), alpha * 255]).astype(np.uint8), 'RGBA')
            cells.append(img)
        bbs = [c.getbbox() for c in cells]
        bb = (min(b[0] for b in bbs), min(b[1] for b in bbs), max(b[2] for b in bbs), max(b[3] for b in bbs))
        W, H = bb[2] - bb[0], bb[3] - bb[1]
        out = Image.new('RGBA', (W * 6, H))
        for i, c in enumerate(cells):
            out.paste(c.crop(bb), (i * W, 0))
        out.save(os.path.join(ROOT, 'spr', name + '.png'))
        meta[name] = [W, H]
        print(name, W, H)
    json.dump(meta, open(os.path.join(ROOT, 'spr', 'sizes.json'), 'w'))


if __name__ == '__main__':
    main()
