# Riftguard: Rift Beacon (aura / buff tower). Paste-ready notes for Claude

## Install
Copy into `godot/art_src/towers/rift_beacon/`:
| File | Notes |
|---|---|
| `rift_beacon.glb` (10.6 MB) | All textures are embedded: 2048² color (jpg), ORM (jpg), normal (jpg), and a new **emission** map (png). |
| `rift_beacon.glb.import` | Keep it next to the GLB **before** the first import. It sets fps=60, root name `RiftBeacon`, `idle` loop=Linear, `buff_pulse`/`spawn` no loop, and AnimationPlayer `import_tracks/* = 0` (IfPresent). The last one is required, see below. Godot adds the uid/dest lines itself. |
| `tower.json` | Modelled on `towers/shrine/tower.json` (`fire` → `buff_pulse`, muzzle `BuffPoint`, `out` `rift_beacon_3d`). Check its fields against what the tower loader/baker actually reads. `muzzle.json` isn't included; regenerate it the way the shrine's was made, if it's needed. |
| `fx/aura_ring.gdshader`, `fx/rift_beacon_visual.gd`, `fx/rift_beacon.tscn` | Optional visual wrapper: GLB, a ground aura ring that shows the buff radius, and helper functions. It uses `res://art_src/towers/rift_beacon/fx/...` paths, so if you move it, fix the 3 ext_resource paths. |

**Textures:** Godot won't overwrite textures it has already extracted. If an older `rift_beacon*` was ever imported, delete the extracted `rift_beacon_rift_beacon_{color,orm,normal}.jpg`, `rift_beacon_rift_beacon_emission.png` and their `.import` files, then reimport. Otherwise the old textures and missing emission will stick.

## What it is / what moves
Stone portal on a platform, a gyroscope-style ring in the middle and a magenta crystal on top.
- **Base** stays static: platform, pillars, consoles and the two short bars that reach from the pillars to the ring.
- **Rotor** (the "center ring") spins **horizontally**, around the vertical Y axis. It holds the cream outer ring, its two equator brackets, the top crown with the crystal, and the bottom post that sits on the round plinth. Everything on the Rotor is on its spin axis, so it turns in place.
- **InnerPivot / InnerRing** (the "inner metal ring") is the dark metal ring with cyan light strips. It's parented to the Rotor and spins **vertically**, around its local X axis (the horizontal axis through the brackets), like an armillary/gyroscope gimbal.
- **Glow:** the cyan strips (inner ring and consoles) and the magenta crystal/side strips are emissive through the emission texture, with energy 2.0. They light up without bloom and bloom well with WorldEnvironment glow.
- **Not gameplay:** no Yaw/Pitch, no aiming. Don't run turret aim, look_at or recoil code on it.

## Node tree (verified in Godot 4.7.2)
```
RiftBeacon (imported root)
├── Turret
│   ├── Base                  MeshInstance3D  21,999 tris (static)
│   ├── Rotor                 Node3D  pos (0, 1.0344, 0)  ← spins on Y
│   │   ├── OuterRing         MeshInstance3D   8,071 tris
│   │   ├── Crystal           MeshInstance3D     700 tris  pos (0, 0.7108, 0) (scale-pulsed in buff_pulse)
│   │   └── InnerPivot        Node3D  (0,0,0) ← spins on local X
│   │       └── InnerRing     MeshInstance3D   3,976 tris
│   ├── Glow                  Node3D  pos (0, 1.745, 0) (crystal centre, static)
│   │   ├── CoreGlow          magenta soft halo (alpha), breathes in idle
│   │   └── CoreFlash         bright flash sphere, rest scale 0.001
│   ├── beam_top              Node3D  pos (0, 1.8816, 0) (crystal tip; socket for beam/link FX)
│   │   └── BeamFlare         cyan vertical flare, rest scale 0.001
│   ├── BuffPoint             Node3D  pos (0, 1.8816, 0) (same spot, same name as the shrine's muzzle)
│   └── aura_center           Node3D  pos (0, 0.03, 0) (ground centre; socket for aura FX)
│       └── PulseRing         flat cyan ring, radius 1.0 at scale 1, rest scale 0.001
└── AnimationPlayer
```
- These are local positions. Use `global_position` after placing the tower.
- Units are metres, Y-up, origin at the bottom centre, front +Z.
- Size is 1.90 (X) × 1.87 (Y, crystal tip) × 1.38 (Z), close to the shrine's 1.68 × 1.90 × 1.49.
- Total body is 34,746 tris, plus 312 FX tris.

## Animations (60 fps)
| Clip | Length | Loop | Keys | What it does |
|---|---|---|---|---|
| `idle` | 4.0 s | Linear | Rotor rot, InnerPivot rot, CoreGlow scale | Rotor turns 360° about Y (**1 rev / 4 s**). InnerPivot turns 720° about X (**1 rev / 2 s**). The crystal halo breathes twice. The loop is seamless (t=4.0 is the same pose as t=0). |
| `buff_pulse` | 1.0 s | no | PulseRing, BeamFlare, CoreFlash, Crystal (scale only) | Aura tick: the ground ring expands 0.25→1.25 m and pops out at 0.84 s. A cyan flare shoots up from beam_top, the core flashes and the crystal swells 1.18×. Everything returns to rest by 1.0 s. **No ring rotation tracks**, so it can't snap the spin. |
| `spawn` | 1.2 s | no | Rotor scale/rot, InnerPivot rot, CoreGlow | Build-in: the rings grow 0.02→1 with an overshoot while spinning up, ending exactly on idle's first pose. Then the halo lights. Queue `idle` after it. |

Speeds: change them with `AnimationPlayer.speed_scale`, which scales both rings together. The ring ratio is fixed at 2:1 so the 4 s loop stays seamless. For independent speeds, drop `idle` and rotate the nodes in `_process` (`rotor.rotate_y(TAU/4.0*delta)`, `inner_pivot.rotate_x(TAU/2.5*delta)`).

### Why `import_tracks = IfPresent` matters
`idle` and `buff_pulse` animate **different** nodes, so they can run at the same time on two AnimationPlayers. That way the rings keep spinning while the pulse plays. With Godot's default (IfPresentForAll), every clip would get rest-value tracks for every animated node, and buff_pulse would freeze the rings. If that ever happens, the sidecar setting was lost. Reimport with the sidecar.

## Wiring (aura tower)
Like the shrine, it never aims. Buff radius, which towers it buffs, the tick rate and buff amounts are **game logic**. Placeholders:
```gdscript
const AURA_RADIUS := 0.0      # TODO user: buff radius (world units / tiles)
const TICK_SECONDS := 0.0     # TODO user: how often the aura applies/refreshes
const BUFF := {}              # TODO user: e.g. {"damage_mult": ?, "fire_rate_mult": ?, "range_mult": ?}
```

Option A uses the wrapper (`fx/rift_beacon.tscn`, script `RiftBeaconVisual`):
```gdscript
var vis: RiftBeaconVisual = preload("res://art_src/towers/rift_beacon/fx/rift_beacon.tscn").instantiate()
add_child(vis)                 # or StyleRig.add_model(vis, 0.6) for the unified 3D style + contact shadow
vis.aura_radius = AURA_RADIUS  # resizes the ground ring decal (PlaneMesh 2r×2r)
vis.play_spawn()               # spawn → idle; or vis.play_idle()
# each aura tick (after the game applies the buff):
vis.buff_pulse()               # FX clip on a 2nd AnimationPlayer + spin burst (speed_scale 1→3→1) + aura wave
vis.show_aura = true           # e.g. only while selected / placing, if that's the game's rule
```

Option B is plain GLB wiring:
```gdscript
var visual := preload("res://art_src/towers/rift_beacon/rift_beacon.glb").instantiate()
add_child(visual)
var anim: AnimationPlayer = visual.get_node("AnimationPlayer")
anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
anim.play("spawn"); anim.queue("idle")     # idle must keep playing for the tower's whole life
var fx := AnimationPlayer.new(); visual.add_child(fx)
fx.add_animation_library("", anim.get_animation_library(""))
func on_aura_tick() -> void:
	fx.stop(); fx.play("buff_pulse")
	var t := create_tween()                 # optional spin burst
	t.tween_property(anim, "speed_scale", 3.0, 0.12)
	t.tween_property(anim, "speed_scale", 1.0, 0.75)
var aura_center: Node3D = visual.get_node("Turret/aura_center")  # ground FX / range ring here
var beam_top: Node3D = visual.get_node("Turret/beam_top")        # e.g. thin beams to each buffed tower
```
Don't play `buff_pulse` on the main player. That would stop `idle`, and the rings would freeze.

- **Buff link idea (optional):** draw a short-lived line or beam from `beam_top.global_position` to each buffed tower, cyan `#5ff0ff`.

## Aura ring shader (`fx/aura_ring.gdshader`)
- Unshaded, additive ground decal on a PlaneMesh sized 2r × 2r, at y = 0.02.
- It has a bright cyan edge at the radius, a faint magenta fill and slow outward ripples.
- Setting `pulse_t` from 0 to 1 sends one bright wave to the edge. The wrapper tweens it over 0.8 s on `buff_pulse()`.
- Uniforms: `edge_color`, `fill_color`, `edge_width`, `fill_alpha`, `ripple_count`, `ripple_speed`, `ripple_strength`, `pulse_strength`, `pulse_width`, `intensity` (master fade).
- It's separate from the GLB's own `PulseRing`, which is a fixed ~1.25 m flourish under the tower, not the radius indicator.

## Unified 3D style (StyleRig)
- `StyleRig.add_model()` / `style_node()` turns the opaque `RiftBeacon_Mat` into the toon material and carries the emission texture and energy over (`_toon_from` already copies `emission_tex`).
- The FX materials (`FX_*`) are alpha-blended, so StyleRig leaves them as they are and they don't get the toon material.
- If outlines show around the FX spheres, skip MeshInstances whose material name starts with `FX_`.
- If the toon palette dulls the cyan or magenta, raise `keep_accents` or add a per-tower `style_overrides` like Gale's.
- Turn off shadow casting for the FX nodes if their shadows look wrong.

## Verification done (Godot 4.7.2 headless)
- The import succeeded, and the node tree above was confirmed.
- `idle` is 4.0 s, LOOP_LINEAR, 3 tracks. `buff_pulse` is 1.0 s with 4 scale tracks. `spawn` is 1.2 s.
- Sampled through `idle`: Rotor only changes rotation.y (0/45/90/135/180… → 0 at 4 s) and InnerPivot only changes rotation.x (0/90/180/270 → 0).
- Both ring meshes are centred on their pivots: AABB centre offset is ≤ 2.4 mm off-axis, so they don't wobble.
- Running two players (idle + buff_pulse) together left the rotor spinning while the pulse animated.
- All 4 FX are back to 0.001 at the end of buff_pulse.
- `spawn` ends at Rotor scale 1, rotation 0.
- The body materials have emission on with the emission texture at energy 2.0.
- The wrapper `.tscn` loads.

## Known limits / judgement calls
- **The source was one merged Meshy mesh** (543,648 tris, 1,755 fragments). I split it by geometry, using the ring centre (0, 1.0344, 0) and radius bands: inner ring r 0.35–0.43 m, outer ring r 0.43–0.56 m.
  - The inner/outer boundary follows Meshy's triangles, so a few mm of jaggedness sits in the step between the rings.
- **Gyroscope reading:** "center ring spins horizontally" = cream ring about vertical Y, and "inner metal ring spins vertically" = dark cyan-lit ring tumbling on X inside it.
  - For a plain in-plane "stargate" spin instead, rotate `InnerPivot` around its local **Z** (the ring's facing axis).
- **Hidden parts Meshy never modelled:**
  - The inner ring had gaps behind the crown, the post and the two brackets. I filled them with plain navy arc segments (no cyan strip), which only show while it tumbles.
  - The crown underside and the post top were cut flat at r 0.445 m and capped, so the tumbling inner ring (r ≤ 0.426 m after a 0.985 shrink) never clips.
- **Bars at rest:** the two short bars from the pillars stay static and line up with the ring brackets only at rest (every half turn of the Rotor). In between they point at empty air.
- **Glow detection:** the emission map was made automatically (cyan and magenta hue mask of the Meshy albedo). A few small cyan or magenta specks elsewhere may glow faintly.
- **Previews:** Blender Cycles with fog glow. In-game look depends on StyleRig and WorldEnvironment glow.
