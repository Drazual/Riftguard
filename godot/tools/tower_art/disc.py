"""Draws the Razor Disc's sheet (6x4 frames of 48px, like the other towers): idle with the disc spinning in its
cradle, the throw, the reload and the hit sparks. Run: python3 tools/tower_art/disc.py"""
import math, os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, '..', '..', 'assets', 'towers', 'disc.png')
INK = (26, 18, 38, 255)
BASE_D = (44, 32, 64, 255)
BASE_M = (72, 54, 102, 255)
BASE_L = (118, 92, 160, 255)
GOLD = (242, 193, 78, 255)
GOLD_L = (255, 226, 140, 255)
STEEL_D = (96, 132, 158, 255)
STEEL = (170, 206, 226, 255)
STEEL_L = (232, 246, 255, 255)
CYAN = (79, 216, 232, 255)
PINK = (255, 111, 216, 255)
F = 48


def base(d):
    # an octagonal plinth seen from above, front face below
    top = [(10, 30), (16, 26), (32, 26), (38, 30), (38, 34), (32, 38), (16, 38), (10, 34)]
    front = [(10, 34), (16, 38), (32, 38), (38, 34), (38, 39), (32, 43), (16, 43), (10, 39)]
    d.polygon(front, fill=BASE_D, outline=INK)
    d.polygon(top, fill=BASE_M, outline=INK)
    d.line([(16, 27), (31, 27)], fill=BASE_L)
    for x in (13, 35):
        d.point((x, 37), fill=GOLD)
    d.line([(18, 40), (30, 40)], fill=GOLD)


def cradle(d, pull=0):
    # two arms that hold the disc, pulled back a little while winding up
    y = 25 + pull
    d.polygon([(13, 31), (15, y - 6), (18, y - 7), (19, 31)], fill=BASE_L, outline=INK)
    d.polygon([(29, 31), (30, y - 7), (33, y - 6), (35, 31)], fill=BASE_L, outline=INK)
    d.point((16, y - 5), fill=GOLD_L)
    d.point((32, y - 5), fill=GOLD_L)


def disc(d, cx, cy, rx, ry, ang, glow=0.0, alpha=255):
    def c(col):
        return col[:3] + (alpha,)
    # teeth: little wedges around the rim, turning with the spin
    n = 8
    for i in range(n):
        a = ang + i * math.tau / n
        a2 = a + 0.45
        p0 = (cx + math.cos(a) * (rx - 1), cy + math.sin(a) * (ry - 1))
        p1 = (cx + math.cos(a) * (rx + 3), cy + math.sin(a) * (ry + 2))
        p2 = (cx + math.cos(a2) * (rx - 1), cy + math.sin(a2) * (ry - 1))
        d.polygon([p0, p1, p2], fill=c(STEEL_L if i % 2 else GOLD_L))
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=c(STEEL), outline=c(CYAN if glow > 0.3 else INK))
    d.ellipse([cx - rx + 2, cy - ry + 1, cx + rx - 2, cy + ry - 1], outline=c(STEEL_D))
    # a light glint that sweeps around as it spins
    gx = cx + math.cos(ang * 2) * (rx - 3)
    gy = cy + math.sin(ang * 2) * (ry - 2)
    d.point((round(gx), round(gy)), fill=c(STEEL_L))
    d.ellipse([cx - 2, cy - 1, cx + 2, cy + 1], fill=c(PINK if glow > 0.5 else GOLD), outline=c(INK))


def frame(kind, i):
    im = Image.new('RGBA', (F, F), (0, 0, 0, 0))
    d = ImageDraw.Draw(im, 'RGBA')
    if kind == 'fx':
        if i == 0:
            disc(d, 24, 24, 9, 6, 0.4)
        else:
            k = i / 5
            r = 4 + 14 * k
            a = int(255 * (1 - k * 0.8))
            for j in range(8):
                ang = j * math.tau / 8 + k
                x0, y0 = 24 + math.cos(ang) * r * 0.4, 24 + math.sin(ang) * r * 0.3
                x1, y1 = 24 + math.cos(ang) * r, 24 + math.sin(ang) * r * 0.7
                d.line([(x0, y0), (x1, y1)], fill=(STEEL_L if j % 2 else CYAN)[:3] + (a,), width=1)
            if i < 3:
                d.ellipse([20, 21, 28, 27], fill=STEEL_L[:3] + (int(200 * (1 - k)),))
        return im
    base(d)
    if kind == 'idle':
        cradle(d)
        disc(d, 24, 20 + (1 if i in (2, 3) else 0), 9, 6, i * math.tau / 24, glow=0.25 if i in (2, 3) else 0.0)
    elif kind == 'attack':
        pull = [1, 2, 2, 0, 0, 0][i]
        cradle(d, pull)
        if i < 3:
            disc(d, 24, 20 + pull, 9, 6, i * 0.9, glow=0.4 + 0.3 * i)
        elif i == 3:
            d.ellipse([14, 10, 34, 24], fill=CYAN[:3] + (150,))
            d.ellipse([19, 13, 29, 20], fill=STEEL_L[:3] + (230,))
        elif i == 4:
            d.ellipse([18, 13, 30, 21], fill=CYAN[:3] + (70,))
    else:  # recover: the next disc slides up into the cradle
        cradle(d)
        if i >= 1:
            k = min(1.0, i / 4)
            disc(d, 24, round(26 - 6 * k), 9, 6, i * 0.5, alpha=int(90 + 165 * k))
    return im


def main():
    sheet = Image.new('RGBA', (F * 6, F * 4), (0, 0, 0, 0))
    for row, kind in enumerate(['idle', 'attack', 'recover', 'fx']):
        for i in range(6):
            sheet.alpha_composite(frame(kind, i), (i * F, row * F))
    sheet.save(OUT)


if __name__ == '__main__':
    main()
