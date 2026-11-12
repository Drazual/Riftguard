# Prism Lance v2 (Arcane Bolt + Prism Laser): integration notes for Claude

The recipe is `arcane` + `laser` → **Prism Lance**, recipe color #FF6FA0. The model is the same as v1. v2 changes the attack:

- **v1** fired a charged magenta bolt.
- **v2** is a continuous beam that heats up on one target. On every damage tick, arcane sparks fly from the beam's impact point to nearby enemies for a percentage of that tick's damage, so the sparks scale with heat too.

The pieces:
- **Model clips:** `idle`, `charge`, `fire` (sustained loop) and `spawn`.
- **2D board effects:** beam and sparks (`fx/`).
- **Heat look:** a helper script (`fx/prism_lance_heat.gd`) for the model.

## Files → `godot/art_src/towers/merges/arcane_laser/`
```
prism_lance.glb, prism_lance.glb.import      the model (the .import loops idle AND fire)
prism_lance_accent_mask.png / _b.png         path-colour masks (same as v1)
tower.json
fx/prism_lance_beam.tscn  .gd  .gdshader     the beam (class PrismLanceBeam)
fx/prism_lance_sparks.tscn  .gd              the arcane sparks (class PrismLanceSparks)
fx/prism_lance_heat.gd                       the model's heat look (class PrismLanceHeat)
```
The textures are embedded in the glb. Loose copies are only in the delivery zip.

## Why the beam is 2D
Merge3D renders each merge model in its own small SubViewport. A 3D beam would be clipped at that box. The base Prism Laser draws its beam on the board in 2D (`Board._laser_beam`: an AnimatedSprite2D stretched from the muzzle to the target, 1 + 0.6·heat wide). Prism Lance does the same with its own shader beam, from `Board.merge_muzzle(t)` to the target's chest (`SY(e.y) - body_lift(e)`). It runs on the Compatibility renderer.

## Model
- The node tree is the same as v1, except the `Bolt` node was removed:
  - `Turret` (yaw) / `Gun` (pitch).
  - The Muzzle sits at the crystal tip, reached as `Turret/Gun/Crystal/Muzzle`. `"muzzle": "Muzzle"` is a node name for `find_child`.
- Rest pitch is `aim` 0.12. The model is 22,332 tris.

| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | The canister and prism glow breathe, the tip glob pulses, the runes orbit 360°, and the head hums. |
| `charge` | **0.30 s** | no | Warm-up from idle frame 0:<br>• The prism-mouth glow and the magenta tip glob swell.<br>• The halo grows.<br>• Charge rings pop prism → tip at 0.03, 0.09 and 0.15 s.<br>• The canister pumps.<br>• The runes spin up one full turn.<br>• The crystal draws back 1 cm and shivers.<br>• The tip flares at 0.285 s.<br>It ends exactly on `fire` frame 0 (verified, difference 0.0). **Start the beam at the end of `charge`.** |
| `fire` | **0.8 s** | **yes** | Sustained beam:<br>• The glob is held at 1.15 ±0.1 (10 Hz flicker), with a small held flare and the halo.<br>• The three rings pulse in a wave toward the tip.<br>• The canister pumps twice per loop.<br>• The prism glow throbs.<br>• The runes spin 720° per loop.<br>• The crystal vibrates (±1.2 mm at 10 Hz, ±1.8 mm at 20 Hz) and is held 8 mm back.<br>The loop seam is 2e-7. |
| `spawn` | 1.2 s | no | Same as v1. It ends on idle frame 0. |

All 4 clips key the same 42 tracks (verified). None of them key Turret or Turret/Gun (verified: yaw 1.2 and pitch -0.4 were unchanged after charge and fire).

`fire` frame 0 is not the idle pose (the glows are lit), so when the beam stops, go back to idle with a cross-fade: `ap.play("idle", 0.15)`.

### Heat look (model)
`PrismLanceHeat.apply(merge3d.model, heat)` makes the effect parts brighter and hotter in color:
- It covers MuzzleGlow, ChargeHalo, MuzzleFlash, PrismGlow, ChargeRing0–2, Runes and CanGlow.
- The materials are duplicated per tower.
- At heat 1, MuzzleGlow's energy goes from 1.6 to 3.5 and its color from #FF4FC0 to #FF9DDE.
- At heat 0 the model looks exactly as exported.

`ap.speed_scale = PrismLanceHeat.clip_speed(heat)` gives 1.0 → 1.8, so the runes spin and the canister pumps faster. A manual `advance()` (Merge3D.tick) honors speed_scale (verified: advance(0.1) at 1.8 = 0.18). Reset it to 1.0 when the beam stops.

## Beam FX: `PrismLanceBeam` (Node2D, `fx/prism_lance_beam.tscn`)
- **API:**
  - `start(from, to)`: the front runs out to the target in 0.07 s.
  - `set_ends(from, to)`: call every frame.
  - `heat` (0..1).
  - `retarget(to)`: on a target switch, the front runs out again.
  - `stop(free_after := false)`: fades in 0.12 s, then emits `faded`.
  - `tick(game_dt)`: steps in game time. Once it's called, the beam no longer uses `_process`, so it pauses and speeds up with the game.
- **Width:** `width_px` is 14 board px of glow at heat 0, up to 1.8× at heat 1. The bright core is about a quarter of that.
- **Look by heat:**

  | heat | edge color | core | width | flicker | flow |
  |---|---|---|---|---|---|
  | 0 | laser cyan | cyan-white | thin | 16 fps steps (like the base laser sprite) | slow |
  | 0.5 | pink #FF6FA0 | white | | | |
  | 1 | hot arcane magenta | pure white | wide | stronger | fast, with a visible wobble |

  There are edge sparkle flecks like the base laser's.
- **Caps:** an emitter flare on the crystal tip, and an impact glow with turning rays (4 → 7 rays, longer as it heats).
- `PrismLanceBeam.heat_color(h)` gives the beam's color for matching effects such as hit numbers.
- Add it to `board.top`. It has no "f" meta, so the reaper leaves it alone. Keep one per tower, for example `t.set_meta("lance_beam", b)`, and `stop(true)` it when the tower loses its target, is stunned, sold or merged, or the run ends.

## Spark FX: `PrismLanceSparks` (Node2D, `fx/prism_lance_sparks.tscn`)
- **API:**
  - `burst(impact, target_positions: Array[Vector2], heat, on_hit := Callable()) -> int`
  - `spawn_spark(from, to, heat, on_hit := Callable(), delay := 0.0)`
  - signal `spark_hit(at)`, `busy()`, `tick(game_dt)`
- **Per target:** 1 spark at heat < 0.4, 2 from 0.4, 3 from 0.8. They are staggered by 0.035 s. Only the first spark per target calls `on_hit(i)`.
- **Flight:**
  - Each spark is a magenta rune diamond with a trail, flying a curved arc (sideways and upward bulge).
  - Flight time is 0.1 s + distance/700, clamped to 0.16–0.38 s.
  - It pops on hit: a ring, a white flash and 4–8 shards, bigger with heat.
  - Plus a crown of 3–9 embers at the impact point.
- One shared node on `board.top` can hold every tower's sparks.
- Damage can land at once or in `on_hit` (when the spark arrives, about 0.2–0.3 s later). On-hit reads better; at once is simpler and safer if the enemy dies mid-flight.

## tower.json (v2)
```
"anims": {"idle","charge","fire","spawn"}
"beam": true, "charge_time": 0.3, "fire_time": 0.8, "fire_loop": true
"shot_time": 0.0     (must be 0: Game.merge_lead would otherwise hold every beam tick)
"beam_fx": "fx/prism_lance_beam.tscn", "spark_fx": "fx/prism_lance_sparks.tscn", "heat_script": "fx/prism_lance_heat.gd"
"aim": 0.12, "wide": 46, yaw "Turret", pitch "Turret/Gun", muzzle "Muzzle", buff_point "BuffPoint"
```

## Merge3D flow (needs a small change)
- `Merge3D.shoot()` does `ap.stop(); ap.play(fire)` on every shot. For a beam that would restart the loop 5×/s. For a beam merge, change it so:
  - **Beam on (first tick on a lock):** if not already in `charge` or `fire`, play `charge`.
  - **Later ticks:** leave the clip alone.
  - **Beam off:** `play(idle, 0.15)`.
- Merge3D's `animation_finished` handler plays idle after any non-idle clip, and **`animation_finished` fires for `charge` even when `fire` is queued** (verified). Make the handler play `fire` when `n == "charge"`, rather than relying on `queue()`.

## Verified headless (Godot 4.7.2)
- 0 import or verify errors. See `source/godot_verify.log`.
- Clip lengths, loops, seams and same-track sets as above.
- The game's own `merge_3d.gd` (copied from the repo) runs `setup()` with this tower.json: it plays spawn, then idle, and `muzzle_at()` resolves.
- Beam and spark scenes instantiated and ran at heat 0 / 0.5 / 1:
  - beam width 14 / 19.6 / 25.2;
  - it fades and frees after `stop(true)`;
  - sparks 3 / 6 / 9 for 3 targets;
  - all 3 on_hit callbacks fired, and the sparks were done within 0.55 s.
- `PrismLanceHeat` at 0 / 0.5 / 1 gives MuzzleGlow energy 1.6 / 2.56 / 3.52 and clip_speed 1.0 / 1.4 / 1.8.
- Rendered in-engine (xvfb, the Compatibility renderer) for the previews.
