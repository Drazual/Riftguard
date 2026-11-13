# Rimeshard (Arcane Bolt + Frost Pylon): integration notes for Claude

Recipe `arcane+frost`, data name **"Rimeshard"**, recipe color #C9B8FF (`data/recipes.tres`). Boon "Frostbitten Strikes" is unchanged.

**v2 (this version):** the crystal stands upright and spins in place. The tower does **not** aim (like Cryo Coil). It is 1.61 m tall (v1 was a tilted, aiming 2.1 m tower).

**The model.** The Frost Pylon's real ice crystal and crown stands **vertical** and rises straight out of the Arcane Bolt's round collar ring. Three real Arcane stone petals hold it: the right petal, its mirror and a copy at the back, spaced around the crystal and leaning in slightly. (The v1 hood petal and the tilted hub were removed because they only fit a tilted crystal.) The base is the slim Arcane Bolt column on its small low plinth, with three small frost crystal clusters on its sides.

## Files → `godot/art_src/towers/merges/arcane_frost/`
```
rimeshard.glb, rimeshard.glb.import       model (textures embedded; the .import loops idle only)
rimeshard_accent_mask.png / _b.png        path-colour masks (A = arcane, B = frost; R trim, G glow, B detail)
tower.json
fx/rimeshard_fx.tscn  fx/rimeshard_fx.gd   2D board FX (class RimeshardFX), unchanged from v1
```
Replacing v1: delete the old files in that folder and `godot/.godot/imported/rimeshard*`, then reimport. The file names are the same.

## Model
- 19,820 tris (v1 was 24,648).
- **1.61 m tall** to the crown tip (Cryo Cannon is 1.50 m); the Muzzle is at 1.64 m. The column and plinth are 0.63 × 0.63 m, the collar is at 0.83 m and the petals span 0.78 m.
- Static; there is no pitch node at all.

Node tree (Godot):
```
Base                                  arcane column + plinth (static, never keyed)
  FrostBits                           small frost crystal clusters (spawn pop only)
Turret                                static container (NOT a yaw node; never keyed)
  Head                                arcane collar ring
    PetalL, PetalR, PetalB            3 arcane petals round the crystal (open about 11° outward while firing)
  Mount                               static, vertical
    Crystal                           SPIN NODE: the Frost Pylon crystal + crown, spins about its vertical axis
      CrystalGlow
    Runes                             3 magenta arcane motes orbiting the crystal
    ChargeShards                      the pylon's charge shards orbiting the crystal
    Muzzle            (0, 1.644, 0) at rest; the crystal tip
      TipFlash, ChargeHalo, Shard, MuzzleFlash, HeatGlow (HeatGlow is NOT keyed: code drives it)
BuffPoint             (y 1.714)
```
- **No aim:** `"yaw": "-"`, `"pitch": "-"`, no `"aim"` key, `"dirs": 1` (like Cryo Coil). Merge3D gets no yaw or pitch node, and `muzzle_at()` stays (0, −42) whatever it is told to aim at. The shards fly from the crystal tip to every target.
- **Muzzle:** `"muzzle": "Muzzle"` (a node name for `find_child()`).
- **Spin:** `Crystal` is its own node and is keyed in every clip. Verified: its axis stays exactly vertical through every clip.

| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | The crystal turns slowly (1 turn per 4 s = 0.25 turns/s). The runes counter-turn, the charge shards orbit, the glow breathes and the petals sway. |
| `fire` | 0.45 s | no | **Quick charge, 0–0.18 s:** the tip flashes magenta, a lilac halo grows, a small ice shard forms at the tip and the petals open 11°.<br>**SHOT at 0.18 s (`shot_time`):** the shard leaves (the 2D shards take over) with a muzzle flash.<br>The crystal spins exactly **2 turns** in the clip (4.44 turns/s). It ends on idle frame 0 (seam 7e-7). |
| `spawn` | 1.2 s | no | The frost bits pop up, then the head (each petal swings in from 35° open), then the crystal pops in spinning 1.5 turns. It ends on idle frame 0. |

- All 3 clips key the same 39 tracks. Base, Turret and Mount are not keyed.
- The fire clip (0.45 s) is shorter than the 0.5 s rate, so sustained fire reads as a constant fast spin.
- **The glow grows during sustained fire:** this is the unkeyed `HeatGlow` at the tip (rest scale 0.001), driven from code.

## Attack: how it should WORK
Numbers marked **SUGGESTED** are proposals. Everything else is repo data.

The merged stats come from `try_merge` (hybrid):
- dmg = max(28, 12) × 1.5 = **42**
- rate = min(0.5, 0.9) = **0.5**
- range = min(180 × 1.1, 150 × 1.6) = **198**
- traits take the max: slow **0.45**, slow_dur **1.6** (frost)
- DPS cap = 2.6 × max(28 / 0.5, 12 / 0.9) = 2.6 × 56 = **145.6**. 42 / 0.5 = 84, so the cap doesn't bite.

The steps:
1. **Multi-target volley.** The tower loop already does `targets.slice(0, 1 + int(t.multi))`. Rimeshard starts at `multi = 2` (**3 targets**).
   - If there are fewer enemies than shards, the extra shards double up on the front-most enemies (max 2 shards per enemy).
2. **Damage split (SUGGESTED).** The volley's total is `d × (1.65 + 0.20 × (shards − 3))`, split evenly across the shards:
   - 3 shards: 0.55 × d each (23.1)
   - 4 shards: 0.4625 × d each
   - 5 shards: 0.41 × d each
   - 6 shards: 0.375 × d each
   - One shard on each of 3 enemies is 69.3 per volley = 138.6 dps total, **under the 145.6 cap even if you add the targets together**. One enemy alone takes 2 shards = 46.2 per volley = 92.4 dps.
3. **Charge and flight.** `merge_lead` already holds the shot until `shot_time` 0.18. Then each shard flies at **1100 board px/s** (tower.json `shard_speed`, SUGGESTED). Flight is about 0.1–0.18 s, so land each hit with `later(flight, ...)`.
4. **Rime stacks (new).** Each shard hit slows (the normal `apply_hit` slow) and adds **+1 rime** to that enemy, up to **5** (`rime_max`).
   - Rime clears **3 s** after the last hit (`rime_decay`).
5. **Freeze and shatter.** At 5 stacks the enemy freezes for **0.6 s** (`freeze_time`; bosses 0.3×, like `freeze_for`).
   - The freeze uses `stun_t`, so the Shatter fusion's +dmg works on it.
   - When the freeze ends it **SHATTERS**: a bonus hit of **1.2 × d (50.4)**. Its rime resets to 0.
   - It also sends **3 arcane splinters** (520 px/s) to the nearest enemies within **90 px** (the same radius Prism Split and the lance sparks use). Each splinter deals **0.25 × d (10.5)** and adds +1 rime.
   - A splinter does nothing to an enemy that is already frozen.
6. **Upgrade hook (new fusion).** "Splintering Volley" (`splinter`) is always one of Rimeshard's 5 fusion paths. Each point gives `t.multi = min(5, t.multi + 1)`, so the volley grows 3 → 4 → 5 → 6 targets.
   - The 4th point only gives the normal +8% damage (and the usual per-level 1.05×).
   - It never shows up for other recipes.

**Sanity check (SUGGESTED numbers):**
- An enemy that keeps getting hit takes 5 × 23.1 + 50.4 = 166 every 2.5 s, which is **66 dps per enemy**. That's under the merge's own 84 single-target line.
- With 3 targets plus splinters, the total is about 200–235 dps. A normal multi-2 tower would deal 3 × 84 = 252.
- Enemies that die in under 5 hits never shatter, so it's strongest against tanky waves.
- If it's too strong, lower the shatter to 1.0 × d or use 2 splinters.

## FX: `RimeshardFX` (Node2D, `fx/rimeshard_fx.tscn`, on board.top, tick(game_dt))
- **API:**
  - `shoot(from, to, flight, on_hit, power)` draws one thin, fast ice shard (pale ice diamond with a white core line) with a twisting magenta + ice-blue trail (55 ms long, time-based). It makes a small ice-chip puff on arrival. Call it once per shard.
  - `volley(from, tos, speed := 1100, on_hit(i, at), power)` is a convenience for a whole volley.
  - `rime(id, at, stacks, radius)` draws frost creeping over an enemy: a pale crystal crust rising from the feet with stacks/5, little ice spikes poking out, one lilac pip per stack over the head, and a magenta pulse at 4 stacks.
    - `at` is the point under the body; the body centre is `at − (0, radius)`.
    - Call it every frame while the enemy has rime. An id not refreshed for 0.25 s fades out by itself.
  - `freeze(id, at, dur, radius)` draws a faceted ice block around the enemy. Magenta cracks spread over the last 40%.
  - `shatter(at, radius, power, tos, on_splinter(i, at), id)` draws a white + magenta flash, ice and magenta rings, a star of 6 ice spikes and flying chunks. One small magenta splinter hops to each point in `tos`. It clears that id's rime overlay.
  - `busy()`; `tick(game_dt)`: after the first call, `_process` stops driving it.
- Use one shared node on `board.top`, like `lance_sparks`. Positions are board px, so use `SY()` and `body_lift()`, like `_sync_lance_sparks`.
- The FX callbacks are visual only. Run the gameplay on `later()`.

## tower.json
- `yaw "-"`, `pitch "-"` (no aim, no "aim" key), `dirs 1`, `muzzle "Muzzle"`, `buff_point "BuffPoint"`
- anims idle/fire/spawn, `fire_time 0.45`, `shot_time 0.18`, `fx "fx/rimeshard_fx.tscn"`
- New keys (SUGGESTED; Merge3D ignores them): `shard_speed 1100`, `spin_node "Crystal"`, `heat_node "HeatGlow"`, `rime_max 5`, `rime_decay 3.0`, `freeze_time 0.6`
- `wide 49`. With no yaw node, Merge3D measures the whole model's width (0.78 m across the petals), so 49 keeps v1's board pixels per metre.
- `size 160`, `foot [80,140]`, `out "rimeshard_3d"`

## Verified headless (Godot 4.7.2; `source/godot_verify.log`)
- 0 import or verify errors. root_name is Rimeshard.
- Clips: fire 0.45 s (no loop), idle 4.0 s (loop), spawn 1.2 s, all with the same 39 tracks. Seams to idle frame 0: 7e-7 / 0 / 0.
- No Turret, Mount or Base keys; there is no Gun node. The crystal axis is vertical in every clip.
- Spin: idle 1.00 turn (0.25/s), fire 2.00 turns (4.44/s). HeatGlow is not keyed.
- The repo's current `scripts/board/merge_3d.gd`: `setup()` works with yaw and pitch null, plays spawn then idle, and the box is (47, 84). `muzzle_at` is (0, −42.4) at rest and after aim calls.
- FX: a 3-shard volley lands all 3 hits in 0.22 s. 5 rime → freeze 0.6 s → shatter with 3 splinters. Everything is done by 0.48 s.
- Rendered in-engine for `previews/rimeshard_attack_ingame.gif`: the shards leave the upright crystal's tip toward 3 targets, then rime, freeze, shatter and splinters.
