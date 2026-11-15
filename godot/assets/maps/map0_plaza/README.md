# Map 0: Rift Plaza (the first stage)

A city square seen at Ocean Drive's isometric angle. The road comes in under the arch on the left, runs round the
square and spirals in to the rift portal in the middle. Same format as `map1_miami` (see its README); everything here is
made by `src/gen.py` (`python3 src/gen.py .` from this folder, needs numpy and Pillow).

## Tower grid
- The square is 15 x 15 diamond tiles (48 x 27.7 board px each). Each tile of the inner 13 x 13 that isn't road or
  portal is one tower spot (88 of them). The road runs along tile rows, so towers line up with it.
- `layout.json` has a `snap` key: `origin`, `a` and `b` in field units. A tower's foot snaps to the nearest
  `origin + i*a + j*b` (`MapInfo.snap_lattice`, `Game.snap_cell`), and build mode outlines the free diamonds. Spots are
  37.9 field units apart, just over `Game.TOWER_GAP`.
- The `build` mask (4-unit cells, looked up 12 units below where a tower stands, like map1) is 0 on tower tiles,
  1 on road tiles, 2 under the portal and arch, and 3 everywhere else.

## Art
- `ground.png`: Coral Spiral's road (navy, pink neon edges, cyan dashes and arrows) and one peach diamond per tower
  spot, inside a pink curb; rose sidewalk outside. Painted at 768 x 416 and scaled 2x without smoothing.
- `sprites`: all Ocean Drive's (`res://assets/maps/map1_miami/spr/`, nothing copied). Buildings stand on 2 x 2 tile
  blocks outside the square, with the odd little park; flower beds, palms, lamps and signs fill the single tiles and
  the square's rim. The portal and arch sit at the same offsets from the road as on Ocean Drive.
- `glow.png`: the sprites' neon plus a faint road edge. `glints.png`: the road's edge lines with the distance along it.
