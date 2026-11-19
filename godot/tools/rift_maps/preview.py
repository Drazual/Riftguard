# python3 preview.py <map dir> <out.png> [scale]: the ground with every sprite laid on it, roughly as the board draws it
import json, os, sys
from PIL import Image
d = sys.argv[1]
L = json.load(open(os.path.join(d, 'layout.json')))
root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
g = Image.open(os.path.join(d, L['ground'])).convert('RGBA')
for s in L['sprites']:
    p = s['tex'].replace('res://', root + '/') if s['tex'].startswith('res://') else os.path.join(d, 'spr', s['tex'])
    im = Image.open(p).convert('RGBA')
    sc = s.get('scale', 1.0)
    if sc != 1.0:
        im = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))), Image.LANCZOS)
    g.alpha_composite(im, (int(round(s['tl'][0])), int(round(s['tl'][1])))) if s['tl'][0] >= 0 and s['tl'][1] >= 0 else g.paste(im, (int(round(s['tl'][0])), int(round(s['tl'][1]))), im)
f = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
g.resize((int(g.width * f), int(g.height * f)), Image.LANCZOS).save(sys.argv[2])
