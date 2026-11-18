"""Builds the Test Room's hand-painted map (assets/maps/test_room/) from Coral Spiral's art.

It keeps Coral's beach, pier, entry and outer road, and paints over the inner spiral with clean plaza so the road is
simple: in over the pier, up, across, and a short leg down to the core. Props inside the old spiral go; the ones
around the beach stay. Run from the repo root:

    python3 godot/tools/build_test_room_art.py
"""
import json
import math
import os

import numpy as np
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets/maps/map2_coral")
OUT = os.path.join(ROOT, "assets/maps/test_room")
CORAL_RES = "res://assets/maps/map2_coral/"

# field units, the start of Coral's own road
PATH = [[-57.5, 24.28], [230.0, 245.6], [480.0, 53.15], [880.0, 361.07], [805.0, 418.8]]
# Coral's spiral, used to drop the props that stood inside it
INNER = [(230.0, 245.6), (480.0, 53.15), (880.0, 361.07), (480.0, 553.52), (255.0, 380.31)]
KEEP_INNER = {"core"}  # moved to the new road end instead


def px(p):
    """Field units to board pixels (768x416): x * 0.8, (40 + 0.75 y) * 0.8."""
    return np.array([p[0] * 0.8, (40.0 + 0.75 * p[1]) * 0.8])


def seg_dist(pts, a, b):
    """Distance from every point in pts (N,2) to segment ab, and the projection t (0..1)."""
    ab = b - a
    t = np.clip(((pts - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(pts - (a + t[:, None] * ab), axis=1)


def poly_dist(pts, poly):
    d = np.full(len(pts), np.inf)
    for i in range(len(poly) - 1):
        d = np.minimum(d, seg_dist(pts, poly[i], poly[i + 1]))
    return d


def inside(p, poly):
    x, y = p
    n = len(poly)
    hit = False
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            hit = not hit
    return hit


def road_mask(img):
    """Road pixels in Coral's ground: the dark road, its pink rim and the cyan arrows (plus a little anti-aliasing)."""
    a = img.astype(int)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = (r + g + b) / 3
    dark = lum < 110
    pink = (r > 180) & (g < 170) & (b > 140) & (r - g > 60)
    cyan = (b > 150) & (g > 150) & (r < 140)
    m = dark | pink | cyan
    # grow by 2 px to take the soft edge
    for _ in range(2):
        g2 = m.copy()
        g2[1:, :] |= m[:-1, :]
        g2[:-1, :] |= m[1:, :]
        g2[:, 1:] |= m[:, :-1]
        g2[:, :-1] |= m[:, 1:]
        m = g2
    return m


def main():
    os.makedirs(OUT, exist_ok=True)
    L = json.load(open(os.path.join(SRC, "layout.json")))
    W, H = L["size"]
    base = np.array(Image.open(os.path.join(SRC, "ground.png")).convert("RGB"))
    road = road_mask(base)

    ys, xs = np.mgrid[0:H, 0:W]
    pts = np.stack([xs.ravel(), ys.ravel()], 1).astype(float)
    keep_poly = [px(p) for p in PATH]
    dkeep = poly_dist(pts, keep_poly).reshape(H, W)
    # the kept road: Coral's road pixels along the new path (the last leg is cut flat where the old road turned)
    a, b = keep_poly[-2], keep_poly[-1]
    ab = b - a
    t = (((pts - a) @ ab) / (ab @ ab)).reshape(H, W)
    beyond = (t > 1.0) & (seg_dist(pts, a, b).reshape(H, W) < 30) & (poly_dist(pts, keep_poly[:-1]).reshape(H, W) > 30)
    dold = poly_dist(pts, [px(p) for p in L["path"]]).reshape(H, W)
    kept = road & (dkeep < 16) & ~beyond
    erase = road & (dold < 16) & ~kept

    # paint the erased road with plaza: the plaza's diamond tiles repeat exactly every 40 px across, so take each
    # pixel from the nearest clean spot 40, 80, ... px to the left or right
    # never copy from the road or the grey sand patches on the plaza
    ai = base.astype(int)
    patch = (ai[..., 0] - ai[..., 2] < 28) & (ai.sum(-1) > 330)
    for _ in range(2):
        g2 = patch.copy()
        g2[1:, :] |= patch[:-1, :]
        g2[:-1, :] |= patch[1:, :]
        g2[:, 1:] |= patch[:, :-1]
        g2[:, :-1] |= patch[:, 1:]
        patch = g2
    bad = road | patch
    # sand patches the old road cut through would be left as half circles: take them out whole
    cut = erase.copy()
    for _ in range(40):
        g2 = cut.copy()
        g2[1:, :] |= cut[:-1, :]
        g2[:-1, :] |= cut[1:, :]
        g2[:, 1:] |= cut[:, :-1]
        g2[:, :-1] |= cut[:, 1:]
        g2 &= patch | erase
        if (g2 == cut).all():
            break
        cut = g2
    erase = cut & ~kept
    out = base.copy()
    ey, ex = np.nonzero(erase)
    miss = 0
    for y, x in zip(ey, ex):
        for k in range(1, 20):
            done = False
            for s in (k, -k):
                sx = x + 40 * s
                if 0 <= sx < W and not bad[y, sx]:
                    out[y, x] = base[y, sx]
                    done = True
                    break
            if done:
                break
        else:
            miss += 1
    print("erased %d road pixels (%d left as they were)" % (len(ey), miss))

    # every ground frame: only the plaza changes, the water keeps moving
    frames = L.get("ground_frames", [L["ground"]])
    for f in frames:
        im = np.array(Image.open(os.path.join(SRC, f)).convert("RGB"))
        im[erase] = out[erase]
        Image.fromarray(im).save(os.path.join(OUT, f))

    # glints (road edge lines): drop the erased road's
    gl = np.array(Image.open(os.path.join(SRC, L["glints"])))
    grow = erase.copy()
    for _ in range(3):
        g2 = grow.copy()
        g2[1:, :] |= grow[:-1, :]
        g2[:-1, :] |= grow[1:, :]
        g2[:, 1:] |= grow[:, :-1]
        g2[:, :-1] |= grow[:, 1:]
        grow = g2
    gl[grow & ~kept] = 0
    Image.fromarray(gl).save(os.path.join(OUT, L["glints"]))

    # props: drop the ones inside the old spiral, move the core to the new road end
    end_shift = px(PATH[-1]) - px(L["path"][-1])
    sprites = []
    dropped = []
    for s in L["sprites"]:
        s = dict(s)
        foot = ((s["tl"][0] + 0) / 0.8, (s["key"] / 0.8 - 40.0) / 0.75)
        path = s["tex"] if s["tex"].startswith("res://") else CORAL_RES + "spr/" + s["tex"]
        tex = Image.open(os.path.join(ROOT, path.replace("res://", "")))
        sc = s.get("scale", 1.0)
        foot = ((s["tl"][0] + tex.width * sc / 2) / 0.8, foot[1])
        if s["kind"] == "core":
            s["tl"] = [s["tl"][0] + end_shift[0], s["tl"][1] + end_shift[1]]
            s["key"] = s["key"] + end_shift[1]
            if "ring" in s:
                s["ring"] = [s["ring"][0] + end_shift[0], s["ring"][1] + end_shift[1]]
        elif inside(foot, INNER):
            dropped.append((s, tex.width * sc, tex.height * sc))
            continue
        sprites.append(s)
    print("kept %d props, dropped %d" % (len(sprites), len(dropped)))

    # glow (quarter res): clear the erased road and the dropped props' lights
    gw = np.array(Image.open(os.path.join(SRC, L["glow"])).convert("RGB"))
    q = np.array(Image.fromarray(grow.astype(np.uint8) * 255).resize((gw.shape[1], gw.shape[0]), Image.BOX)) > 0
    gw[q] = 0
    for s, w, h in dropped + [({"tl": [px(L["path"][-1])[0] - 60, px(L["path"][-1])[1] - 70]}, 120, 100)]:
        x0, y0 = int(s["tl"][0] / 4) - 2, int(s["tl"][1] / 4) - 2
        x1, y1 = int((s["tl"][0] + w) / 4) + 3, int((s["tl"][1] + h) / 4) + 3
        gw[max(0, y0):max(0, y1), max(0, x0):max(0, x1)] = 0
    Image.fromarray(gw).save(os.path.join(OUT, L["glow"]))

    # build mask: Coral's water, edge and kept props; road clearance worked out again for the new road
    B = L["build"]
    step, bw, bh = B["step"], B["w"], B["h"]
    old = np.array([[ord(c) - 48 for c in row] for row in B["rows"]])
    cy, cx = np.mgrid[0:bh, 0:bw]
    cpts = np.stack([cx.ravel() * step + step / 2, cy.ravel() * step + step / 2], 1).astype(float)
    fpath = [np.array(p, float) for p in PATH]
    fpath_old = [np.array(p, float) for p in L["path"]]
    # the same clearance rule as Coral (measured at the spot and at the tower's foot): fit it to Coral's mask
    def clear(poly):
        return np.minimum(poly_dist(cpts, poly), poly_dist(cpts + [0, 12.0], poly)).reshape(bh, bw)
    dold = clear(fpath_old)
    thr = np.percentile(dold[old == 1], 99.5)
    dnew = clear(fpath)
    new = old.copy()
    new[(old == 1)] = 0
    for s, w, h in dropped:
        x0, x1 = s["tl"][0] / 0.8, (s["tl"][0] + w) / 0.8
        y0, y1 = (s["tl"][1] / 0.8 - 40) / 0.75, ((s["key"] + 4) / 0.8 - 40) / 0.75
        box = (cpts[:, 0] >= x0) & (cpts[:, 0] <= x1) & (cpts[:, 1] >= y0) & (cpts[:, 1] <= y1)
        box = box.reshape(bh, bw)
        new[box & (old == 2)] = 0
    new[(dnew < thr) & (new != 3)] = 1
    rows = ["".join(chr(48 + int(v)) for v in r) for r in new]
    print("road clearance %.1f field units; %d build cells (Coral %d)" % (thr, int((new == 0).sum()), int((old == 0).sum())))

    L2 = dict(L)
    L2["path"] = PATH
    L2["base"] = PATH[-1]
    L2["sprites"] = sprites
    L2["spr"] = CORAL_RES + "spr/"  # Coral's own props
    L2["build"] = {"step": step, "w": bw, "h": bh, "rows": rows}
    with open(os.path.join(OUT, "layout.json"), "w") as f:
        json.dump(L2, f, indent=1)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
