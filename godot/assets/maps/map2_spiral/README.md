# Map 2 — Neon Spiral (hand-painted iso map)

The second stage: the road enters from the southwest, runs a full lap of a diamond around the plaza, a second
lap inside it, and ends on the front step of the rift portal in the middle. Same format as Ocean Drive
(see `../map1_miami/README.md`); `maps/coral_spiral.tscn` points at `layout.json` here (save id `coral`).

## Files
- `ground.png`: Ocean Drive's plaza tiles with its road painted out, and the spiral road painted in (true 30° iso,
  the same road profile: far-side curb, white dashed edges, yellow centre dashes, pink tile halo).
- `glints.png`, `glow.png`: road edge glints toward the portal and the sprites' neon glow, as on Ocean Drive.
- `spr/portal.png`: Ocean Drive's portal at 80%, so the inner lap clears it.
- `layout.json`: as Ocean Drive's, plus
  - `spr`: the folder the sprites come from (Ocean Drive's `spr/`, so the edge buildings and props are shared);
    a sprite whose `tex` is a full `res://` path loads from there.
  - `hero_spawn`: where the hero starts a run (field units), open ground inside the inner lap.

## Regenerating
`python3 tools/spiral_art/build_map2.py [CY] [END_V] [END_U]` (run as `410 84 4`) rebuilds everything here from
Ocean Drive's ground and sprites: the path (in ground units, `R` outer lap half-size, `G` lap spacing,
`FIL` corner radius), the art, the kept sprites (any whose footprint is within 34 ground units of the road is
dropped, as are the portal, arch and traffic lights), and the build mask (road clearance 33 ground units at the
tower's foot, fitted to Ocean Drive's mask; Ocean Drive's edge cells kept; pockets under 60 cells dropped).
It also writes `/tmp/map2_preview.png` and `/tmp/map2_preview_mask.png`. Reopen the project to re-import.
