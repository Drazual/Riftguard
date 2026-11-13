# Cryo Cannon v2 (Frost Pylon + Plasma Cannon): integration notes for Claude

Recipe `frost+plasma`, recipe color #E0E6FF. The data name is still **"Steam Engine"** in `data/recipes.tres`.
v2 replaces v1. v1 was the Steam Engine with a crystal boiler stack and steam puffs.

**SUGGESTED recipes.tres change.** The attack is no longer steam, so this is optional:
- `name = "Cryo Cannon"`
- `desc = "Fires a charged ice-plasma ball that explodes on impact and leaves a frozen patch of ice spikes that slows and damages everything on it."`
- Optional: `boon_name = "Cryo Vent"`. The boon effect stays unchanged.

"Cryo Cannon" sits close to the existing "Cryo Coil" (frost+tesla). An alternative is **"Rime Cannon"**. The files are named cryo_cannon_* either way; MergeArt finds them through the folder plus tower.json, not through the recipe name.

**The model.** The Plasma Cannon's real turret is the large, aiming part: its yaw ring, its gun body with the black radiator banks and the teal energy cell, and its cream barrel. The FRONT of the gun is the Frost Pylon's real crown, turned forward along the barrel axis to form the muzzle/emitter:
- the crystal spire in its cream frame
- the cross crystal arms with icicles, swept forward into four prongs
- the finial

A collar joins the crown to the barrel: a steel clamp ring, a cyan frost seam and a cream nozzle cone with 4 steel ribs. The ice-plasma ball charges at the crown's tip, inside the prongs. The pedestal is the slim Frost Pylon body: the real stepped cream pyramid with teal coolant pipes and magenta bands, on a small low plinth.

## Files → `godot/art_src/towers/merges/frost_plasma/`
```
cryo_cannon.glb, cryo_cannon.glb.import     model (textures embedded; the .import loops idle only)
cryo_cannon_accent_mask.png / _b.png        path-colour masks (A = frost, B = plasma; R trim, G glow, B detail)
tower.json
fx/cryo_cannon_fx.tscn  fx/cryo_cannon_fx.gd   2D board FX (class CryoCannonFX)
```
If v1 was copied in, delete these from that folder: `steam_engine.glb(.import)`, `steam_engine_accent_mask*.png(.import)` and `fx/steam_engine_fx.*`.

## Model
- 27,837 tris.
- 1.50 m tall (v1 was 2.05 m).
- The pedestal is 0.67 × 0.67 m, and its plinth is about 0.2 m tall.
- The turret spans 1.87 m from the crown tip to the radiators, at y ≈ 0.80–1.50 m.
- The crown is 0.60 m across its prongs (the barrel is 0.39 m across).

Node tree (Godot):
```
Base                                  frost pylon body (static, never keyed)
Turret                (yaw)           never keyed
  Head                                plasma yaw ring
  Gun                 (pitch, y 1.03) never keyed
    GunBody                           plasma gun: radiators, energy cell
      Barrel                          plasma barrel (recoils 6.5 cm)
        Collar                        steel clamp ring + frost seam + cream nozzle cone
        Crown                         frost crown turned forward (twists 28° while charging)
          CrownGlow
        Muzzle        (0.006, 1.184, 1.246 at rest; +Z = shot direction)
          PlasmaGlow, IceOrb, IceOrbCore, IceShell, FrostGlow, ChargeRing, ChargeRing2, ChargeShards, MuzzleFlash
BuffPoint             (y 1.601)
```
- **Aim:** `"yaw": "Turret"`, `"pitch": "Turret/Gun"`, `"aim": 0.06`. No clip keys Turret or Turret/Gun. Verified: yaw 1.2 and pitch 0.06 survive every clip.
- **Muzzle:** `"muzzle": "Muzzle"` is a node name for `find_child()`. It is the ball's centre at the crown tip.

| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | A small ice-plasma seed glows at the crown tip. The plasma glow and the frost halo breathe, and the crystal spire glows inside the crown frame. The frost shards orbit the tip slowly. |
| `fire` | 0.85 s | no | **Charge, 0–0.45 s:** the ice-plasma ball grows at the crown tip, inside the prongs. It has a white plasma core, a teal plasma glow and a faceted, spiky ice-blue crystal shell that turns as it grows. The two frost charge rings spin up and contract. The frost shards spiral in onto the ball. The crown prongs twist 28° like a chuck, the spire glows up and the gun body hums.<br>**SHOT at 0.45 s (`shot_time`):** the ball pops (the 2D ball takes over), with a muzzle flash and a shard burst. The crown snaps back and the barrel, collar and crown recoil 6.5 cm.<br>It ends on idle frame 0 (seam 5e-8). |
| `spawn` | 1.2 s | no | The yaw ring pops up, then the gun body, then the crown spins in a quarter turn and pops out with a bounce. The glows and the seed light up. It ends on idle frame 0. |

All 3 clips key the same 42 tracks. Base, Turret and Turret/Gun are not keyed.

## Attack: how it should WORK
Numbers marked **SUGGESTED** are proposals. Everything else is repo data.

The merged stats come from `try_merge` (hybrid):
- dmg = max(48, 12) × 1.5 = **72**
- rate = min(1.4, 0.9) = **0.9**
- range = min(165 × 1.1, 150 × 1.6) = **181.5**
- traits take the max: splash **50** (plasma), slow **0.45** (frost), slow_dur **1.6** (Tower default)

The steps:
1. **Aim and charge.**
   - Merge3D turns the turret toward the target.
   - `fire` plays and the shot is held until `shot_time` 0.45 (`Game.merge_lead`).
2. **The ice-plasma ball (shell).**
   - At 0.45 s, call `CryoCannonFX.shoot(Board.merge_muzzle(t), landing_board_px, flight, on_hit, power)`.
   - SUGGESTED speed is **650 board px/s** (tower.json `shell_speed`). It's a bit slower than SHOT_SPEED 800, so the ball reads; flight = distance / 650, about 0.15–0.3 s.
   - Lead the target like `lob_shell`: `lead = 0 if e.stun_t > 0 or e.blocked else e.speed * (1 - e.slow) * flight`, then `p = pos_at(min(path_len, e.d + lead))`.
   - Run the gameplay on the game's own `later(flight, ...)` (pause- and speed-safe), not on the FX callback.
3. **Icy plasma burst.**
   - Land on a fake spot `{x, y, d=-1, dead=false, fake=true}` through `_land(t, spot, d, 50, ...)`, as `land_shell` does.
   - Every enemy within 50 takes 72, and `apply_hit` slows each of them by 0.45 for 1.6 s.
   - The Plasma signature (Napalm Shells) still triggers its burning ground because `base_types()` has plasma.
   - Draw it with `fx.burst(p, 50, power)`.
4. **The frozen ice patch (new).** On landing, add a zone. The game already ticks `dps` and `slow` zones:
   ```gdscript
   var pz := zone({ x = spot.x, y = spot.y, r = t.splash * 0.9, t = t.slow_dur, dps = d * 0.2, slow = t.slow,
          end_dmg = d * 0.25, color = col(0xe0e6ff), src = t, quiet = true })
   ```
   - SUGGESTED values:
     - r = splash × 0.9 = **45**
     - t = slow_dur = **1.6 s** (tower.json `patch_time`, matching the Frost slow; the Plasma napalm ground lasts 2 s)
     - dps = **0.2 × d = 14.4/s** (napalm uses 0.25 × d; this is lower because the patch also slows)
     - slow = **t.slow (0.45)**. `slow_enemy(e, z.slow, 0.3)` runs every tick, so the slow lasts 0.3 s after an enemy steps off.
   - `quiet = true` stops the board drawing its default circle. Instead, draw `fx.patch(p, 45, 1.6, power)` and keep the id.
     - The FX grows the icy decal and sprouts the spikes over 0.3 s.
     - In the last 0.38 s the spikes shatter (shards fly) and the ice melts.
     - If the zone is removed early (run reset), call `fx.shatter(id)`.
   - **SUGGESTED, optional shard burst** when the patch ends: deal `end_dmg` (**0.25 × d = 18**) to enemies still inside. The zone loop does not know this key yet. Add it next to `end_freeze` in the zones loop of `game.gd`, and add `"end_dmg"` to the defaults list in `zone()`:
     ```gdscript
     if z.end_dmg and z.t <= 0:
         for e in in_range(z.x, z.y, z.r):
             damage(e, z.end_dmg, z.get("src"), 1)
     ```
     The FX emits `shattered(at, radius)` at the same moment. Don't use it for gameplay.
   - SUGGESTED (optional): `vuln = t.brittle` on the zone, so the Frost Brittle path also works on the ice.
   - At rate 0.9 and 1.6 s, at most 2 patches per tower overlap.
5. **SUGGESTED FX `power`:** `clamp(d / 72, 0.75, 1.5)`.

**Sanity check (SUGGESTED numbers):**
- Each enemy caught takes 72 from the burst, up to 14.4 × 1.6 ≈ 23 from the ice and 18 from the shatter: about 113 per shot, every 0.9 s.
- The hybrid line is dmg/rate = 72 / 0.9 = 80, under the 2.6 × (48 / 1.4) ≈ 89 hybrid DPS cap. The patch is extra area damage, like the napalm.
- Walking enemies leave the 45 px patch in about 1 s.
- If testing shows it's too strong, lower dps to 0.15 × d or drop `end_dmg`.

**Synergies to watch:**
- **Deep Freeze** (the Frost signature: slowed 3 s straight → frozen 1 s) will trigger often, because the patch plus repeated shots keep enemies slowed.
- **Frostfire** and **Brittle** stack with the patch.

## FX: `CryoCannonFX` (Node2D, `fx/cryo_cannon_fx.tscn`)
- **API:**
  - `shoot(from, to, flight := 0.25, on_hit := Callable(), power := 1.0)` draws the ice-plasma ball: a white core, a plasma-teal glow, a turning crystalline ice hexagon with six spikes and an ice-blue halo. It follows a short arc (bulge 10% of the distance) and leaves a frost-glitter and shard trail. It emits `hit(at)` and calls `on_hit` on arrival.
  - `burst(at, radius := 50, power := 1.0)` draws for 0.40 s: a white flash, plasma-teal and ice-blue ground rings (K 0.75), a starburst of 8 ice spikes along the ground and flying ice shards.
  - `patch(at, radius := 45, dur := 1.6, power := 1.0) -> int` draws the frozen ice patch:
    - an irregular icy decal with a frosty rim, crack lines and twinkling glitter
    - 8–14 upright ice spikes (lit and shaded faces with a white ridge, some with a side crystal) that sprout with a staggered bounce
    - in the last 0.38 s they shatter into flying shards while the decal melts away
  - `shatter(id)` breaks a patch now.
  - Signal `shattered(at, radius)`.
  - `busy()`; `tick(game_dt)`: after the first call, `_process` stops driving it, so it follows game speed and pause.
- Put one shared node on `board.top`. It has no "f" meta, so `_reap` leaves it alone. Positions are board px: convert with the board's SX()/SY(), like the other effects.

## tower.json
- `yaw "Turret"`, `pitch "Turret/Gun"`, `aim 0.06`, `muzzle "Muzzle"`, `buff_point "BuffPoint"`
- anims idle/fire/spawn, `fire_time 0.85`, `shot_time 0.45`
- `shell_speed 650` and `patch_time 1.6` (new keys, SUGGESTED), `fx "fx/cryo_cannon_fx.tscn"`
- `wide 40`. `_fit` measures the width with the gun facing the camera, so the longer gun does not shrink it.
- `size 160`, `foot [80,140]`, `out "cryo_cannon_3d"`
- Merge3D ignores the unknown keys.

## Verified headless (Godot 4.7.2; `source/godot_verify.log`)
- 0 import or verify errors. root_name is CryoCannon.
- Clips: fire 0.85 s (no loop), idle 4.0 s (loop), spawn 1.2 s, all with the same 42 tracks. Seams to idle frame 0: 5e-8 / 0 / 0.
- At 0.40 s: ice orb 0.82, plasma glow 0.88, ring 0.82, crown glow 1.59, crown twist 27.7°. At 0.50 s: ball gone, flash 0.88, shards bursting 1.09, barrel recoiled.
- The game's own merge_3d.gd:
  - `setup()` works: yaw is Turret, pitch is Turret/Gun, and the pitch rest is 0.06. It plays spawn, then idle. The box is (92, 102).
  - `muzzle_at` follows aim: aim right gives (37, −27); aim toward the camera gives (0, −6).
- The FX ran at power 0.75 / 1 / 1.5: hit → burst → patch → shattered, one patch alive at 1 s, all done at 1.95 s. `shatter()` finishes in 0.43 s.
- Rendered in-engine (xvfb, the Compatibility renderer) for `previews/cryo_cannon_attack_ingame.gif`.
