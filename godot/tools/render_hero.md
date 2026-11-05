# Riftguard: 3D models rendered to hero sprites

How Riftguard turns 3D character models into the pixel-art sprite sheets the game uses. The game stays 2D: hand-painted maps, sprite towers, and Godot 4.7 with 2D nodes. Only the characters start as 3D models, and they are rendered to sprites ahead of time by a tool inside the Godot project.

## Why

- A weapon is part of the model, attached to a hand bone, so it always lines up with the body in every frame and every direction.
- Any number of directions and animations can be rendered from one model. A new hero is a new model, not hundreds of hand-drawn frames.
- The game code doesn't change. It already plays 8-direction sprite sheets (`idle_N`, `walk_N`, `fire_N`) and fires bullets from a per-direction muzzle point.

## The pipeline at a glance

```
3D model (GLB, rigged, with animations and a "Muzzle" marker)
   -> Godot render tool (orthographic camera at the board's 3/4 angle, toon lighting, outline)
   -> 8 directions x (idle, walk, fire) frames, rendered big and shrunk to 64x64 pixel art
   -> sprite sheet PNG + SpriteFrames .tres + muzzle point per direction
   -> HeroData (frames, sheet, muzzle) -> the game plays it like any other hero
```

## 1. Input: what a hero model must have

One folder per hero, `godot/art_src/heroes/<folder>/`, holding the `.glb` and a `hero.json`:

```json
{
	"model": "Rogue.glb",
	"weapon": "2H_Crossbow",
	"hide": ["1H_Crossbow", "Knife", "Knife_Offhand", "Throwable"],
	"anims": { "idle": "2H_Ranged_Aiming", "walk": "Walking_A", "fire": "2H_Ranged_Shoot" },
	"out": "rogue_test"
}
```

`weapon` (the node whose front end becomes the muzzle when there's no `Muzzle` node) and `hide` (spare props) are optional.

- **Rigged humanoid.** A Mixamo or KayKit-style skeleton is fine.
- **Size and orientation:** about 1.8 units tall, Y up, standing at the origin, facing +Z (toward the camera at yaw 0).
- **Weapon:** part of the model, parented to the hand bone, with both hands posed on it in the animations.
- **A `Muzzle` node:** an empty or Node3D named exactly `Muzzle`, at the tip of the barrel, parented to the weapon. Bullets start here.
- **Animation clips** (names can be remapped in the tool's config):
  - `idle`: standing with the weapon held, looping.
  - `walk`: walking in place (no root motion), weapon held, looping.
  - `fire`: one shot with recoil, about 0.3 to 0.5 s.
  - Optional: `aim` (held aiming pose), `cast`, `death`.
- **Textures:** simple flat colours or hand-painted textures. Low detail reads better at 64 px.

## 2. The render tool (Godot)

`godot/tools/render_hero.gd`. It needs a display because it renders, so on a server run it under Xvfb: `xvfb-run godot --path godot --rendering-driver opengl3 -s res://tools/render_hero.gd -- <hero folder>`. On Windows, run the same command without `xvfb-run`. A full hero takes about 10 seconds.

**Camera**
- Orthographic, looking down 35 degrees (`PITCH`). That's flatter than the ground's own tilt (asin(0.75), about 49 degrees), so characters read more from the front, like hand-drawn 3/4 sprites.
- One camera position for every direction. The model is turned instead, to the 8 facings (N, NE, E, SE, S, SW, W, NW). The diagonals are worked out through the board's 0.75 squash, so they match the game's 8 sectors on screen.
- **Same size for every hero:** before rendering, the tool renders the first idle frame facing the camera, without the weapon. It scales the model so it stands 38 px tall (`TALL`), then moves it so its lowest pixel sits on row 59. It measures the render rather than the model, because skinned meshes don't report their posed size reliably.

**Look**
- Toon shading: one directional key light from the top-left, plus flat ambient, with 3 to 4 hard light bands.
- A 1 px dark outline, from an edge pass on the alpha and depth.
- Render at 4x (256x256) with no anti-aliasing. Shrink to 64x64 by box filter, then a hard alpha cut, so the result is crisp pixel art.
- Optional: snap colours to the game's palette.

**Frames per direction** (sampled at even times through each clip)

| Animation | Frames | Playback fps | Loops |
|---|---|---|---|
| idle | 4 | 5 | yes |
| walk | 8 | 12 | yes |
| fire | 4 | 15 | no |

- Feet anchored on pixel row 59 of the 64 px frame, the same as the current Striker. Horizontally centred on the hips.
- The camera never moves between frames, so the walk bob is baked in.

**Muzzle**
- For each direction and fire frame, the tool projects the `Muzzle` node's 3D position through the camera to a pixel in the 64 px frame.
- It writes the first fire frame's point per direction to `HeroData.muzzle`. All per-frame points go in a sidecar `.json` for later use.

## 3. Output (per hero)

| File | What it is |
|---|---|
| `godot/assets/heroes/<id>.png` | The sheet: 8 columns (N, NE, E, SE, S, SW, W, NW) of 64 px frames. Rows: idle 0-3, walk 4-11, fire 12-15. |
| `godot/art/heroes/<id>.tres` | SpriteFrames with `idle_0..7`, `walk_0..7`, `fire_0..7` at the fps above. |
| `godot/data/heroes/<id>.tres` | HeroData: `frames`, `sheet` and `muzzle` filled in by the tool. Stats stay hand-edited. |
| `godot/art_src/heroes/<folder>/muzzle.json` | Muzzle pixel for every direction and fire frame. |

It also prints the line to paste into the hero's data: `HeroData.muzzle = PackedVector2Array(...)`.

**Preview in game without changing any hero:** `xvfb-run godot --path godot --rendering-driver opengl3 res://tests/striker.tscn -- <out dir> <folder>` puts the render on the Striker and saves close-ups of him walking and shooting.

## 4. In the game

Nothing new: the board already
- turns the hero to the nearest of 8 facings, with hysteresis so it doesn't flicker,
- plays walk while moving, including while shooting (backwards when backing away), idle when still, and fire when shooting while standing,
- spawns bullets from `muzzle[facing]` and flies them to the target.

The split body-plus-gun layer added for the 2D Striker is no longer needed for 3D heroes, because the gun is in the frames. If aiming between the 8 directions ever looks too coarse, the tool can render 16 directions instead with no game changes beyond the facing count.

## 5. Making a hero model

1. **Model:** generate one with an AI 3D tool (Meshy, Tripo or Rodin) from a front-view concept image, or use a free CC0 pack (KayKit, Quaternius, Kenney). Keep it low-poly with chunky proportions.
2. **Rig:** upload to Mixamo (free) for an automatic humanoid rig, or use the generator's own auto-rig.
3. **Animations:** from Mixamo, download "Rifle Idle", "Rifle Walk" (tick "In Place") and "Firing Rifle", or similar for other weapon types. For casters, use "Standing Idle", "Walking" and a casting clip.
4. **Assemble in Blender:** import the rigged model and clips. Parent the weapon to the right-hand bone and add an empty named `Muzzle` at the barrel tip. Name the clips `idle`, `walk` and `fire`, then export one `.glb` (glTF Binary, animations on, +Y up).
5. **Render:** drop the file in `godot/art_src/heroes/<id>/` and run the render tool. Check the result with `tests/striker.tscn`-style close-ups.

### Prompt for an AI 3D generator (Striker)

> Low-poly stylised game character, full body, T-pose or A-pose, front view: a young street fighter with spiky dark teal hair, a hot-pink bandana with long tails, a cropped white and pink jacket with cyan shoulder pads, navy cargo pants with glowing cyan knee pads, white chunky sneakers. Holding nothing (the weapon is added separately). Clean flat colours, simple shapes, readable at small size, neon synthwave palette.

> Low-poly stylised sci-fi rifle, side view: white and cream body, dark grey grip and barrel, cyan glowing stripe along the side, small scope on top. Simple shapes, flat colours.

## 6. Current status

- The tool works end to end on a placeholder: the free CC0 KayKit Rogue with a two-handed crossbow (`art_src/heroes/rogue_test`), rendered to `assets/heroes/rogue_test.png` and previewed in game.
- No real hero uses a render yet. The shipped Striker is unchanged.
- Swapping in a real model later means dropping in a new `.glb` and re-running the tool.

## Live 3D instead of sprites

A hero can also skip the sprite sheet and be drawn live from its model: set `HeroData.model_dir` to the hero's
source folder (the one with `hero.json`). `scripts/board/hero_3d.gd` renders the model every frame into a small
transparent viewport with the same camera angle and the painted lighting, plus a dark outline, and draws it on the
board. The hero then turns to any angle, aims exactly at its target and blends between idle, walk and fire. The
same `hero.json` drives both, so a hero can switch between live and pre-rendered at any time. `frames` is still
used for the menu portrait. The folder must ship with the game, so it is not covered by the export exclude filter.

## Towers rendered from 3D

`tools/render_tower.gd` does the same for a turret tower: `xvfb-run godot --path godot --rendering-driver opengl3 -s
res://tools/render_tower.gd -- <tower folder>`, for a folder in `godot/art_src/towers/` with the `.glb` and a
`tower.json` (the options are listed at the top of the tool). It uses the heroes' camera and painted look, sets the
model's yaw and pitch nodes itself (so any yaw or pitch keys in the clips are overridden), and renders 16 facings,
each with one idle frame and 6 frames of the fire clip, into 128 px frames. The board draws them at
`TowerData.turret_scale` (0.38 for the Prism Laser and Plasma Cannon, so they stand about as tall as the pixel-art
towers); change that number to resize a turret without baking again.

It writes `assets/towers/<out>.png`, `art/towers/<out>.tres` (`idle_N` and `fire_N`, N = 0 up the screen,
clockwise) and the muzzle point of every facing, and prints the `TowerData.turret_muzzle` line. Setting
`TowerData.turret` makes the board draw those frames instead of the tower's `idle` and `attack`, turn the turret to
the nearest facing toward its target, and start the laser's beam at the muzzle. The tower's old `frames` still
supply its beam and hit effects. The source models aren't needed at runtime, so `art_src/towers/` is left out of
the export.

The Prism Laser (`art_src/towers/laser/prism_laser.glb`) is the first: Yaw turns the head, Pitch tilts the prism
(negative is up), and the beam leaves from the `Muzzle` node. It's baked with a slight downward tilt (`aim` 0.12)
toward the enemies on the ground. `tests/laser.tscn` takes screenshots of it in a run.

The Plasma Cannon (`art_src/towers/plasma/plasma_cannon.glb`) is the second. Its Pitch range is tiny, so it's baked
level (`aim` 0), and its shell flies straight from the muzzle (`TowerData.shot_arc` 0). `shot_frame` 1 in its `tower.json` takes the
muzzle point from the fire frame where the glow peaks, which is also its `fire_frame`, so the shell leaves the
barrel as it flashes. A turret without a held target (no beam) faces where its last shot went.
`tests/plasma.tscn` takes screenshots of it in a run.

The Arcane Bolt (`art_src/towers/arcane/arcane_bolt.glb`) is the third. Its crystal rests tilted 45° up, so it's
baked at that rest pitch (`aim` -0.789) and only turns (yaw). Its base is 1.0 m across against the Plasma Cannon's
1.33 m, so it renders at `wide` 42 (56 / 1.33) to keep the same pixels per metre, and draws at the same
`turret_scale` 0.38. The bolt leaves the crystal tip (`Muzzle`) at `shot_frame` 1, where the tip glows, and flies
straight. `tests/arcane.tscn` takes screenshots of it in a run.
