# Wraith

Floating enemy model for `data/enemies/wraith.tres`, in the same format as `rift_prowler`.

- `wraith.glb` is 3.8 MB: 14,000 tris, 33 bones, PNG textures (colour 1024, normal and metal/rough 512). It faces glTF +Z, like the prowler.
- The mesh is 1.74 tall (native). Its origin sits on the ground, 0.2 below the tail tip, so it hovers on its own with no code needed (about 0.18 m in game).
- Bones:
  - Root, Hips, Spine, Chest, Neck, Head
  - Hair1-3
  - Tail1-7 (robe/tail)
  - Shoulder/UpperArm/ForeArm/Hand .L/.R
  - Ribbon1-3 .L/.R (the trailing arm ribbons)
  - Crystal1-3 (the floating shards)
- Clips are at 30 fps and all start at t=0:

| clip | length | notes |
|---|---|---|
| idle | 2.0 s loop | hover bob, tail sway |
| move | 1.2 s loop | forward-leaning drift, tail and ribbons trail. Every channel is a whole-cycle sine, so it stays seamless at any rate (fine at 0.5x). |
| slowed | 1.6 s loop | heavy, low, labouring surge. Arms shiver and the head shakes (frost struggle). |
| stun | 1.4 s loop | |
| frozen | 1.0 s loop | almost still |
| knockback | 0.7 s | |
| attack | 0.9 s | claw lunge |
| hit | 0.3 s | optional flinch (not used by the code yet) |
| spawn | 0.9 s | optional: Root scales 0.05 to 1 and unfurls (not used yet) |
| death | 1.5 s | recoil, writhing rise, then collapse and shrink. The crystals drop and vanish. It ends on a low, compact pose for the game's 0.6 s hold and 0.45 s sink and fade. |

To rebuild with Blender 4.2:

```
blender -b --factory-startup -P rig_wraith.py -- wraith_src.glb rigged.blend
blender -b --factory-startup -P anim_wraith.py -- rigged.blend wraith_raw.glb
python3 glb_textures.py wraith_raw.glb wraith.glb   # PNG and game-size maps (Godot rejects Blender's JPEG)
```
