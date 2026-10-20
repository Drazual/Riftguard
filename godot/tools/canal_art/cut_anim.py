"""Cuts the animated Canal Crossing sprites (6 frames a row) into spr/anim_*.png, with the same background
removal as the Coral Spiral sheets. Pass the folder holding plants.png, shops.png, things.png, portal.png and
water.png (they aren't in the repo)."""
import os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, '..', 'beach_art'))
from cut import cut_strip  # noqa: E402

SRC = sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/canal2'
ANIMS = {
    'palm_box': ('plants.png', 30, 335, 34, 'base', 0),
    'palm_pot': ('plants.png', 355, 585, 34, 'base', 0),
    'flowerbed': ('plants.png', 605, 740, 34, 'base', 0),
    'umbrella': ('plants.png', 760, 970, 34, 'base', 0),
    'arcade_front': ('shops.png', 60, 255, 34, 'base', 0),
    'diner_front': ('shops.png', 305, 520, 34, 'base', 0),
    'ramen_sign': ('shops.png', 585, 700, 34, 'centre', 0),
    'window': ('shops.png', 765, 960, 34, 'centre', 0),
    'fan': ('things.png', 30, 230, 34, 'base', 0),
    'lamp': ('things.png', 250, 475, 30, 'base', 0),
    'boat': ('things.png', 490, 720, 30, 'centre', 80),
    'speedboat': ('things.png', 735, 960, 30, 'centre', 80),
    'rift_gate': ('portal.png', 70, 290, 34, 'base', 0),
    'rift_ring': ('portal.png', 320, 560, 26, 'centre', 0),
    'entry': ('portal.png', 560, 760, 34, 'base', 0),
    'arrow': ('portal.png', 780, 960, 26, 'centre', 0),
}


def main():
    for name, (sheet, y0, y1, thr, anchor, core) in ANIMS.items():
        out = cut_strip(os.path.join(SRC, sheet), y0, y1, thr, anchor, core)
        out.save(os.path.join(ROOT, 'spr', 'anim_%s.png' % name))
        print(name, out.width // 6, out.height)
    # canal water: open water and the two walls, taken as they are
    wat = Image.open(os.path.join(SRC, 'water.png')).convert('RGB')
    xs = [40, 288, 537, 786, 1034, 1283]
    for name, y0 in {'open': 32, 'open2': 266, 'wall_l': 502, 'wall_r': 737}.items():
        strip = Image.new('RGB', (200 * 6, 200))
        for i, x in enumerate(xs):
            strip.paste(wat.crop((x + 4, y0 + 4, x + 204, y0 + 204)), (i * 200, 0))
        strip.save(os.path.join(ROOT, 'spr', 'anim_water_%s.png' % name))


if __name__ == '__main__':
    main()
