# Map 1 — Ocean Drive (hand-painted iso map)

A pre-rendered 3/4-view Miami map. `maps/ocean_drive.tscn` points `MapScene.art_layout` at `layout.json`;
everything else (path, build mask, sprites) comes from that file, so the scene has no Ground/Props tiles.

## Files
- `ground.png` — the ground and road, 1536x832 (the board's 768x416 art at `art_scale` 2).
- `spr/*.png` — every building, palm, sign, the arch and the portal as its own sprite.
- `glow.png` — the soft neon glow (quarter res), added over the sprites and pulsing slowly.
- `glints.png` — road edge lines: red = line strength, green/blue = distance along the road (16 bit).
  `map_glints.gdshader` runs packets of pink light along them toward the portal.
- `layout.json` — the data below.

## layout.json
All `tl`/`key`/`ring` values are in art pixels (the 1536x832 image); field units are the game's
(x across 0..960, y down 0..~500; the board shows a field point at `(x, 40 + 0.75*y)`).

| key | meaning |
| --- | --- |
| `art_scale` | art pixels per base board pixel (2) |
| `ground`, `glow`, `glints` | file names in this folder |
| `period` | seconds per neon pulse / sway / glint cycle |
| `path` | enemy path as field points, from off-screen to the portal (the base) |
| `build` | where towers may stand: a grid of `step` (4) field units, `w`x`h` (240x150) cells, `rows` = one digit string per row. Codes: `0` build, `1` road (the road plus a curb margin), `2` object (portal, arch, traffic lights), `3` edge (buildings and the props beside them, the screen border, small cut-off pockets). Looked up at a tower's foot (12 field units below its position) |
| `hero` | hero start, field units |
| `sprites` | `{tex, tl, key, kind, name}`: `tl` = top-left, `key` = the y the sprite sorts at (its ground line). `kind`: `palm` (sways), `portal` (`ring` = swirl centre, `ring_r` = the ring's half-width/half-height in mockup pixels, so the swirl follows the upright oval of a side-on portal), `neon`, `tlight`, `arch`, `bld`, `prop` |

Buildings, props, towers, enemies and the hero all sit in the board's y-sorted `units` layer, so units walk
behind and in front of the art correctly. The arch is cut in two (`arch_iso_a`/`_b`) so enemies pass
behind its front pillar.

## Layout rules
- The portal faces the last road leg (down-left on screen): its stairs run along that leg and the road ends
  on the bottom step's front edge.
- The inside of the road loop is empty open ground, so towers can go anywhere in it. Street props, decor and
  traffic lights only stand outside the loop, next to the buildings.
- Edge buildings mix 11 types (the 5 from the tile sheet plus motel, diner, record store, apartments,
  nightclub and palm hotel). No type repeats within 4 cells, the neon trim is recoloured pink, teal, violet or
  coral, and size and setback vary a little per lot.

## In game
- There are no pads: towers go anywhere the `build` mask says `0`, at least 36 field units (`Game.TOWER_GAP`)
  from another tower. A tower's cell is the 4-unit mask cell under its foot, so towers, merges and saves still
  key on a cell. Refusals say why: too close to the road, something in the way, the edge of the city, or too
  close to another tower.
- In build mode the board washes the buildable ground faint green and shows the tower as a ghost at the
  pointer: green when it fits and is in reach, gold when it fits but the hero has to walk over, red when it
  doesn't fit. Clicking out of reach still walks the hero over to build it.
- `tests/placement.tscn -- canal` checks the rules: open middle allowed; road, curb, buildings, the four
  edges, the portal/arch and overlapping towers refused; hero walk-to-build.
- Walls and spells snap to the nearest point of the road instead of a path tile.
- The board renders this map at 2x (1536x832) and scales it to the screen smoothly; tile maps keep 768x416.

## Regenerating
The art was composed from the iso tile sheet by the map mockup scripts (`compose13.py`, which builds on
`compose12.py`/`compose11.py`; `cut12.py` keys the generated portal and building sprites) and exported with
`export13.py`, which runs `buildmask13.py` for the `build` mask (all kept outside the repo with the source
sheets). Mask settings: road clearance `ROAD_CLR` 0.56 iso cells from the centre line, 0.32 cells around
buildings and decor, 0.42 around props, a screen border of 70 px at the sides, 150 at the top and 40 at the
bottom (mockup pixels), and pockets under 60 cells dropped. Re-export, copy the output
over this folder, and reopen the project so Godot re-imports it.
