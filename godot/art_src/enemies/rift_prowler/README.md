# Rift Prowler (the Grunt)

A rigged, animated enemy model. `data/enemies/grunt.tres` points at this folder (`model_dir`), so on the
hand-painted maps every Grunt is drawn from this model by `scripts/board/enemy_3d.gd` instead of a coloured disc.

## Files

| File | What it is |
|---|---|
| `rift_prowler.glb` | The game model: about 12k triangles, a 27-bone skeleton (Mixamo-style names plus `Tail` to `Tail4`), 1024 px colour and 512 px normal/ORM textures, and the clips below. |
| `enemy.json` | Height on the board (`height`, metres, a hero is 1.8), the speed its walk clip was made for (`walk_speed`), and which clip plays for each state (`anims`). |
| `rig.py`, `joints.json` | Builds the rig in Blender from the Meshy source model (`Meshy_AI_Rift_Prowler_texture.glb`, not in the repo; it's 26 MB). |
| `anim.py` | Keys every clip and exports the GLB. |
| `pngify.py` | Re-encodes the GLB's textures as PNG: Godot can't decode the JPEG Blender writes for the colour map. |

## Clips

| Clip | Loops | When it plays |
|---|---|---|
| `idle` | yes | standing still |
| `walk` | yes | walking the path, paced to the enemy's real speed |
| `slowed` | yes | slowed (frost and other slows): hunched, short dragging steps, shivering; plus a light blue tint |
| `hit` | no | a hit that takes 8% of its max HP or more (at most once every 0.9 s); smaller hits just flash |
| `stun` | yes | stunned: dazed, head lolling, wobbling |
| `frozen` | yes (held pose) | frozen solid by Rimeshard, with an icy tint |
| `knockback` | no | pushed back or pulled along the path |
| `attack` | no, repeated | held up by the hero or a wall |
| `death` | no | killed: knees buckle and it topples, lies still, then sinks into the ground |

## Rebuilding

Needs Blender 4.2+ (or the `bpy` Python package) and Python with Pillow.

```
blender -b -P rig.py -- Meshy_AI_Rift_Prowler_texture.glb /tmp/rigged.blend
blender -b -P anim.py -- /tmp/rigged.blend /tmp/rift_prowler.glb
python3 pngify.py /tmp/rift_prowler.glb rift_prowler.glb
```

Check it in game: `xvfb-run godot --path godot --rendering-driver opengl3 res://tests/prowler.tscn -- <out dir>`.
