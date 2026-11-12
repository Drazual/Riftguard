# Bombard v2 merge tower (Mortar + Plasma Cannon): integration notes for Claude

The recipe is `mortar` + `plasma` → **Bombard**, recipe color `#D8F0B0`. This is **v2**, made after the feedback "make sure it has a charge up for its projectile. make the gun part thinner so the tower doesnt look so bottom heavy and out of proportion". v1 is kept in `../final_v1/`.

**What changed in v2**
- **Slimmer gun, taller silhouette.**
  - The real Mortar barrel and cradle are about 26% narrower: the barrel's outer diameter went from 0.73 m to about 0.59 m. The barrel is also 8% longer along the bore.
  - The Mortar head/gear ring is 24% narrower and 6% taller.
  - The Plasma Cannon canisters are 24% smaller and tucked in closer. The radiator is narrower.
  - The Plasma Cannon plinth is lower and smaller: 1.16 × 1.11 m, with its top at 0.364 m.
  - Result: 1.83 m tall × 1.18 m wide (v1 was 1.72 × 1.54). The plinth is **20%** of the height (v1 was 26%).
- **A real charge-up.** `fire` is now **1.0 s**, and the **shot is at t = 0.55 s**:
  - 0–0.55 s: the plasma glob inside the bore swells from small to bore-filling inside a growing halo.
  - Three teal charge rings light up along the barrel, breech to muzzle.
  - The two canisters pump brighter in alternation.
  - Lightning streams crackle from each canister to the trunnions, with energy motes travelling along them.
  - The barrel creeps back 1 cm and shivers.
  - At 0.55 s: the glob flares, then the flash, the plasma shock ring, and the 9.5 cm Mortar recoil.

## Where it goes
Copy everything to **`godot/art_src/towers/merges/mortar_plasma/`**:
```
bombard.glb                 game asset (Y-up, meters, 2048 atlas embedded, 3 clips)
bombard.glb.import          import settings. Keep it next to the glb.
bombard_accent_mask.png     parent A (Mortar) accent mask, same UV as the atlas
bombard_accent_mask_b.png   parent B (Plasma Cannon) accent mask
textures/bombard_{color,normal,orm,emission}.png   loose copies of the embedded atlas
tower.json                  descriptor (field names match live_3d.gd / docs/merge-art.md)
```
**v2 has a new UV layout.** If v1 was ever imported, first delete the extracted `bombard_bombard_*.png` files (and their `.import`) plus `.godot/imported/bombard*`. Godot doesn't overwrite textures it has already extracted, and a stale v1 atlas would look scrambled.

## Node tree (Godot names)
```
Bombard (root)                      origin = bottom center of the plinth, front/aim = +Z
├─ Base            MeshInstance3D  static Plasma Cannon plinth (top y=0.364)
├─ Turret          Node3D  YAW (rotation.y), at (0, 0.364, 0)
│  ├─ Head         Mortar gear ring + cradle arms + pistons (Ø 1.16 m)
│  ├─ Radiator     Plasma Cannon finned radiator on the back
│  ├─ Canister0/1  Plasma Cannon teal canisters, left/right
│  ├─ CanGlow0/1   FX canister glow sleeves (breathe in idle, pump during the charge)
│  ├─ Stream0/1    FX lightning canister → trunnion (charge only)
│  ├─ ChargeMote0/1 FX energy motes travelling along the streams (charge only)
│  └─ Gun          Node3D  PITCH (rotation.x), pivot at global (-0.006, 0.920, 0.002), REST rotation.x = -1.0858 (barrel 62.2° up)
│     ├─ Cradle    Mortar trunnion cradle
│     └─ Barrel    Mortar barrel (slimmer, longer). Recoils along local -Z
│        ├─ ChargeRing0/1/2  FX teal rings around the barrel (breech → muzzle), charge only
│        └─ Muzzle Node3D at the bore mouth, global (-0.006, 1.701, 0.410) at rest; +Z = shot direction (0, 0.885, 0.466)
│           ├─ MuzzleGlow   FX plasma glob, 17 cm inside the bore
│           ├─ ChargeHalo   FX soft halo around the glob (charge only)
│           ├─ MuzzleFlash  FX star (shot only)
│           └─ PlasmaRing   FX teal shock ring (shot only)
├─ BuffPoint       Node3D (0, 1.928, 0)
└─ AnimationPlayer
```

### Aiming
- `tower.json`: `"yaw": "Turret"`, `"pitch": "Turret/Gun"`, `"aim": -1.0858`, which is the Mortar's 62° lob rest. The base Mortar's `tower.json` uses -1.5708; switch to that if you want them to match.
- No clip keys `Turret` or `Turret/Gun` (verified). Headless test: yaw 1.2 and pitch -1.3 were set, `fire` was played, and both were unchanged at t = 0.6 s.
- `"muzzle": "Muzzle"` is a **node name** (`find_child`). The path form returns null (verified). Spawn the projectile at `muzzle.global_position` at **t = 0.55 s** after starting `fire`.
- Clean pitch range: about rest -25° to rest +22°. Recommended: yaw-only aim.

## Clips (60 fps)
| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | Canister glows breathe ±7% in anti-phase, the plasma glob in the bore pulses gently, the Head hums ±4 mm. All charge/shot FX stay hidden. |
| `fire` | **1.0 s** | no | **Charge 0–0.55 s:**<br>• 0–0.06 s: the glob draws in to 0.12×.<br>• It then swells to 1.0× by 0.50 s, with the ChargeHalo growing from 0.14 s.<br>• ChargeRing0/1/2 pop on at 0.12, 0.23 and 0.34 s, then pulse.<br>• The canisters pump alternately (peaks 1.18 → 1.24 → 1.32 → 1.40×).<br>• The streams crackle on and off every 0.1 s, and 3 motes per side fly canister → barrel.<br>• From 0.25 s the barrel creeps back 1 cm and shivers ±2.5–6.5 mm from 0.30 s.<br>**SHOT t = 0.55 s:**<br>• The glob flares to 1.5× and empties by 0.67 s.<br>• Flash 0.55–0.70 s; the plasma ring expands to about Ø 1.0 m by 0.85 s.<br>• The barrel kicks **9.5 cm** back by 0.60 s and eases home by 0.94 s.<br>• Cradle jolt 1.4 cm / 1.2°, Head dip 1.8 cm.<br>• The rings and streams cut out.<br>The glob refills by 1.0 s, which is exactly idle frame 0 (verified, difference 0.0). |
| `spawn` | 1.2 s | no | Head rises 0.02–0.38 s, cradle and barrel pop in 0.10–0.46 s, the barrel slides forward 0.55–0.95 s, the radiator and canisters pop in 0.48–0.92 s, the canisters ignite, the charge rings flash once (0.90–1.06 s), and the glob lights with a ring pulse at ~1.0 s. It ends on idle's first pose (verified, difference 6e-8). |

**All three clips key the same 57 tracks** on 19 nodes, holding constant values where a clip doesn't move something.

If you want the charge to be interruptible: the charge is just `fire` from 0 to 0.55 s. Code can `play("fire")` when a target is acquired and spawn the shell at 0.55 s. There's no separate `charge` clip, so `fire` stays self-contained.

## Import settings (`bombard.glb.import`)
`animation/fps=60`, `idle` loop_mode 1, AnimationPlayer `import_tracks/* = 0` (IfPresent), **`animation/remove_immutable_tracks=false`** (required), `nodes/root_name="Bombard"`. Verified headless in Godot 4.7.2: 0 import errors, clips 4.0 s (looping) / 1.0 s / 1.2 s with 57 tracks each, and 23,781 tris. See `source/godot_verify.log`.

## Proportions
- 1.83 m tall (barrel rim), 1.18 m wide. Plinth top 0.364 m (20%). Barrel outer Ø about 0.59 m.
- Parents: Mortar 1.35 / 1.92 m, Plasma Cannon 1.33 / 1.36 m.
- `"wide": 54`: `_fit()` scales by the x-extent, and v2 is much narrower, so 54 keeps its on-screen height near v1's. With 54 it's about 84 px tall; with 64 it would be about 99 px.

## Materials
- `bombard_mat`: one 2048² atlas re-baked from the Mortar and Plasma Cannon textures. Albedo (sRGB), normal (OpenGL tangent), ORM (R=1, G=roughness, B=metallic), emission at energy 3.
- FX materials (emissive, no textures):
  - `MuzzleGlow_mat` #5FF8E4
  - `ChargeHalo_mat` #7FFFF0 (alpha)
  - `ChargeRing_mat` #5FF8E4 (alpha)
  - `Stream_mat` #9FFFF4
  - `Mote_mat` #C8FFF8
  - `MuzzleFlash_mat` #8FFCEC (alpha)
  - `PlasmaRing_mat` #5FF0E0 (alpha)
  - `CanGlow_mat` #5FF8EA (alpha)

## Accent masks: path-color recolor
Both masks are 2048² RGB in UV0. A = **mortar** (sorts first), B = **plasma**. R = 1st path → trim, G = 2nd path → glow, B = 3rd path → details.

| | A `bombard_accent_mask.png` (Mortar) | B `bombard_accent_mask_b.png` (Plasma Cannon) |
|---|---|---|
| R trim | the barrel's cream armour bands, cream cradle and hub plates | plinth cream armour, radiator cream bands, canister end caps |
| G glow | barrel hazard stripes, trunnion hub rings | teal plasma glass and cores of the canisters, plinth light strips |
| B details | teal barrel band, pistons, trims | teal plinth panels, magenta pinstripes |

There are 0 overlapping pixels between A and B, and R/B overlap is 0. Coverage is A ≈ 4.5 / 0.4 / 2.1 % and B ≈ 4.4 / 1.7 / 1.9 %. Unmasked areas are mixed 72% toward #D8F0B0. `previews/bombard_recolor_demo.png` reproduces `toon_model.gdshader` exactly.
