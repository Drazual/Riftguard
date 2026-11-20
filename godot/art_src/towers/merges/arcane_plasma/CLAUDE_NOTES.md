# Starbolt (Arcane Bolt + Plasma Cannon): integration notes for Claude

Recipe `arcane+plasma`, data name **"Starbolt"**, recipe color #FF6FD8 (`data/recipes.tres`). Boon "Starburst Rounds" is unchanged.

**The model.** The slim Arcane Bolt column, collar ring and three real Arcane stone petals. Between the petals floats a
small glowing **four-point star** cut from the Plasma Cannon's real teal energy cell (4 tapered points, 4 short glints,
a hub), with a teal glow shell. A narrow band of the Plasma Cannon's real radiator fins wraps the column just under
the collar, and two small plasma canisters (cell copies with the cannon's navy/cream caps) sit low on either side.
The head aims (yaw + pitch); the star spins about the aim axis. 1.61 m tall, not bottom-heavy.

## Files → `godot/art_src/towers/merges/arcane_plasma/`
```
starbolt.glb, starbolt.glb.import         model (textures embedded; .import: remove_immutable_tracks=false, idle loops)
starbolt_accent_mask.png / _b.png         path-colour masks (A = arcane, B = plasma; R trim, G glow, B detail)
tower.json
fx/starbolt_fx.tscn  fx/starbolt_fx.gd     2D board FX (class StarboltFX)
```

## Model
- **21,091 tris** (v1.1). 1.61 m tall (Rimeshard 1.61, Cryo Cannon 1.50). Footprint ±0.38 m.
- Muzzle at rest: Godot (0, 1.392, 0.07) — the star's centre (shots leave from the star).

Node tree (Godot):
```
Base                                  arcane column + plinth (static, never keyed)
  FinBand                             plasma radiator fin band under the collar (spawn pop only)
  Canisters                           2 plasma canisters, low on the sides (spawn pop only)
    CanGlow0, CanGlow1                their teal glow (pulse in idle, flash in fire/supernova)
Turret                                YAW node (game-driven, never keyed)
  Head                                arcane collar + hood
    PetalL, PetalR, PetalB            3 arcane petals (flick open ~9° in fire, ~18° in supernova)
  Gun                                 PITCH node (game-driven, never keyed)
    Star                              SPIN node: the four-point plasma star; spins about the aim axis
      StarGlow                        teal glow shell (spins with it)
    StarCore, StarHot                 white-teal core + magenta glint (flare at the shot)
    Runes                             3 magenta arcane motes orbiting the star
    Muzzle                            the star's centre
      StarFlare, ChargeHalo, MuzzleFlash, Bolt, NovaRing (supernova only), HeatGlow (NOT keyed: code drives it)
BuffPoint             (y ≈ 1.71)
```
- **Aims:** `"yaw": "Turret"`, `"pitch": "Turret/Gun"`, `"aim": 0.0`, `"dirs": 16` (like Prism Lance / Railgun).
- Every clip keys the same 50 channels on 18 nodes; Base, Turret and Gun are never keyed.

| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | The star turns slowly (0.25 turns/s), motes counter-turn, star glow, core and canister glows breathe, petals sway 1.2°. |
| `fire` | 0.45 s | no | **Short charge 0–0.15 s:** the star flares (magenta glint ×2.4, core ×1.6), a halo grows, the petals flick open 9°, the canisters pulse teal. **SHOT at 0.15 s (`shot_time`)**: a pink four-point flash, the bolt leaves (2D FX take over). The star spins 2 turns in the clip. Ends on idle frame 0. |
| `supernova` | 0.45 s | no | Same timing (SHOT 0.15 s) so `merge_lead` is unchanged, but everything is ~1.6× bigger: petals 18°, canisters flash, a teal NovaRing expands round the star, the star spins 3 turns. |
| `spawn` | 1.2 s | no | Fin band and canisters pop up, the head pops, petals swing in from 35°, then the star pops in spinning 1.5 turns and the glows ignite. Ends on idle frame 0. |

- Fire is shorter than the 0.5 s rate, so sustained fire reads as a constant fast-spinning, bright star.
- **Heat glow:** the unkeyed `HeatGlow` (rest scale 0.001) at the star, driven from code exactly like Rimeshard's
  `_rime_heat` (generalise it to any merge whose tower.json has `heat_node`).

## Attack: how it should WORK (numbers marked SUGGESTED)
Merged stats from `try_merge` (repo, unchanged):
- dmg = max(28, 48) × 1.5 = **72**, rate = min(0.5, 1.4) = **0.5**, range = min(180 × 1.1, 165 × 1.6) = **198**, splash **50** (plasma)
- 72 / 0.5 = **144 dps**; DPS cap 2.6 × max(56, 34.3) = **145.6**.

1. **Bolt (new projectile).** At the fire clip's shot moment (`merge_lead`, 0.15 s) a bolt leaves the star at
   **950 board px/s** (`bolt_speed`, SUGGESTED), led a little along the path, and lands with the normal plasma splash
   (`_land`, radius 50). The board draws it from a `"star_bolt"` fx; the burst from `"star_burst"`.
2. **Supernova (every 4th shot, new).** A counter on Tower (`star_n`) counts shots; every `nova_every` = **4**th
   (SUGGESTED) is a supernova: damage × **1.4** (`nova_dmg`), splash radius × **1.8** (`nova_splash`, 50 → 90),
   **12** tiny falling stars (FX only), and a faint star field left behind for **1.2 s** (`nova_linger`) doing
   **0.15 × hit per second** (`nova_linger_dps`) — all SUGGESTED. The tower plays its `supernova` clip for that shot.
3. **Balance.** Average per shot = (3 + 1.4) / 4 = 1.1 × → **158 dps** single target, plus ~13 dmg of field per nova
   (~6 dps) ≈ **164 dps**, ~13% over the 145.6 hybrid cap, but only on the supernova shots. If that's too much use
   nova_dmg 1.25 (≈150 dps) or drop the linger. Splash area on a nova is 3.2× a normal shot's.
4. **Not to be confused** with the arcane path trait `hex_nova` (its own purple rings); they stack independently.

## FX: StarboltFX (fx/starbolt_fx.gd), drawn on `board.top`, ticked in game time
- `shoot(from, to, flight, on_hit, power, nova)` — magenta bolt with a teal core, spinning white star at the head and
  a time-based glitter trail (magenta + teal sparkles). `nova = true`: bigger, with a spinning teal star and halo.
- `splash(at, radius, power)` — small star-shaped plasma splash: teal + magenta four-point burst, teal/magenta ground
  rings (ground squash 0.75), a few sparkles.
- `supernova(at, radius, power, linger, n_stars)` — white-teal flash, triple ring, an 8-ray star, then `n_stars` tiny
  stars fall around it over ~0.7 s (magenta rim + white + teal core, they glint where they land), plus the faint
  twinkling field for `linger` s.
- `busy()`, `tick(game_dt)` (after the first tick() it no longer runs on _process).

## Tested (box, local copy of origin/main 8e52946, then reverted)
- `--import` clean; `--merge-selftest` 8/8 PASS (arcane+plasma added as a third run).
- A real run: arcane + plasma maxed and merged in-game; bolts, splashes, supernova every 4th shot (shots 4, 8, 12),
  the `supernova` clip playing for them; no script errors.
