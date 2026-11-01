"""Builds the Striker's split-layer art from the Neon Striker sheets in src/. Run from godot/:
    python3 tools/striker_split/neon.py

src/neon_body.png: 5 rows (S, SE, E, NE, N) by 12 frames (1-4 idle, 5-12 walk), about 160px cells.
src/neon_weapon.png: the gun pointing right on top; below it three muzzle-flash frames, a fade, and the bullet.

Writes, at the game's pixel scale:
- assets/heroes/striker_body.png: 64px frames, one column per facing (N, NE, E, SE, S, SW, W, NW; the west side is the
  east side mirrored), rows 0-3 idle and 4-11 walk, feet on row 59, centred on the torso.
- assets/heroes/striker_gun.png: the gun, pointing right. Prints its pivot (back of the sleeve) and tip (end of the barrel).
- assets/heroes/striker_gun_fx.png: 32px cells, frames 0-3 the muzzle flash (star centred in the cell), 4 the bullet.
"""
import numpy as np
from PIL import Image

BODY_SCALE = 0.25
GUN_LEN = 28  # px from the back of the sleeve to the muzzle
FX_SCALE = 0.05
SRC_ROW = {4: 0, 3: 1, 2: 2, 1: 3, 0: 4}  # facing -> source row
MIRROR = {5: 3, 6: 2, 7: 1}


def load(p):
	a = np.array(Image.open(p).convert("RGBA")).astype(np.float64)
	on = a[:, :, 3] >= 128
	a[:, :, 3] = np.where(on, 255, 0)
	a[~on, :3] = 0
	return a


def runs(v):
	r, s = [], None
	for i, x in enumerate(v):
		if x and s is None:
			s = i
		if not x and s is not None:
			r.append((s, i))
			s = None
	if s is not None:
		r.append((s, len(v)))
	return r


def shrink(a, scale):
	"""Box-filter downscale on premultiplied colour, then a hard alpha edge, like hand-placed pixels."""
	h, w = a.shape[:2]
	im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
	nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
	pre = a.copy()
	pre[:, :, :3] *= pre[:, :, 3:4] / 255
	small = np.array(Image.fromarray(np.clip(pre, 0, 255).astype(np.uint8), "RGBA").resize((nw, nh), Image.BOX)).astype(np.float64)
	al = small[:, :, 3]
	on = al >= 110
	out = np.zeros_like(small)
	out[on, :3] = np.clip(small[on, :3] * 255 / np.maximum(al[on, None], 1), 0, 255)
	out[on, 3] = 255
	return out


def to_img(a):
	return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def body():
	a = load("tools/striker_split/src/neon_body.png")
	on = a[:, :, 3] > 0
	rows = [r for r in runs(on.any(1)) if r[1] - r[0] > 40]
	cols = [c for c in runs(on.any(0)) if c[1] - c[0] > 40]
	assert len(rows) == 5 and len(cols) == 12, (rows, cols)
	sheet = Image.new("RGBA", (64 * 8, 64 * 12))
	for face, sr in SRC_ROW.items():
		y0, y1 = rows[sr]
		for f, (x0, x1) in enumerate(cols):
			cell = a[max(0, y0 - 4):y1 + 4, max(0, x0 - 4):x1 + 4]
			s = shrink(cell, BODY_SCALE)
			al = s[:, :, 3] > 0
			ys, xs = np.nonzero(al)
			bottom = ys.max()
			top = ys.min()
			# centre on the torso (the band from shoulders to hips), not the legs or bandana tails
			band = al[top + (bottom - top) * 35 // 100:top + (bottom - top) * 65 // 100]
			bx = np.nonzero(band.any(0))[0]
			cx = (bx.min() + bx.max() + 1) / 2
			im = to_img(s)
			ox = int(round(32 - cx))
			oy = 59 - bottom
			frame = Image.new("RGBA", (64, 64))
			frame.alpha_composite(im, (max(0, ox), max(0, oy)), (max(0, -ox), max(0, -oy)))
			sheet.alpha_composite(frame, (face * 64, f * 64))
	for face, src in MIRROR.items():
		col = sheet.crop((src * 64, 0, src * 64 + 64, 64 * 12)).transpose(Image.FLIP_LEFT_RIGHT)
		sheet.paste(col, (face * 64, 0))
	sheet.save("assets/heroes/striker_body.png")


def gun():
	a = load("tools/striker_split/src/neon_weapon.png")
	on = a[:, :, 3] > 0
	rows = [r for r in runs(on.any(1)) if r[1] - r[0] > 40]
	gy0, gy1 = rows[0]
	g = a[gy0:gy1]
	gx = np.nonzero((g[:, :, 3] > 0).any(0))[0]
	g = g[:, gx.min():gx.max() + 1]
	gon = g[:, :, 3] > 0
	# the barrel: the rightmost tenth of the gun; its middle row is the line the bullets fly along
	w = g.shape[1]
	tip_rows = np.nonzero(gon[:, w - max(3, w // 40):].any(1))[0]
	tip_y = (tip_rows.min() + tip_rows.max() + 1) / 2
	# the sleeve: the leftmost tenth; the gun turns around its middle
	back_rows = np.nonzero(gon[:, :max(3, w // 12)].any(1))[0]
	back_y = (back_rows.min() + back_rows.max() + 1) / 2
	scale = GUN_LEN / w
	s = shrink(g, scale)
	to_img(s).save("assets/heroes/striker_gun.png")
	print("gun", s.shape[1], "x", s.shape[0], "pivot", (0.5, round(back_y * scale, 1)), "tip", (round(w * scale, 1), round(tip_y * scale, 1)))
	# the effects row: flash frames and the bullet, left to right
	fy0, fy1 = rows[1]
	fx = a[fy0:fy1]
	parts = []
	for c in runs((fx[:, :, 3] > 0).any(0)):  # merge pieces closer than 40px (the fade is loose specks)
		if parts and c[0] - parts[-1][1] < 40:
			parts[-1] = (parts[-1][0], c[1])
		else:
			parts.append(c)
	cells = Image.new("RGBA", (32 * 5, 32))
	for i, (x0, x1) in enumerate(parts[:5]):
		p = fx[:, x0:x1]
		bright = p[:, :, :3].sum(2) * (p[:, :, 3] > 0)
		if i < 4 and bright.max() > 600:
			ys, xs = np.nonzero(bright >= bright.max() * 0.9)  # the white core of the star
			cy, cx = ys.mean(), xs.mean()
		else:
			ys, xs = np.nonzero(p[:, :, 3] > 0)
			cy, cx = (ys.min() + ys.max()) / 2, (xs.min() + xs.max()) / 2
		s = shrink(p, FX_SCALE)
		im = to_img(s)
		ox = int(round(16 - cx * FX_SCALE))
		oy = int(round(16 - cy * FX_SCALE))
		cell = Image.new("RGBA", (32, 32))
		cell.alpha_composite(im, (max(0, ox), max(0, oy)), (max(0, -ox), max(0, -oy)))
		cells.alpha_composite(cell, (i * 32, 0))
	cells.save("assets/heroes/striker_gun_fx.png")


def frames_tres(path, uid, tex, tex_uid, anims):
	"""Writes a SpriteFrames resource. anims: (name, [Rect2 tuples], loop, fps)."""
	subs, out = [], []
	n = 0
	for name, rects, loop, fps in anims:
		ids = []
		for r in rects:
			n += 1
			ids.append("AtlasTexture_%d" % n)
			subs.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("1_tex")\nregion = Rect2(%d, %d, %d, %d)\n' % ((ids[-1],) + r))
		fr = ",\n".join('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % i for i in ids)
		out.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", name, fps))
	with open(path, "w") as f:
		f.write('[gd_resource type="SpriteFrames" format=3 uid="uid://%s"]\n\n' % uid)
		f.write('[ext_resource type="Texture2D" uid="uid://%s" path="%s" id="1_tex"]\n\n' % (tex_uid, tex))
		f.write("\n".join(subs))
		f.write("\n[resource]\nanimations = [%s]\n" % ", ".join(out))


body()
gun()
anims = []
for face in range(8):
	anims.append(("idle_%d" % face, [(face * 64, r * 64, 64, 64) for r in range(4)], True, 5.0))
	anims.append(("walk_%d" % face, [(face * 64, r * 64, 64, 64) for r in range(4, 12)], True, 12.0))
frames_tres("art/heroes/striker_body.tres", "cs3bodyk4fr2m", "res://assets/heroes/striker_body.png", "3qyjxf8pgy6uh", anims)
frames_tres("art/heroes/striker_gun_fx.tres", "dgunfx7k2m4qa", "res://assets/heroes/striker_gun_fx.png", "egunfx3p8r1tb", [
	("flash", [(i * 32, 0, 32, 32) for i in range(4)], False, 30.0),
	("bullet", [(128, 0, 32, 32)], True, 1.0),
])
