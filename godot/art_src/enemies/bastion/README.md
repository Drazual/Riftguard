# Bastion

A heavy armoured knuckle-walker, set up in the same format as `rift_prowler` and `wraith`. It's made to be drawn for the **Bastion** (`data/enemies/bastion.tres`, formerly the Juggernaut: radius 16, speed 26).

- **`bastion.glb`** is 4.0 MB, with 20,000 triangles (the upload had 1.75M) and 20 bones. Textures are PNG: colour 1024, normal and metal/rough 512. It faces glTF +Z like the prowler, its soles sit on the origin, and the mesh is 1.653 tall.
- **Bones:**
  - Root, Hips, Spine, Chest, Neck, Head
  - for each side: Shoulder (clavicle), UpperArm, ForeArm, Hand (fist), Thigh, Shin, Foot
- **Size:** `height` 0.8 × clamp(16/9) gives 1.42 m on the board, about 29 px wide, so it fits its radius-16 footprint.
- **Speed:** `walk_speed` 26 is the Bastion's speed, so `move` plays at 1×.
- **Planted contacts:** the stride is built for exactly that scale and speed, which keeps the fists and feet locked to the ground. If you change `height` (or use it for an enemy with a different radius), scale `walk_speed` the same way: `walk_speed = 26 × (height / 0.8) × (clamp(r/9, 0.6, 2.5) / 1.778)`.

| clip | length | notes |
|---|---|---|
| move | 0.667 s loop | Diagonal-sequence knuckle-walk (left foot, right fist, right foot, left fist). Each contact is placed by IK and stays planted while down. Measured slide: feet ≤ 0.0008 and fists ≤ 0.0016 native/frame, against a 0.051 stride speed. The body drops onto each fist plant. Fine at 0.5×. |
| slowed | 1.0 s loop | Lower and heavier: shallow dragging steps, shivering, head shaking off the cold. Its stride matches a **35% slow** (`slowed_for` in enemy.json). |
| idle | 2.0 s loop | Heavy breathing, looking around, all four contacts planted. |
| stun | 1.4 s loop | Dazed circular sway on locked limbs, head lolling. |
| frozen | 1.0 s | Braced mid-flinch. |
| knockback | 0.7 s | Rocks back, fists torn off the ground, then slams back down. |
| attack | 0.9 s | Rears up and ground-pounds with both fists; impact at 0.45 s. |
| hit | 0.3 s | Heavy flinch. |
| spawn | 0.9 s | Grows out of the rift in a short hop, lands in a crouch and roars. |
| death | 1.8 s | Rocked back, staggers, knees buckle, crashes forward onto its chest with arms splayed. It ends low and flat for the game's hold, sink and fade. |

To rebuild with Blender 4.2:

```
blender -b --factory-startup -P rig_bastion.py -- bastion_src.glb rigged.blend
blender -b --factory-startup -P anim_bastion.py -- rigged.blend bastion_raw.glb
python3 glb_textures.py bastion_raw.glb bastion.glb
```
