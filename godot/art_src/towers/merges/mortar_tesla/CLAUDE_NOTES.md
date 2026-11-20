# Thunder Battery (Siege Mortar + Tesla Coil): integration notes for Claude

Recipe `mortar+tesla`, data name **"Thunder Battery"**, recipe color #D8E8FF (`data/recipes.tres`). Its boon is unchanged.

**The model.** The real Siege Mortar (base with all 6 feet, gear ring, head, cradle and the cream barrel at its own
62° lob lean), "tesla'd": a copper winding and cyan/dark coil collars wrap the barrel near the mouth, with a cyan
CollarGlow ring. Three small Tesla coils, built from the real Tesla Coil's column and toroid top on little
dark/cream/copper pedestals, stand round the mortar on the gear ring (at 90°, 210° and 330°). They sit on the yaw
node, so they turn with the mortar and their arcs always reach the ball. The coils charge a crackling lightning ball
just in front of the mouth, then the mortar fires it. 1.37 m tall (the ball centre is at 1.41 m), ~1.9 m across the
coils. Slim, not bottom-heavy, and it still reads as a mortar first.

## Files → `godot/art_src/towers/merges/mortar_tesla/`
```
thunder_battery.glb, thunder_battery.glb.import   model (textures embedded; .import: remove_immutable_tracks=false, idle loops)
thunder_battery_accent_mask.png / _b.png          path-colour masks (A = mortar, B = tesla; R trim, G glow, B detail)
tower.json
fx/thunder_battery_fx.tscn  fx/thunder_battery_fx.gd   2D board FX (class ThunderBatteryFX)
```

## Model
- **38,186 tris** (35,878 body + 2,308 FX meshes). It's heavier than Starbolt because both parents are dense (the
  mortar body alone is ~24k after decimation). One 2048² atlas (color, normal, ORM, emission).
- Muzzle at rest: Godot (−0.006, 1.414, 0.351). That's the ball's centre, where the shot leaves.

Node tree (Godot):
```
Base                         mortar base, feet, gear ring (static, never keyed)
Turret                       YAW node (game-driven, never keyed), y 0.314
  Head                       mortar head (spawn pop only)
  Coil0, Coil1, Coil2        3 small tesla coils (jolt at the shot, pop in spawn)
  ArcNest
    ArcA0..2, ArcB0..2       coil → ball arcs; each starts exactly on its coil's tip (v1.1)
    CoilGlow0..2             small flare sitting on each coil's tip (breathes in idle, flares while charging)
    CoilTip0..2              v1.1: never-keyed markers on the coil tips (tower.json "charge_tips") for the 2D arcs
  Gun                        PITCH node (game-driven, never keyed); rest = the mortar's own lean, so "aim": 0.0
    Cradle                   mortar cradle
    Barrel                   mortar barrel + copper winding + collars (recoils along the bore)
      CollarGlow             cyan ring at the winding
    Muzzle                   the ball's centre (shot point)
      Ball, BallGlow, BallArcs, ChargeHalo, MuzzleFlash, ShockRing
BuffPoint                    y 1.663
```
- Every clip keys the same 66 channels on 22 nodes (the CoilTip markers are never keyed). Base, Turret and Gun are never keyed. The clips are sorted
  idle-first, and the rest pose is idle frame 0.

| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | A small ball (0.32×) pulses at the mouth, the coil terminals breathe, and short random sparks flick from coils to ball now and then. |
| `fire` | 1.2 s | no | **Charge 0–0.85 s:** the coil glows ramp up and flicker. Arcs leap from each coil in turn (0.10 / 0.18 / 0.26 s), reach the ball by 0.5 s and crackle. The ball grows to full size and swells, and a halo builds. The barrel shivers from 0.55 s. **SHOT at 0.85 s (`shot_time`)**: the ball vanishes, with a muzzle flash, a shock ring and a 9 cm recoil along the bore. The coils jolt and the arcs cut. The ball re-forms small and everything eases back to idle frame 0 by 1.2 s. |
| `spawn` | 1.2 s | no | Head, cradle, barrel and coils scale in with overshoot. All arcs strike once at 0.92 s, then the ball appears. Ends on idle frame 0. |

`merge_clip_k` speeds the clip up when the tower fires faster than 1.2 s. A maxed Thunder Battery (rate ~0.94 s)
plays it at ~1.4×, so the charge shows for ~0.61 s. An unmaxed one charges the full 0.85 s. (Bombard: ~0.26–0.55 s.)

## Mechanic (all numbers SUGGESTED)
- `tower.gd`: `var thunder := false`.
- `try_merge` (non-super `mortar+tesla`, before the DPS cap): `thunder = true`, `rate × 1.8`, `dmg × 1.7`,
  `splash × 1.4` (`THUNDER_RATE / THUNDER_DMG / THUNDER_SPLASH`). Single-target DPS is 0.94× before the cap and the
  same after it (the cap binds either way). Each shot hits ~1.8× harder, over 1.96× the area.
- `fire()`, `merge_lead` branch: `elif t.thunder and target is Enemy: thunder_ball(...)`. Also, once per volley, it
  adds a `"thunder_charge"` fx lasting `lead` seconds. That's a 2D glow + coil arcs over the mouth so the charge-up
  reads at board scale too.
- `thunder_ball`: flight = board distance / `bolt_speed` (1500 px/s, min 0.06 s). That's ~0.1–0.2 s, so very fast.
  It's led along the path like Rime Cannon's ball, adds a `"thunder_ball"` fx, then `later(flight)`: `_land` on the
  spot (fake target), add a `"thunder_blast"` fx with r = splash, and `do_shake(0.005, 120)`. Tesla's inherited
  chain still hops on from the blast; the cluster, orbital and overload traits work as usual.
- `_land` skips the generic splash ring for `t.thunder`.
- Board `_sync_thunder` (like `_sync_cryo`) drives one shared ThunderBatteryFX:
  - `charge(getter, secs, pw)`, where the getter returns `merge_muzzle(t)` each frame
  - `shoot(muzzle, ground point, flight, pw, lob_k)`: a low, fast lob, apex = `lob_k` × distance (cap 50 px)
  - `blast(ground point, r, pw)`: flash, a shock ring out to the full radius, 8 jagged bolts to the rim, rim crackle and sparks, over 0.55 s
  - then `tick(dt * speed)`.

Measured in a real run (maxed Mortar + maxed Tesla, box capture): dmg 608.5, rate 0.942 s (646 DPS, at the cap),
range 252, splash 146.9 (was 104.9), chain 6 × 0.95. Unmaxed (level 1 parents): ~126 dmg every 1.98 s, splash 84.

## v1.1: the charge starts on the coil tips
- **Model:** the coil terminal point is now measured from the joined coil mesh (the top of each coil's terminal cap,
  +4 mm), and every arc's origin and CoilGlow sit exactly there. CoilGlow is smaller (r 0.05, flaring to ~1.9× while
  charging), so the tip stays visible and the arc visibly leaves it. New `CoilTip0..2` empties under
  `Turret/ArcNest`, at the tips, never keyed. Same tris (38,186), same clips and timings.
- **tower.json:** `"charge_tips": ["CoilTip0", "CoilTip1", "CoilTip2"]`.
- **Merge3D:** `point_at(path)` projects any model node, like `muzzle_at()`, with a per-name node cache.
- **Board:** `merge_point(t, path)`, like `merge_muzzle`. `_sync_thunder` gives `charge()` a getter that returns
  `{ at = muzzle, tips = [each charge_tips node's board point] }`. It's called every FX step, so the arcs follow
  the turret's yaw and pitch.
- **ThunderBatteryFX.charge:** the 2D arcs run from each projected tip into the ball, with a small staggered flare on
  each tip. There are no approximate offsets any more. The mouth glow is smaller, so it doesn't cover the coils at
  board scale.
