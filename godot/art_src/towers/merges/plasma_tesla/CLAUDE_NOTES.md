# Ion Storm (Plasma Cannon + Tesla Coil): integration notes for Claude

Recipe `plasma+tesla` → **Ion Storm**, color #FFD36E. The recipe text (data/recipes.tres):
"Explosive shells whose blast also throws lightning outward. The best crowd clearer."

The model is a Tesla Coil (dominant: the stretched copper coil column, the big black toroid with cyan strips, and the arcs) with the Plasma Cannon's barrel standing upright out of the toroid hub. The Plasma Cannon's base is the small, low plinth. It charges up, fires an ion shell straight UP, and the shell falls on the target (the Tesla Coil's sky-bolt idea). The blast is a plasma blast, and lightning forks OUTWARD from the blast centre to enemies the blast missed. There's no aim and no yaw or pitch nodes, because the shot goes straight up.

## Files → `godot/art_src/towers/merges/plasma_tesla/`
```
ion_storm.glb, ion_storm.glb.import       model (textures embedded; the .import loops idle only)
ion_storm_accent_mask.png / _b.png        path-colour masks (A = plasma, B = tesla)
tower.json
fx/ion_storm_fx.tscn  fx/ion_storm_fx.gd  2D board FX (class IonStormFX): shell, blast, lightning forks
```

## Model
- 22,312 tris. 2.056 m tall. The toroid is 1.10 m wide. The plinth is about 0.94 m wide × 0.30 m (about 15% of the height).
- Node tree:
  - `Base` (the plasma plinth, never keyed)
  - `Base/Column` (the tesla coil column)
  - `CoilTop` (the toroid, at y 1.25)
    - `CoilTop/Barrel` (the plasma barrel, upright)
      - `CoilTop/Barrel/Muzzle` (y 2.056, points +Y). Its children are TipGlow, TipCore, ChargeRing, ChargeRing2, UpBolt, UpBoltCore, MuzzleFlash and PlasmaGlow.
  - `ArcNest` (y 1.25): ArcV0-5, ArcL0-3, ArcT0-4, Spark0-7
  - `BuffPoint` (y 2.156)
- `"muzzle": "Muzzle"` is a node NAME for `find_child()`. `yaw` and `pitch` are `"-"`, so Merge3D leaves the model unturned.

| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | The arcs flicker in 1/15 s steps and sparks pop. The tip glows breathe and the plasma glow pulses. The charge rings counter-spin and the arc nest turns 360°. |
| `fire` | 1.0 s | no | **Charge, 0–0.55 s:** the plasma glow swells to 1.55×, the tip glow to 1.7×, the rings swell and spin up, the arcs intensify, the coil top hums and the barrel creeps down 1.2 cm.<br>**SHOT at 0.55 s (`shot_time`):** the UpBolt streaks up (0.55–0.81 s) with the muzzle flash, and the plasma glow launches up and collapses.<br>**Recoil:** the barrel 4.5 cm and the coil top 2.2 cm.<br>It ends on idle frame 0 (seam 3.5e-7). |
| `spawn` | 1.2 s | no | The column grows, the coil top drops in with a bounce, the barrel pops up and the arcs ignite. It ends on idle frame 0. |

All 3 clips key the same 105 tracks. Base is not keyed.

## Attack: how it should WORK (suggested; numbers are SUGGESTIONS, grounded in repo data)
The merge stats come from `try_merge` (hybrid): dmg = max(48, 24) × 1.5 = **72**, rate = min(1.4, 1.1) = **1.1**, splash **50** (plasma), chain = 3 + 1 = **4** (tesla), chain_mul 0.7, chain_reach 95. Tesla's `shot_up` is true.

1. **Charge.** `fire` plays at once, and the shot leaves at `shot_time` 0.55 (`Game.merge_lead`).
2. **Shell.** At 0.55 s, `IonStormFX.launch(muzzle, landing_point, 0.6, on_land)`.
   - The landing point leads the target like `lob_shell`: `lead = e.speed*(1-e.slow)*(0.55+0.6)` (0 if stunned or blocked), `p = pos_at(min(path_len, e.d + lead))`.
   - SUGGESTED `shell_flight` is 0.6 s (tower.json). It's shorter than the mortar's SHELL_TIME 0.8, so the total delay is 1.15 s.
3. **Blast.** On landing, call `_land(t, spot, d, 50, ...)` with a fake spot `{x, y, d=-1, dead=false, fake=true}`, as `land_shell` does.
   - Everything within 50 px takes 72.
   - The Plasma signature (Napalm Shells) already makes a burning zone there (r = splash × 0.7, 2 s, dps d × 0.25), because `base_types()` has plasma.
   - Draw it with `IonStormFX.blast(p, 50, power)`.
4. **Lightning thrown outward (the new part).** The existing `_land` chain hops one enemy to the next. Ion Storm should instead fork RADIALLY from the blast centre:
   - **Who:** SUGGESTED, the `int(t.chain)` (4) enemies nearest the blast centre that were NOT hit by the blast, within `splash + chain_reach` (50 + 95 = **145 px**).
   - **Damage:** SUGGESTED `d * t.chain_mul` = 72 × 0.7 = **50.4** each, the same for every fork (no 0.85 decay).
     - If Tesla's Overcharge signature or `chain_keep` is active, the forks take the full d (the same `keep` rule as `_land`).
   - **Effects per fork:** apply `chain_blast` (40 px, `hd*t.chain_blast`) and Static Shock stun (`randf() < t.stun` → 0.6 s) per fork, exactly as the `jump` lambda does.
   - **Draw:** `IonStormFX.fork(p, target_positions, power, func(i): apply the hit to i, 0.03)`. The hit can land in `on_hit`, about 0.06 s after the blast.
   - **Optional, SUGGESTED, off by default:** each fork may hop once more to the nearest unhit enemy within chain_reach for `×0.85`.
   - Implement it by skipping the chain block of `_land` for this hybrid (for example a `t.radial_chain` flag set in try_merge for `plasma+tesla`) and doing the radial loop after the splash hits.
5. **SUGGESTED `power`** for the FX is `clamp(d / 72, 0.75, 1.5)`, so buffed or surged shots look bigger.

Sanity check (SUGGESTED numbers): a 5-enemy clump plus 4 nearby gives 5 × 72 + 4 × 50.4 ≈ 562 per shot every 1.1 s. The Merge DPS cap (2.6× the stronger parent's dmg/rate) applies to the tower's stat line, not to multi-target totals, so this is the intended "best crowd clearer".

## FX: `IonStormFX` (Node2D, additive, `fx/ion_storm_fx.tscn`)
- **API:**
  - `launch(from, to, flight := 0.6, on_land := Callable(), power := 1.0)`: the shell rises 300 px over the first 35% of the flight (`SKY_UP`, the same as Tesla's sky bolt) and falls on `to`. It then emits `landed(at)` and calls `on_land`.
  - `blast(at, radius := 50, power := 1.0)`: 0.45 s. A white-gold flash, a plasma fireball, a ground ring squashed by K 0.75, blobs and a crackle on the rim.
  - `fork(from, targets: Array[Vector2], power := 1.0, on_hit := Callable(), delay := 0.0)`: 0.32 s jagged tesla-blue bolts with a white core, re-jagged at 30 fps, with a side branch and a pop at each target. `on_hit(i)` fires when bolt i arrives (0.06 s travel).
  - `busy()`, and `tick(game_dt)` for game-time stepping (after the first `tick`, `_process` stops driving it).
- Put one shared node on `board.top`. It has no "f" meta, so `_reap` leaves it alone.
- Positions are board px: from = `Board.merge_muzzle(t)`, and the blast and forks are at the ground/feet.

## tower.json
`yaw "-"`, `pitch "-"`, `muzzle "Muzzle"`, `buff_point "BuffPoint"`, anims idle/fire/spawn, `fire_time 1.0`, `shot_time 0.55`, `shot_up true`, `shell_flight 0.6`, `fx "fx/ion_storm_fx.tscn"`, `wide 56`, `foot [80,140]`, `size 160`.
`shell_flight` and `fx` are new keys; Merge3D ignores unknown keys.

## Verified headless (Godot 4.7.2; `source/godot_verify.log`)
- 0 errors.
- Clips: fire 1.0 s (no loop), idle 4.0 s (loop), spawn 1.2 s, all with the same 105 tracks. Seams are 0 / 3.5e-7 / 0.
- At 0.5 s the plasma glow is 1.317 and the tip 1.573. At 0.6 s the flash is 0.84, the UpBolt is out and the barrel has kicked.
- The game's own merge_3d.gd: `setup()` works, the yaw and pitch nodes are null, the box is (50, 87), `muzzle_at` is (0, -42.9), and it plays spawn then idle.
- The FX ran at power 0.75 / 1 / 1.5: landed, then fork hits 0–3, done in 1.05 s.
- Rendered in-engine (xvfb, Compatibility) for `previews/ion_storm_attack_ingame.gif`.
