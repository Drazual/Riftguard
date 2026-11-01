"""Placeholder art for the split-layer Striker (body + rotating gun). Run from godot/:
    python3 tools/striker_split/split.py

- assets/heroes/striker_body.png: striker.png with the gun erased from every frame, same layout.
  The gun is found by colour (cool greys, slate, cyan and their outline) along the line from the chest
  to the old gun tip of each facing. On the back facings the hair is as dark as the gun, so a disc
  around the head is kept. It is rough: a few stray pixels and the old hands stay. Final art replaces it.
- assets/heroes/striker_gun.png: a hand-pixelled gun with two hands and a sleeve, pointing right.
  The gun pivots at its back end (HeroData.gun_pivot) and bullets leave its tip (HeroData.gun_tip).
"""
import math
from PIL import Image

SRC = "assets/heroes/striker.png"
# old gun tips per facing (N, NE, E, SE, S, SW, W, NW), pixels of a 64px frame: HeroData.muzzle
TIP = [(31.7, 26.1), (42.5, 30.2), (50.7, 41), (48.8, 43.6), (31.9, 52.1), (14.2, 43.6), (12.5, 40.8), (20.6, 30.3)]
CHEST = (32, 40)
HEAD = {0: (29, 28), 1: (29, 26), 7: (35, 26)}


def gunish(r, g, b):
	if r > g + 14 or r > b + 45:
		return False  # warm: skin, jacket, bandana
	if g < 0.45 * b and r < 60:
		return False  # navy jeans
	return True


def seg_d(p, a, b):
	dx, dy = b[0] - a[0], b[1] - a[1]
	t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / (dx * dx + dy * dy)))
	return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dy))


def body():
	im = Image.open(SRC).convert("RGBA")
	src = im.load()
	out = im.copy()
	px = out.load()
	for col in range(8):
		m = TIP[col]
		end = (m[0] + (m[0] - CHEST[0]) * 0.1, m[1] + (m[1] - CHEST[1]) * 0.1)
		for row in range(im.size[1] // 64):
			ox, oy = col * 64, row * 64
			for y in range(64):
				for x in range(64):
					r, g, b, a = src[ox + x, oy + y]
					if a < 100 or seg_d((x, y), CHEST, end) > 4.5 or not gunish(r, g, b):
						continue
					if col in HEAD and r + g + b < 230 and math.hypot(x - HEAD[col][0], y - HEAD[col][1]) < 6:
						continue
					px[ox + x, oy + y] = (0, 0, 0, 0)
			# sweep up specks and loose outline left along the gun's path
			for _ in range(3):
				gone = []
				for y in range(64):
					for x in range(64):
						if px[ox + x, oy + y][3] < 100 or seg_d((x, y), CHEST, m) > 6:
							continue
						n = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
							if (dx or dy) and 0 <= x + dx < 64 and 0 <= y + dy < 64 and px[ox + x + dx, oy + y + dy][3] >= 100)
						if n <= 2:
							gone.append((x, y))
				for x, y in gone:
					px[ox + x, oy + y] = (0, 0, 0, 0)
	out.save("assets/heroes/striker_body.png")


GUN = [
	"..........kk...........",
	"..kkkkkkkkllkkkkkkk....",
	".kpplllssssllsssssskkk.",
	"kpPPkssssssssddddcccck.",
	"kpPokkdddkkokkkkkkkkk..",
	".koOk.kdk.kOok.........",
	"..kk..kdk..kk..........",
	"......kk...............",
]
PAL = {"k": (12, 22, 40), "d": (73, 101, 109), "s": (137, 179, 183), "l": (208, 210, 182), "c": (0, 170, 194),
	"o": (255, 156, 74), "O": (196, 96, 52), "p": (240, 2, 104), "P": (150, 0, 66)}


def gun():
	im = Image.new("RGBA", (len(GUN[0]), len(GUN)))
	for y, r in enumerate(GUN):
		for x, ch in enumerate(r):
			if ch in PAL:
				im.putpixel((x, y), PAL[ch] + (255,))
	im.save("assets/heroes/striker_gun.png")


body()
gun()
