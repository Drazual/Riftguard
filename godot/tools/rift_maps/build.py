# python3 build.py [map ...] [--ascii]   (needs numpy and Pillow). With no map names it builds them all, and the
# void prop set into assets/maps/rift_props first.
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapgen, voidprops
from maps import MAPS

args = [a for a in sys.argv[1:] if not a.startswith('--')]
names = args or list(MAPS)
if '--ascii' in sys.argv:
    for n in names:
        print('==', n); print(mapgen.ascii_map(MAPS[n]))
    sys.exit()
if not args or '--props' in sys.argv:
    voidprops.build(mapgen.PROPS_DIR)
for n in names:
    cfg = MAPS[n]
    print(n, mapgen.build(cfg, os.path.join(mapgen.MAPS, cfg['out'])))
