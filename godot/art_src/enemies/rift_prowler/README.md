**Current run: [RUN_V3.md](RUN_V3.md)** (built by `anim_v3.py`). RUN_FIX.md and RUN_V2.md describe older passes; their scripts stay as a record of how the clips were built.

# Rift Prowler (the Grunt)

A rigged, animated enemy model. `data/enemies/grunt.tres` points at this folder (`model_dir`), so on the
hand-painted maps every Grunt is drawn from this model by `scripts/board/enemy_3d.gd` instead of a coloured disc.

## Files

| File | What it is |
|---|---|
| `rift_prowler.glb` | The game model: about 12k triangles, a 27-bone skeleton (Mixamo-style names plus `Tail` to `Tail4`), 1024 px colour and 512 px normal/ORM textures, and the clips below. Frost is a shader overlay in `enemy_3d.gd`, not a texture. |
| `enemy.json` | Height on the board (`height`, metres, a hero is 1.8), the speed its walk clip was made for (`walk_speed`), and which clip plays for each state (`anims`). |
| `rig.py`, `joints.json` | Builds the rig in Blender from the Meshy source model (`Meshy_AI_Rift_Prowler_texture.glb`, not in the repo; it's 26 MB). |
| `anim.py` | Keys every clip and exports the GLB. |
| `fix_run.py`, `RUN_FIX.md` | Rebuilds the run with locked feet and a clean 16-frame loop. |
| `pngify.py` | Re-encodes the GLB's textures as PNG: Godot can't decode the JPEG Blender writes for the colour map. |

## Clips

| Clip | Loops | When it plays |
|---|---|---|
| `idle` | yes | standing still |
| `run` | yes | moving along the path (enemy.json maps the game's `walk` to it). Paced to the enemy's real speed, so a 40% slow plays it 40% slower. While slowed, frost creeps over the model and it gets a slight icy tint. |
| `stun` | yes | stunned: dazed, head lolling, wobbling |
| `frozen` | yes (held pose) | frozen solid by Rimeshard, fully frosted |
| `knockback` | no | pushed back or pulled along the path |
| `attack` | no, repeated | held up by the hero (it turns to face them) or a wall: a lunging two-claw combo |
| `death` | no | killed: knees buckle and it topples, lies still, then sinks into the ground |

Hits don't play a clip.

## Rebuilding

Needs Blender 4.2+ (or the `bpy` Python package) and Python with Pillow.

```
blender -b -P rig.py -- Meshy_AI_Rift_Prowler_texture.glb /tmp/rigged.blend
blender -b -P anim.py -- /tmp/rigged.blend /tmp/rift_prowler.glb
python3 pngify.py /tmp/rift_prowler.glb /tmp/rift_prowler_png.glb
blender -b --factory-startup -P fix_run.py -- /tmp/rift_prowler_png.glb rift_prowler.glb
```

`fix_run.py` rebuilds `run` with planted feet (see RUN_FIX.md); the game's run comes from it, not from anim.py's.

Check it in game: `xvfb-run godot --path godot --rendering-driver opengl3 res://tests/prowler.tscn -- <out dir>`.
