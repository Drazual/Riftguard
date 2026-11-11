# Railgun v2 merge tower (Arcane Bolt + Tesla Coil): integration notes for Claude

This is the test model for the path-color merge system. The recipe is `arcane` + `tesla` → **Railgun**, with recipe color `#8AFFFF`.
v2 is a redesign. The gun is the main shape: a long twin-rail gun on a chunky yaw/pitch mount sitting on a low pedestal. The Tesla Coil parts are only decorations: coil rings, insulators, electrodes and flank emitters. The Arcane Bolt parts are the gun's identity: a magenta crystal energy core in the breech, swept rune petals on the receiver and magenta rail emitters. (v1 is kept in `final_v1/` but has been rejected.)

## Where it goes
Copy everything to **`godot/art_src/towers/merges/arcane_tesla/`**:
```
railgun.glb                 game asset (Y-up, meters, 2048 atlas embedded, 3 clips)
railgun.glb.import          import settings. Keep it next to the glb (see below).
railgun_accent_mask.png     parent A (Arcane) accent mask, same UV as the atlas
railgun_accent_mask_b.png   parent B (Tesla)  accent mask, same UV as the atlas
textures/railgun_{color,normal,orm,emission}.png   loose copies of the embedded atlas
tower.json                  suggested descriptor. Check it against the real loader; the field names are a guess.
```
(Only in the full delivery zip: `previews/` and `source/`, which holds the packed .blend and the build scripts.)

**Godot does not overwrite textures it already extracted from a GLB.** If any older `railgun.glb` (v1) was imported, delete the extracted `railgun_railgun_{color,normal,orm,emission}.png` and their `.import` files next to it, plus `.godot/imported/railgun*`, before re-importing. Otherwise the old v1 atlas sticks. v2 uses a completely different UV layout, so a stale atlas will look scrambled.
The masks are **not** inside the GLB. Load them as `Texture2D` and sample them as data, without the `source_color` hint. Import them Lossless (`compress/mode=0`, which is Godot's default for these, verified) so the channels don't bleed into each other.

## Node tree (Godot names)
```
Railgun (root)                               origin = bottom center of the pedestal, front = +Z
├─ Base            MeshInstance3D  static    low pedestal: slab + chamfered tier + mount drum + 4 corner insulator nubs (7.1k tris)
│  ├─ CoilRing2    floating coil ring around the pedestal (idle: slow turn + pulse)
│  └─ CoreRing     glowing ring at the turret seat (the shared "core" glow)
├─ Turret          Node3D  YAW PIVOT  pos (0, 0.445, 0). Code owns rotation.y; no clip keys it.
│  ├─ Yoke         MeshInstance3D  turntable + two trunnion cheeks (1.8k), yaws with Turret
│  └─ Gun          Node3D  PITCH PIVOT  pos (0, 0.475, -0.06) → global (0, 0.92, -0.06), trunnion axis = X.
│     │                  Code owns rotation.x; no clip keys it.
│     ├─ Receiver  MeshInstance3D  breech block, rune petals, flank coil emitters, arcane housing + magenta crystal core (6.5k)
│     │  └─ CoreGlow   FX haze around the crystal (breathes in idle, flares on fire)
│     └─ Barrel    MeshInstance3D  twin rails + rail electrodes (5.7k), pos (0, 0.01, 0.24); recoils along local -Z
│        ├─ CoilRing0, CoilRing1   floating coil rings around the rails (turn about the barrel axis)
│        ├─ RailArc0..2            FX lightning between the electrode pairs (0 = rearmost), hidden at rest
│        ├─ ChargeBeam             FX beam between the rails, hidden at rest
│        └─ Muzzle  Node3D  rail tip, identity rotation, forward = +Z. Rest global (0, 0.93, 1.08)
│           ├─ MuzzleGlow  FX sphere (scale 0.01 at rest)
│           └─ MuzzleFlash FX star (scale 0.001 at rest)
├─ BuffPoint       Node3D  (0, 1.473, 0)  10 cm above the top of the gun, static (doesn't yaw). Anchor for buff icons/VFX.
└─ AnimationPlayer
```
### Aiming
- **Yaw:** `turret.rotation.y = atan2(d.x, d.z)`, where `d = target - turret.global_position` in the tower's local space. Positive turns counter-clockwise seen from above. Full 360°. Don't use plain `look_at()`, which points -Z.
- **Pitch:** `gun.rotation.x`, where **negative = muzzle up**, the same convention as Arcane Bolt. Rest is 0, which is level. Verified: rotation.x = -10° gives muzzle direction (0, 0.174, 0.985). The rails are clean from **-20° (up) to +12° (down)**, as checked in the contact-sheet renders. For a top-down tower defense, leaving pitch at 0 (or a small lean toward the target) reads best.
- `muzzle.global_basis.z` is the shot direction. Spawn slugs or beams at `muzzle.global_position`.

## Proportions
- Height 1.37 m. The pedestal and drum go up to the yaw seat at 0.445 m (**32%**). The yoke, receiver and rails above that make up the rest.
- Pedestal footprint 1.04 × 1.04 m. CoilRing2 reaches 0.58 m from center.
- Gun: the breech cap sits 0.60 m behind the axis and the rail tips reach **1.04 m** in front (muzzle 1.08 m), so the gun is **1.64 m long**. The rails are 0.86 m long, 0.075 × 0.17 m in cross-section, with a 0.23 m gap between them. The receiver is 0.40 × 0.76 × 0.33 m.
- Same units as the parents (meters, unscaled). The model is shorter than either parent (1.98 / 1.92 m) but longer at the gun.

## Clips (60 fps)
| clip | length | loop | what |
|---|---|---|---|
| `idle` | 4.0 s | yes | barrel coil rings turn ±90° per loop and the pedestal ring turns 45° per loop (all 8-fold symmetric, so the loop is seamless). Each ring pulses ±5%. The core ring breathes. The crystal haze (CoreGlow) breathes. Three short electrode arcs flicker (t = 0.9 s, 2.2 s, 3.3 s). |
| `fire` | 0.6 s | no | 0–0.22 s charge: the barrel rings spin up and swell, electrode arcs fire rear to front, the charge beam grows between the rails, the crystal flares and the muzzle glow builds. **Shot frame t = 0.22 s** (spawn the projectile then). Then the flash fires, the barrel recoils **8 cm** and the receiver kicks 1.5 cm back, and everything settles by 0.6 s. The rings finish a full turn. |
| `spawn` | 1.2 s | no | 0–0.45 s: the yoke rises out of the drum while the pedestal ring and core ring ignite. 0.30–0.75 s: the receiver drops in from 0.5 m above with an overshoot. 0.62–1.0 s: the barrel slides forward out of the breech. 0.85–1.2 s: the barrel rings spin up and the crystal lights. There's a muzzle blink at 1.08 s. **It ends exactly on idle's first pose** (verified, difference 0.0). |

**All three clips key the same 42 channels** on 14 nodes, holding constant values wherever a clip doesn't move something. This is because Godot 4's deterministic AnimationMixer resets un-keyed channels to 0 or identity, which would otherwise drop rings and parts to the origin. **`Turret` and `Gun` appear in no clip**, so code-driven yaw and pitch are never overwritten. Verified: yaw 1.0 rad and pitch -10° both survive idle, spawn and fire. Resume `idle` after `fire` or `spawn` finishes.

```gdscript
@onready var anim: AnimationPlayer = $Railgun/AnimationPlayer
@onready var turret: Node3D = $Railgun/Turret
@onready var gun: Node3D = $Railgun/Turret/Gun          # pitch (rotation.x, negative = up)
@onready var muzzle: Node3D = $Railgun/Turret/Gun/Barrel/Muzzle
const SHOT_TIME := 0.22

func _ready() -> void:
	anim.play("spawn")
	anim.animation_finished.connect(func(n): if n != "idle": anim.play("idle"))

func aim(target: Vector3, delta: float) -> void:
	var d := turret.get_parent().to_local(target) - turret.position
	turret.rotation.y = lerp_angle(turret.rotation.y, atan2(d.x, d.z), 1.0 - exp(-10.0 * delta))

func shoot(target: Vector3) -> void:
	anim.stop(); anim.play("fire")
	await get_tree().create_timer(SHOT_TIME / anim.speed_scale).timeout
	spawn_slug(muzzle.global_position, muzzle.global_basis.z)
```

## Import settings (`railgun.glb.import`)
- `animation/fps=60`. `idle` has loop_mode 1. The AnimationPlayer uses `import_tracks/* = 0` (IfPresent).
- **`animation/remove_immutable_tracks=false`** is required. Otherwise Godot deletes the constant hold channels described above.
- `nodes/root_name="Railgun"`.
- Verified headless in Godot 4.7.2: no import errors or warnings, clips idle 4.0 s (looping) / fire 0.6 s / spawn 1.2 s with 42 tracks each, 23,400 tris total.

## Materials
- `railgun_mat` is one material shared by Base, CoilRing0-2, CoreRing, Yoke, Receiver and Barrel. It uses a 2048² atlas: albedo (sRGB), normal (OpenGL tangent), ORM (R=1, G=roughness, B=metallic) and an emission texture at energy 3.
- The effect materials are emissive with no textures:

| Material | Color | Alpha |
|---|---|---|
| `CoreGlow_mat` | #FF6FD0 | yes |
| `MuzzleGlow_mat` | #C8FFFF | no |
| `MuzzleFlash_mat` | #FF4FC0 | yes |
| `RailArc_mat` | #BFF6FF | no |
| `ChargeBeam_mat` | #FF8FE0 | yes |

  Tint them from code if the effects should follow the path colors (make the material unique per tower first).

## Accent masks: path-color recolor
Both masks are 2048² RGB in the same UV (TEXCOORD_0) as the atlas. Path order: **R = 1st path → main trim, G = 2nd path → glow (emissive), B = 3rd path → small details.**

| | parent A `railgun_accent_mask.png` (Arcane = the gun) | parent B `railgun_accent_mask_b.png` (Tesla = decorations) |
|---|---|---|
| R trim | teal trim stripes on the receiver sides and breech cap, rune-petal edges, the rails' outer trim lines and collars, the yoke turntable ring, the arcane housing's teal parts | a thin trim band around the pedestal slab, plus the outer face of each of the 3 coil rings (kept modest on purpose) |
| G glow | magenta crystal core, rune lines on the petals, the rails' inner emitter strips, the rear rune light | glow notches on the 3 coil rings, electrode balls, flank-emitter balls, the pedestal's vent lights |
| B details | rail tip prongs, trunnion hub caps, small cyan bits on the arcane housing | electrode and emitter insulator caps, corner-nub caps, pedestal side stripes |
| shared | **CoreRing (turret seat) is in G of both masks**. Blend the two G colors there. | same |

There is no other overlap: checked per pixel, 0 overlapping pixels in R and B, and G overlaps only on CoreRing. Atlas coverage is A R/G/B ≈ 5.5 / 4.6 / 1.2 % and B R/G/B ≈ 1.9 / 4.2 / 0.6 %. The masks are slightly soft (0.7 px blur) to avoid aliasing.
Unmasked areas are plain body albedo (navy metal, cream armor, copper coil wire). Tint them lightly with the recipe color.

Reference shader logic, the same as used for `previews/railgun_recolor_demo.png`:
```glsl
vec3 base = texture(albedo_tex, UV).rgb;              // albedo_tex : source_color
vec4 a = texture(mask_a, UV);  vec4 b = texture(mask_b, UV);   // data, no source_color
float sh = 0.30 + 1.25 * dot(base, vec3(0.2126, 0.7152, 0.0722));
vec3 c = mix(base, base * recipe_color, 0.2);
c = mix(c, a_trim * sh, a.r);   c = mix(c, b_trim * sh, b.r);
c = mix(c, a_detail * sh, a.b); c = mix(c, b_detail * sh, b.b);
c = mix(c, a_glow * sh, a.g);   c = mix(c, b_glow * sh, b.g * (1.0 - 0.5 * a.g));   // core = 50/50
ALBEDO = c;
EMISSION = (a.g * a_glow + b.g * b_glow) * glow_energy;   // replaces the baked emission
```
Path colors: power #FF4A4A, speed #FFD84A, burst #FF8A2E, burn #FF5A1F, slow #6EC8FF, chain #3CF0FF, precision #E6D8FF, arcane #FF4FC0, multi #6CF07A. For two paths of the same type, the demo uses a "-light" shade (50% toward white) and a "-dark" shade (×0.55).
Prefer putting the mask math inside StyleRig's toon shader, with one material per tower instance and the 6 path colors plus the recipe color as instance uniforms. Render the model live like the other towers; don't bake sprites.

## Paste-ready note for Claude
> New merge tower model: Railgun v2 (arcane + tesla), recipe #8AFFFF, in `godot/art_src/towers/merges/arcane_tesla/` (follow `CLAUDE_NOTES.md` there). It replaces any earlier railgun.glb, so delete old extracted `railgun_railgun_*.png` textures and the `.godot/imported/railgun*` cache first. Keep `railgun.glb.import` next to the glb (fps 60, idle loops, import_tracks IfPresent, **remove_immutable_tracks=false**). Nodes: `Base` (static), `Turret` (yaw = rotation.y), `Turret/Gun` (pitch = rotation.x, negative = up, rest 0 = level, clean -20°..+12°). No clip keys Turret or Gun. Shots spawn at `Turret/Gun/Barrel/Muzzle` (forward +Z, global (0, 0.93, 1.08) at rest). `BuffPoint` sits on top. Clips: `spawn` 1.2 s, then loop `idle` 4.0 s; `fire` 0.6 s with the shot at t = 0.22 s, then resume idle. Recolor: `railgun_accent_mask.png` (A = Arcane, on the gun) and `railgun_accent_mask_b.png` (B = Tesla, on the decorations), same UV as the atlas. R = 1st path (trim), G = 2nd path (glow/emission), B = 3rd path (details). CoreRing is in both G channels (blend 50/50). Unmasked body gets a light recipe tint. Render it live through StyleRig, no sprite baking.
