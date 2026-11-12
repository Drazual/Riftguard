# Cryo Coil v2 merge tower (Frost Pylon + Tesla Coil): integration notes for Claude

The recipe is `frost` + `tesla` → **Cryo Coil**, with recipe color `#9AF0FF`. This is v2. The top is the real Frost Pylon crown, from `ice_tower.glb` scaled 1.38×: the crystal spire in its frame, the cross-shaped crystal arms with icicles, and the finial. It sits on a Tesla coil column (copper winding), with a small floating cryo-core orb on top. The electric effects (arcs, coil glow, upward bolt) and the ice effects (orbiting shards, frost nova, glowing crystals) are kept from v1. v1 had a toroid top and was rejected; it's kept in `final_v1/`.

## Where it goes
Copy everything to **`godot/art_src/towers/merges/frost_tesla/`**:
```
cryo_coil.glb                 game asset (Y-up, meters, 2048 atlas embedded, 3 clips)
cryo_coil.glb.import          import settings. Keep it next to the glb.
cryo_coil_accent_mask.png     parent A (Frost) accent mask, same UV as the atlas
cryo_coil_accent_mask_b.png   parent B (Tesla) accent mask
textures/cryo_coil_{color,normal,orm,emission}.png   loose copies of the embedded atlas
tower.json                    descriptor (field names match live_3d.gd / docs/merge-art.md)
```
If the v1 `cryo_coil.glb` was ever imported, **first delete the extracted `cryo_coil_cryo_coil_{color,normal,orm,emission}.png` files (and their `.import`) next to it, plus `.godot/imported/cryo_coil*`**. Godot doesn't overwrite textures it has already extracted, and v2 has a completely different UV layout, so a stale v1 atlas would look scrambled. The masks are separate PNGs (Lossless import, verified) and `MergeArt.load_mask()` finds them by name.

## Node tree (Godot names)
```
CryoCoil (root)                         origin = bottom center of the plinth, front = +Z (crown is 4-fold symmetric)
├─ Base            MeshInstance3D  static  low plinth (top 0.30 m), 4 frost crystal clusters, coolant pipes, vents (5.4k tris)
│  ├─ Column       MeshInstance3D  Tesla coil: core, copper winding, rails, glow windows, collars, insulators, seat ring (6.8k). Origin at its foot y=0.30
│  ├─ Crown        MeshInstance3D  Frost Pylon crown + cryo-core orb (6.9k). Origin y=1.05; spans y 1.05 → 2.24, arms Ø 1.43 m
│  │  ├─ TipGlow   FX halo around the orb (breathes)
│  │  └─ Muzzle    Node3D  at the orb, global (0, 2.182, 0), identity rotation
│  │     ├─ MuzzleGlow   FX orb glow (soft idle, builds on fire)
│  │     ├─ MuzzleFlash  FX star (hidden at rest)
│  │     └─ Bolt         FX 0.9 m jagged lightning bolt shooting UP from the orb (hidden at rest)
│  ├─ FrostShards  MeshInstance3D  6 ice shards orbiting the coil, y=0.66
│  ├─ Arc0..3      FX lightning from under the crown down to each corner crystal cluster (hidden at rest)
│  └─ FrostNova    FX frost burst ring at crown-arm height y=1.70 (hidden at rest)
├─ BuffPoint       Node3D  (0, 2.337, 0)  10 cm above the orb
└─ AnimationPlayer
```

### No aiming (like the base Tesla Coil)
- `tower.json` has `"yaw": "-"` and `"pitch": "-"`. `LiveTower._fill_cfg()` only fills in empty values, and `get_node_or_null("-")` returns null, so nothing turns.
- As a second safety net, the GLB has **no** node named Yaw, Turret, Pitch, Gun or Barrel (verified). Even with no `tower.json`, the loader's name fallbacks find nothing to turn.
- `"muzzle": "Muzzle"` is a **node name**, because `live_3d.gd` resolves it with `find_child()` (verified: it finds `Base/Crown/Muzzle`). Shots and chain lightning start at `muzzle.global_position`; the game picks the direction. The fire clip's bolt goes straight up, like the Tesla Coil's.

## Proportions
- Height **2.24 m** (top of the orb). The plinth top is at 0.30 m (**13%**). The coil column runs 0.30 → 1.10 m, with a Ø 0.38 m core and copper winding at r 0.23 m. The crown runs 1.05 → 2.24 m.
- Plinth footprint 1.04 × 1.04 m. Across the crown's arms it's **1.43 m**, so the top is the widest part. Parents: Frost Pylon 1.90 m tall / 1.20 m wide, Tesla Coil 1.90 m / 1.42 m. Suggested `"wide": 62` is close to tesla's 60, and `_fit()` scales by the x-extent, which here is the crown arms.

## Clips (60 fps)
| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | The FrostShards orbit 60° per loop (6-fold symmetric, so it loops seamlessly) and bob ±2.5 cm. The tip glow breathes ±8% and the orb glows softly. The 4 crown→crystal arcs flicker at t = 0.6 s, 1.5 s, 2.4 s and 3.3 s. |
| `fire` | 0.6 s | no | 0–0.20 s charge: the arcs strobe, the tip glow swells to 1.6×, the shards pull in 18% and rise, and the orb glow builds. **Shot frame t = 0.20 s.** The flash and the upward bolt follow (visible 0.20–0.33 s), the frost-nova ring bursts from crown-arm height (to about Ø 1.9 m, gone at 0.54 s), and the crown dips 3 cm. Everything settles by 0.6 s. |
| `spawn` | 1.2 s | no | 0.05–0.45 s: the coil column grows out of the plinth. 0.30–0.70 s: the crown drops in from 0.7 m above with an overshoot. 0.62–0.94 s: a frost-nova flash as it lands. 0.78–1.15 s: the shards spin in. ~0.9 s: the orb ignites. **It ends exactly on idle's first pose** (verified, difference 0.0). |

**All three clips key the same 36 tracks** on 12 nodes, holding constant values where a clip doesn't move something. Godot's AnimationMixer resets un-keyed channels, which would otherwise drop parts to the origin. `fire` ends with the shards turned 60°, which looks identical to idle's start.

## Import settings (`cryo_coil.glb.import`)
`animation/fps=60`, `idle` loop_mode 1, AnimationPlayer `import_tracks/* = 0` (IfPresent), **`animation/remove_immutable_tracks=false`** (required), `nodes/root_name="CryoCoil"`. Verified headless in Godot 4.7.2: import with no errors or warnings, clips 4.0 s (looping) / 0.6 s / 1.2 s with 36 tracks each, and 19,858 tris. See `source/godot_verify.log`.

## Materials
- `cryo_coil_mat` is one material shared by Base, Column, Crown and FrostShards. It uses a 2048² atlas: albedo (sRGB), normal (OpenGL tangent), ORM (R=1, G=roughness, B=metallic) and emission at energy 3. The crown's Meshy texture was re-baked into this atlas.
- FX materials (emissive, no textures): `TipGlow_mat` #BFF6FF (alpha), `MuzzleGlow_mat` #E0FFFF, `MuzzleFlash_mat` #9AF0FF (alpha), `Arc_mat` #C8F6FF, `Bolt_mat` #C8F4FF, `FrostNova_mat` #D8F8FF (alpha).

## Accent masks: path-color recolor
Both masks are 2048² RGB in UV0. Parent A = **frost** (it sorts first in `frost+tesla`), and parent B = **tesla**. **R = 1st path → trim, G = 2nd path → glow (emissive), B = 3rd path → details.**

| | A `cryo_coil_accent_mask.png` (Frost) | B `cryo_coil_accent_mask_b.png` (Tesla) |
|---|---|---|
| R trim | **the crown's cream frame** (spire pillars, cross-arm frames), coolant pipes, crystal-cluster brackets, the lower collar's frost band | the 4 coil rails, the top collar stripe band, the plinth trim band |
| G glow | **the crown's ice crystals** (spire, arm crystals, icicles, finial), the 4 corner crystal clusters, the 6 orbiting shards | the 4 coil glow windows, the energy seat ring under the crown, 12 plinth vent lights |
| B details | the crown's magenta stripe accents, collar frost spikes, a small shard per corner cluster | plinth side stripes, rail clamps, insulator caps |
| shared | **the cryo-core orb is in G of both masks** (the glows add) | same |

R/B overlap between the masks is 0 pixels, and G overlaps only on the orb. Coverage is A R/G/B ≈ 10.6 / 16.6 / 1.3 % and B ≈ 2.4 / 3.0 / 1.2 %. Frost's coverage is larger on purpose: the crown is the frost half and carries most of its colors, while the Tesla colors live on the coil. Unmasked areas are mixed 72% toward #9AF0FF by `MergeArt.BODY`. `previews/cryo_coil_recolor_demo.png` reproduces `toon_model.gdshader` exactly.

## Paste-ready note for Claude
> New merge tower model: Cryo Coil v2 (frost + tesla), recipe #9AF0FF. Unzip `cryo_coil_game.zip` into `godot/art_src/towers/merges/frost_tesla/` (follow `CLAUDE_NOTES.md` there). If an older cryo_coil.glb was ever imported, first delete the extracted `cryo_coil_cryo_coil_*.png` files (and their `.import`) plus `.godot/imported/cryo_coil*`. Keep `cryo_coil.glb.import` next to the glb (fps 60, idle loops, import_tracks IfPresent, **remove_immutable_tracks=false**, root_name CryoCoil). It does NOT aim: tower.json has `"yaw": "-"`, `"pitch": "-"`, and the GLB has no Yaw/Turret/Pitch/Gun/Barrel nodes. Shots and chain lightning start at the node named `Muzzle` (`Base/Crown/Muzzle`, the orb on top, global (0, 2.182, 0)). `BuffPoint` is on top. Clips: play `spawn` (1.2 s), then loop `idle` (4.0 s); `fire` is 0.6 s with the shot at t = 0.20 s, then resume idle. Recolor: `cryo_coil_accent_mask.png` = A = Frost (crown frame R, crown crystals G, details B) and `cryo_coil_accent_mask_b.png` = B = Tesla (coil rails R, coil glow G, details B); the orb is in both G channels. Check tower.json against `live_3d.gd`. Test an in-game Frost Pylon + Tesla Coil merge: the crown stays still, shots leave from the orb, and path colors land on the crown (frost) and the coil (tesla). Render it live; no sprite baking. **Also fix Railgun:** in `godot/art_src/towers/merges/arcane_tesla/tower.json`, change `"muzzle": "Turret/Gun/Barrel/Muzzle"` to `"muzzle": "Muzzle"`. `find_child()` matches node names, not paths, so right now Railgun shots come from the tower center.
