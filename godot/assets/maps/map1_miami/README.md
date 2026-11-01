# Map 1 — Ocean Drive (hand-painted iso map)

A pre-rendered 3/4-view Miami map. `maps/ocean_drive.tscn` points `MapScene.art_layout` at `layout.json`;
everything else (path, build pads, sprites) comes from that file, so the scene has no Ground/Props tiles.

## Files
- `ground.png` — the ground and road, 1536x832 (the board's 768x416 art at `art_scale` 2).
- `spr/*.png` — every building, palm, sign, pad, the arch and the portal as its own sprite.
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
| `pads` | build pads: `centre` (the pad on the ground) and `tower` (where a tower stands), field units |
| `hero` | hero start, field units |
| `sprites` | `{tex, tl, key, kind, name}`: `tl` = top-left, `key` = the y the sprite sorts at (its ground line). `kind`: `pad` (drawn flat on the ground, pulses on its own beat, `pad` = index), `palm` (sways), `portal` (`ring` = swirl centre), `neon`, `tlight`, `arch`, `bld`, `prop` |

Buildings, props, towers, enemies and the hero all sit in the board's y-sorted `units` layer, so units walk
behind and in front of the art correctly. The arch is cut in two (`arch_iso_a`/`_b`) so enemies pass
behind its front pillar.

## In game
- A pad is the cell `(index, MapInfo.SPOT_ROW)`, so towers, merges and saves still key on a cell.
  Clicking a pad (or a tower standing on it) selects it; anywhere else says "Build towers on the glowing pads."
- Walls and spells snap to the nearest point of the road instead of a path tile.
- The board renders this map at 2x (1536x832) and scales it to the screen smoothly; tile maps keep 768x416.

## Regenerating
The art was composed from the iso tile sheet by the map mockup scripts (`compose11.py`) and exported with
`export_godot.py <out dir>` (both kept outside the repo with the source sheets). Re-export, copy the output
over this folder, and reopen the project so Godot re-imports it.
