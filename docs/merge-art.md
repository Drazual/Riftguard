# Merge models and path colours

Live 3D towers pick up path colours through an accent mask. Hybrids and super towers swap the placeholder plinth for a GLB from `art_src/towers/merges` whenever one is there. With the unified 3D style off (the default), a merge GLB draws in its own smooth render (`scripts/board/merge_3d.gd`, `Merge3D`, like the Rift Beacon and the heroes): the turret turns smoothly to any angle, `spawn` plays when it is built, then `idle` loops, and `fire` plays on each shot. Its body material is swapped for a recolour shader that follows the delivery's reference logic (the parents' masks over the atlas, a light 20% recipe tint on the plain body, glow zones replacing the baked emission). With the style test on (`Save.settings.style3d_test`), merges and base towers draw through the shared low-res layer instead (`Live3D`, `StyleRig`'s toon shader, `MergeArt.BODY`).

## Path colours

`res://data/path_colors.tres` (`PathColors`) is the one tag-to-colour map:

| Tag | Colour |
| --- | --- |
| power | `#FF4A4A` red |
| speed | `#FFD84A` yellow |
| burst | `#FF8A2E` orange |
| burn | `#FF5A1F` ember |
| slow | `#6EC8FF` icy blue |
| chain | `#3CF0FF` electric cyan |
| precision | `#E6D8FF` white-violet |
| arcane | `#FF4FC0` magenta |
| multi | `#6CF07A` green |

`PathColors.for_tower(tower)` returns three colours in the order paths were invested (`Tower.order`). Slots past the paths bought so far are the tower's own colour.

When two or more **chosen** paths share a tag, each is shifted by its index in the tower's path list (0–4), not by the order they were bought:

| Index | Shift |
| --- | --- |
| 0 | darkened 0.20 |
| 1 | darkened 0.10 |
| 2 | unchanged |
| 3 | lightened 0.12 |
| 4 | lightened 0.24 |

A single chosen path of that tag keeps the base colour. Set `color` on a `TowerPath` (alpha above 0) to replace the tag colour for that path; the shift is not applied to an override.

Fusion paths on a hybrid use the fusion's first tag and the fusion's index in the five it was given. The path buttons, their tooltip, the build tip and the tower codex show the swatch.

## Accent mask

The toon material (`scripts/style/toon_model.gdshader`) samples an optional mask. Models with no mask, and no body tint, render as they did before.

File name, next to the GLB: `<model>_accent_mask.png`. The Prism Laser's model is `prism_laser.glb`, so the mask is `prism_laser_accent_mask.png` in the same folder. UVs are the model's UV0, the same mapping as the albedo.

| Channel | Zone | What it does |
| --- | --- | --- |
| R | 1 | Main trim. Tinted with path colour 1. |
| G | 2 | Glow core. Tinted with path colour 2, and added as emission. |
| B | 3 | Small details. Tinted with path colour 3. |

Paint zones as full red, green or blue (0 or 255). Mid-greys pick up a gamma shift on import. Overlap mixes the colours. Shading, the lift and the outline stay; the zone keeps a shade of the texel so the toon light still models it.

A node may instead hold metadata `accent_mask` (a `Texture2D`). That overrides the file. The same with `accent_mask_b` for the second mask below.

Path colours are pushed onto the material when a path is bought, on the next board sync. No mask means the material is not touched.

## Merge folders

```
godot/art_src/towers/merges/<recipe key, + replaced by _>/
```

`arcane+tesla` is `merges/arcane_tesla/`. A super's key is its base types sorted, so the Rift Singularity is `merges/arcane_frost_plasma_tesla/`. The Rift Singularity's recipe colour is `#B07CFF` (void violet).

Put any `*.glb` in the folder, or name one in `tower.json` (`"model": "railgun.glb"`). `tower.json` is optional and uses the same fields as a base tower (`yaw`, `pitch`, `muzzle`, `anims`, `aim`, `wide`, `muzzle_scale`). `wide` is the same pixel width as a base turret (default 52) and is fitted with the default turret scale of 0.5.

Without `tower.json`, nodes are found by name:

| Role | Names tried, in order |
| --- | --- |
| Yaw | `Yaw`, then `Turret` |
| Pitch | `Pitch`, then `Gun`, then `Barrel` |
| Muzzle | `Muzzle`, then `BuffPoint` |
| Idle clip | `anims.idle`, else a clip named `idle` |
| Fire clip | `anims.fire`, else `fire`, else `attack` |

`MuzzleGlow` is the glow the fire clip scales, the same as on the base towers. The game owns yaw and pitch: clips that animate those nodes have those tracks removed. The model's rest pose should face the camera (+Z in the turned anchor), the same as a base turret.

### Six colours

Mask `<model>_accent_mask.png` is parent A (R/G/B = that parent's three path colours). `<model>_accent_mask_b.png` is parent B. The two zone-2 glows add, so the cores can blend where the masks overlap.

On a **hybrid**, parent A is the earlier tower id in the sorted recipe key and parent B the later one. `arcane_tesla` paints arcane on mask A and tesla on mask B, whichever tower the merge was started from. The colours are the paths those towers had invested when they merged.

On a **super with its own GLB**, parent A is the hybrid the merge was started from and parent B is the other hybrid. The colours are each hybrid's own invested paths at merge time.

The body's albedo is mixed 72% toward the recipe colour (`MergeArt.BODY`). Accent zones are applied after that, so trim stays the path colours.

### Super without its own model

If `merges/<super key>/` has no GLB, the super reuses the model of the hybrid the merge was started from (the super's `type`), at 1.15× scale, with that hybrid's parent colours still on the masks. The orbiting parent-colour dots and the signature charge ring stay. A super with its own GLB does not draw the dots or the placeholder core; the charge ring remains.

No GLB at all: the old plinth, circle or core, and the orbiting dots.

## Adding a merge model

1. Build the mesh with `Turret`, `Gun` or `Barrel`, `Muzzle`, and optionally `MuzzleGlow` and `BuffPoint`. Add `idle` and `fire` (or `attack`) clips if it should animate.
2. Create `godot/art_src/towers/merges/<sorted_key>/` and drop in the `.glb`.
3. Paint `<glb name>_accent_mask.png` and `<glb name>_accent_mask_b.png` as above.
4. Optional `tower.json` when the node paths differ from the names above, or to set `wide` / `aim`.
5. The game picks the file up on the next merge. Nothing in the tower data has to point at it. Delete the GLB to fall back to the plinth.
