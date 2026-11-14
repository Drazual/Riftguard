# Map 2: Coral Spiral (isometric rebuild, phase 1 final)

Coral Spiral's beach look (palette, pink-edged road with cyan arrows, tiled plaza, sand rim, foamy water, SURF / DINER /
ARCADE shops, ENTRY gate, lifeguard tower, AQUA dome, palms, umbrellas, lamps, boats) drawn at Ocean Drive's isometric angle.
It uses the same format as `map1_miami` (Ocean Drive): `MapScene.art_layout` points at `layout.json`.

## Files
- `layout.json`: the layout (keys below).
- `ground.png` and `ground_1..5.png`: the ground and water frames. They are baked with the boats, jetskis, buoys and
  dock, which bob 1 px between frames. The game eases between frames like Coral's backdrop did (`frames_span` 2,
  `frames_period` 7 s).
- `glints.png`: road edge lines for `map_glints.gdshader`. Red is the line strength; green/blue hold the 16-bit
  distance along the road.
- `glow.png`: quarter-res additive glow, blurred from the finished board. It covers the road neon, the sign letters,
  the lamp lights and the core.
- `spr/*.png`: one sprite per building or prop, at 1× board pixels.

## Layout keys
- `art_scale` 1, `size` [768, 416], `pixel` true. Everything is in board pixels, so F = 1 and `_filter()` already
  picks NEAREST. `pixel` is informational.
- `ground_frames`, `frames_span`, `frames_period`: NEW, the animated ground.
- `glow`, `glints`, `period`: same as map1.
- `path`: 13 points in field units. The road starts off-board at the top-left, crosses the pier and the ENTRY gate,
  spirals clockwise, and ends at the core. Its length is 2729 field units; Coral's is 2760, so it is 1.1% shorter.
- `build`: a 240×150 mask, 4 field units per cell. Codes match map1: 0 build, 1 road, 2 object, 3 water or edge.
  - Code 1 covers the iso clearance of 0.85 cells. It also covers anything within 17.5 field units of the road, measured
    at the spot or at the tower's foot (FOOT_DY 12), which keeps placement.gd's curb rule true.
  - Legal 40-grid tower spots: 184. Coral has 187.
- `sprites`: each has `tex`, `tl` (top-left) and `key` (ground line), in board px, plus `kind` and `name`. They are
  y-sorted in `units` exactly like map1.
  - Kinds are `palm` (13, they use the existing sway), `prop`, `bld`, `arch` and `core`.
  - The `arch` kind is the ENTRY gate, split in two. `gate_back` holds the back post, the bar and the sign, keyed on
    the far side of the road. `gate_front` is the front post, keyed on the near side. Enemies walk between the two.
  - `core` is the base sprite at the path end. It carries `ring` / `ring_r`, the swirl centre and radii, in case the
    code wants the portal swirl on it. It works fine as a plain sprite.
- `hero`: in field units. Its mask code is 0.
- `base`: the path end. MapInfo already uses the last path point, so this key is informational.
- `light`: a SUGGESTED MapLight profile (floor #2B2549, tint #F8D9CF at 0.05, mauve shadow).
- `iso`: notes on the camera.

## Camera
The camera is orthographic true isometric: tilt 35.264°, yaw 45°. Ground lines run at a slope of 0.577; Ocean Drive's
road measures 0.566–0.581. One ground cell is 40×23 board px, and 1 cell of height is 23.1 px.

## Source
The source lives on the build box in `maps/map2_coral/src`. Run `run_all.sh` to rebuild:
- `geo.py`: the projection, the path and the prop list.
- `props_blender.py`: Blender 4.2 Cycles with a toon emission shader.
- `sprites.py`: renders at 4×, scales to 1× with the Coral palette and outlines, and adds the pixel-font sign text.
- `ground.py`: the ground and water frames.
- `mask.py`, `glow.py`, `layout.py`.
- `checks.py` and `sim_placement.py`: path, spots and curb checks.
