"""Bakes the assets for the one-768-grid pixel look (Settings > "Pixel art test").

Run from the repo root:  python3 godot/tools/pixel_art/bake_pixel.py
Needs Pillow. Writes:
  godot/data/pixel_palette.png               the shared palette (1 px per colour), used by the 3D layer
  godot/assets/maps/map1_miami/px1/          Ocean Drive at 1x (768x416): ground, glints, every sprite
  <model dir>/px/<texture>_flat.png          flat-colour albedo for the models listed in FLAT
"""
import json, os, sys
from PIL import Image, ImageFilter

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
MAPS = os.path.join(ROOT, "assets", "maps")
OD = os.path.join(MAPS, "map1_miami")
CORAL = os.path.join(MAPS, "map2_coral")
PAL_N = 64
# neon accents every map and model uses: kept even if the art samples miss them
ACCENTS = ["#5fe3f0", "#25b8d9", "#ff5fb4", "#d9338f", "#b06bff", "#7a3fd1", "#f4c95d", "#5ee08a", "#ff7a59", "#ffffff", "#101223"]
FLAT = {
    "art_src/heroes/gale_tank": ["gale_tank_Image_0.png", "gale_tank_Image_0_4.jpg"],
    "art_src/towers/arcane": ["arcane_bolt_arcane_bolt_color.png"],
    "art_src/towers/ice": ["ice_tower_ice_tower_color.png"],
}


def half(im):
    """2x -> 1x: an area average of each 2x2 block, then hard alpha (no half-see-through edge pixels)."""
    im = im.convert("RGBA")
    w, h = (im.width + 1) // 2, (im.height + 1) // 2
    # premultiply so transparent pixels don't bleed their colour into the edge
    r, g, b, a = im.split()
    pm = Image.merge("RGB", [Image.composite(c, Image.new("L", im.size, 0), a) for c in (r, g, b)])
    pm = pm.resize((w, h), Image.BOX)
    a1 = a.resize((w, h), Image.BOX)
    px, pa = pm.load(), a1.load()
    out = Image.new("RGBA", (w, h))
    po = out.load()
    for y in range(h):
        for x in range(w):
            al = pa[x, y]
            if al < 128:
                po[x, y] = (0, 0, 0, 0)
            else:
                c = px[x, y]
                po[x, y] = tuple(min(255, int(v * 255 / al)) for v in c) + (255,)
    return out


def palette():
    """The shared palette: the 768-grid Coral art plus Ocean Drive at 1x, cut to PAL_N colours, plus the accents."""
    samples = [Image.open(os.path.join(CORAL, "ground.png")).convert("RGB")]
    for f in sorted(os.listdir(os.path.join(CORAL, "spr"))):
        if f.endswith(".png"):
            im = Image.open(os.path.join(CORAL, "spr", f)).convert("RGBA")
            bg = Image.new("RGBA", im.size, (0, 0, 0, 0))
            samples.append(Image.alpha_composite(bg, im).convert("RGB").crop(im.getbbox() or (0, 0, 1, 1)))
    samples.append(half(Image.open(os.path.join(OD, "ground.png"))).convert("RGB"))
    w = max(s.width for s in samples)
    sheet = Image.new("RGB", (w, sum(s.height for s in samples)))
    y = 0
    for s in samples:
        sheet.paste(s, (0, y))
        y += s.height
    q = sheet.quantize(colors=PAL_N - len(ACCENTS), method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    flat = q.getpalette()[: (PAL_N - len(ACCENTS)) * 3]
    cols = [tuple(flat[i : i + 3]) for i in range(0, len(flat), 3)]
    cols += [tuple(int(h[i : i + 2], 16) for i in (1, 3, 5)) for h in ACCENTS]
    return cols


def pal_image(cols):
    p = Image.new("P", (1, 1))
    flat = [v for c in cols for v in c]
    p.putpalette(flat + [0] * (768 - len(flat)))
    return p


def lock(im, pimg):
    """Snaps an RGBA picture's colours to the palette, no dithering, alpha kept."""
    a = im.getchannel("A")
    rgb = im.convert("RGB").quantize(palette=pimg, dither=Image.Dither.NONE).convert("RGB")
    rgb.putalpha(a)
    return rgb


def main():
    cols = palette()
    strip = Image.new("RGB", (len(cols), 1))
    for i, c in enumerate(cols):
        strip.putpixel((i, 0), c)
    strip.save(os.path.join(ROOT, "data", "pixel_palette.png"))
    pimg = pal_image(cols)
    print("palette", len(cols))

    out = os.path.join(OD, "px1")
    os.makedirs(os.path.join(out, "spr"), exist_ok=True)
    g = lock(half(Image.open(os.path.join(OD, "ground.png"))), pimg)
    g.convert("RGB").save(os.path.join(out, "ground.png"))
    # glints hold data (line strength, 16-bit distance along the road): every other pixel, never averaged
    gl = Image.open(os.path.join(OD, "glints.png"))
    gl.resize((gl.width // 2, gl.height // 2), Image.NEAREST).save(os.path.join(out, "glints.png"))
    L = json.load(open(os.path.join(OD, "layout.json")))
    tls = {}
    par = {}
    for it in L["sprites"]:
        tex = it["tex"]
        if tex in tls:
            continue
        im = Image.open(os.path.join(OD, "spr", tex)).convert("RGBA")
        tlx, tly = it["tl"]
        # start the 1x picture on an even 2x pixel, so it lands on whole board pixels
        px, py = int(tlx) % 2, int(tly) % 2
        if px or py:
            pad = Image.new("RGBA", (im.width + px, im.height + py), (0, 0, 0, 0))
            pad.paste(im, (px, py))
            im = pad
        lock(half(im), pimg).save(os.path.join(out, "spr", tex))
        tls[tex] = [(int(tlx) - px) // 2, (int(tly) - py) // 2]
        par[tex] = (px, py)
    # the game puts a 1x sprite at floor(tl / 2): every placement of a texture must share its tl parity
    for it in L["sprites"]:
        assert (int(it["tl"][0]) % 2, int(it["tl"][1]) % 2) == par[it["tex"]], it["name"]
    print("ocean drive 1x:", len(tls), "sprites")

    for d, files in FLAT.items():
        os.makedirs(os.path.join(ROOT, d, "px"), exist_ok=True)
        for f in files:
            im = Image.open(os.path.join(ROOT, d, f)).convert("RGB")
            im = flat_hero(im) if "heroes" in d else flat_atlas(im)
            im = im.quantize(palette=pimg, dither=Image.Dither.NONE).convert("RGB")
            name = os.path.splitext(f)[0] + "_flat.png"
            im.save(os.path.join(ROOT, d, "px", name))
            print("flat", d, name)


def flat_hero(im):
    """A hero's scattered-noise albedo -> big flat blocks: the body in 2 tones with large patches, and the accent
    colour (cyan/blue) kept only where it forms big blobs, painted one clean cyan."""
    import colorsys
    small = im.resize((512, 512), Image.BOX)
    hsv = small.convert("HSV")
    h, sa, v = hsv.split()
    acc = Image.eval(Image.merge("RGB", (h, sa, v)), lambda x: x)  # placeholder for split
    hp, sp, vp = h.load(), sa.load(), v.load()
    m = Image.new("L", small.size, 0)
    mp = m.load()
    for y in range(512):
        for x in range(512):
            if 120 <= hp[x, y] <= 175 and sp[x, y] > 110 and vp[x, y] > 110:
                mp[x, y] = 255
    m = m.filter(ImageFilter.MedianFilter(9)).filter(ImageFilter.MinFilter(9)).filter(ImageFilter.MaxFilter(11))
    body = small.filter(ImageFilter.MedianFilter(21)).filter(ImageFilter.MedianFilter(21))
    body = body.quantize(colors=2, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    body.paste(Image.new("RGB", body.size, (79, 214, 236)), mask=m)
    return body


def flat_atlas(im):
    """A tower's atlas of small UV islands -> flat colours per island part, at a size that keeps the islands: 8 tones
    at full size (no blur, so the black between islands never bleeds in), a mode filter for specks, then half size.
    Near-white is pulled down a step so pale bases still stand out on light ground."""
    import numpy as np
    bg = np.asarray(im.convert("L").resize((im.width // 2, im.height // 2), Image.BOX)) < 12
    q = im.quantize(colors=8, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = q.filter(ImageFilter.ModeFilter(5)).convert("RGB")
    q = q.resize((q.width // 2, q.height // 2), Image.NEAREST)
    q = q.point(lambda v: int(v * 0.86) if v > 200 else v)
    # bleed each island's colours out over the empty black around it, so the blurrier mip levels read at a few
    # pixels a model never mix that black in (dark specks on pale towers)
    a = np.asarray(q).copy()
    empty = bg.copy()
    for _ in range(24):
        if not empty.any():
            break
        grow = np.zeros_like(empty)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            src = np.roll(np.roll(a, dy, 0), dx, 1)
            have = ~np.roll(np.roll(empty, dy, 0), dx, 1)
            take = empty & have & ~grow
            a[take] = src[take]
            grow |= take
        empty &= ~grow
    return Image.fromarray(a)


if __name__ == "__main__":
    main()
