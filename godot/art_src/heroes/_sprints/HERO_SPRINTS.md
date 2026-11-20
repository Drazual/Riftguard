# Hero sprints (Striker, Sniper, Wizard, Vanguard, Gale): authored runs with a coordinated upper body

All numbers are SUGGESTED (tuned on the box, easy to change in hero_sprint.py PRESETS and hero.json "run_speed").
The Oracle hovers and is unchanged.

## What changes in the game
- Each hero gets `godot/art_src/heroes/<hero>/<hero>_run.glb` (rig + one clip "run", 60 keys/s) and hero.json gets
  `"anims": {"run": "<hero>_run.glb"}` plus `"run_speed": <model m/s>` (the per-hero flag: when it is set the run is
  "authored": played as made, no _stretch/_narrow, no hip drop, play rate = board speed / (run_speed x fit)).
- Clip name stays "run" (file swap); the hero picks it when the walk would play faster than 1.4x, as before.
- Wizard: `run_from_walk` is removed (the old stretched walk-as-run). Vanguard (tank) / Gale (gale_tank): their
  "walk": "@run" mapping is untouched; the new "run" takes over at sprint speed.
- Shooting on the move (Striker, Sniper: walkfire heroes): new "runfire" = the run's legs + the aim pose, with 80%
  (RUNFIRE_SWAY) of the run's spine/neck/head motion kept on top of the aim, so the torso and gun still ride the stride.
  Arms hold the aim; the barrel correction in _process keeps the shot on target. Wizard/Vanguard/Gale are
  "walkfire": false: their run keeps playing unchanged while they attack on the move; casts/abilities still play standing.

## Upper body, in step with the legs (hero_sprint.py)
- Pelvis: bobs (lowest mid-stance), yaws with the swinging leg, rolls 4 deg / tilts 8 deg.
- Chest counter-rotates against the hips (YAW x TWIST, split over Spine1/Spine2), the trunk leans forward (LEAN),
  flexes ~1.2 deg just after each footfall, and sways 2.5 deg over the stance leg.
- Arms opposite the legs: right arm forward as the left foot lands.
  - Striker/Sniper (two-hand rifle): both arms move rigidly with the chest about Spine2 (yaw 6 deg, bounce-pitch 3.5 deg).
  - Wizard: free left arm pumps (46 deg, elbow 80 +/- 20); staff arm swings from its carry (16 deg, elbow 6).
  - Vanguard: free right arm pumps (40 deg, elbow 85 +/- 18); shield arm swings a little (7 deg).
  - Gale: sword arm swings (30 deg, elbow 12); shield arm 7 deg.
- Neck/head stabilised: slerped 85%/45% back toward level-and-forward, so the head stays steady while the chest twists.

## Numbers per hero (SUGGESTED)
| hero (folder) | run_speed (model m/s) | cycle s | step m | flight s | contact keys/foot | worst slide mm per 1/60 s key (per 30 fps frame) | travel/key mm | ground matched (sole) | in-game play rate | in-game ground matched (before -> after) |
|---|---|---|---|---|---|---|---|---|---|---|
| Striker (striker) | 10.25 | 0.533 | 2.73 | 0.18 | 5 | 0.87 (~1.7) | 170.8 | 99.5% | 1.00 | 26% walk x2.2 -> 100% |
| Sniper (sniper) | 8.49 | 0.567 | 2.41 | 0.18 | 6 | 0.88 (~1.8) | 141.5 | 99.4% | 1.00 | 42% walk x2.2 -> 100% |
| Wizard (wizard) | 8.68 | 0.567 | 2.46 | 0.18 | 6 | 1.20 (~2.4) | 144.7 | 99.2% | 1.00 | 30% stretched-walk run x1.5 -> 100% |
| Vanguard (tank) | 8.19 | 0.600 | 2.46 | 0.20 | 6 | 0.55 (~1.1) | 136.5 | 99.6% | 1.00 | 90% @run x2.2 (scurry) -> 100% |
| Gale (gale_tank) | 8.49 | 0.600 | 2.55 | 0.20 | 6 | 1.74 (~3.5) | 141.5 | 98.8% | 1.00 | 87% @run x2.2 (scurry) -> 100% |

Contact check: enemies/tools/contact_check.py logic (contact_check_fps.py adds an fps arg), on the preview GLB with
mesh, at the true move speed (V/60 per key); bone ToeBase for Striker/Sniper/Wizard, Foot for Vanguard/Gale (their
toes are skinned to the foot). Lowest sole point: within +/-6 mm of the ground, Vanguard dips 9 mm at most.
In-game: capture_hero at plaza speed: every hero plays ext/run at speed_scale 1.000; Striker shooting on the move
plays ext/runfire at 1.000 for all 119 moving frames. (The Sniper didn't fire in the 120-frame box capture, so check
his runfire by eye.)

## Rebuild / check
blender -b --factory-startup -P hero_sprint.py -- <hero> art_src/heroes/<hero>/<hero>.glb <hero>_run.glb [V=.. LEAN=..]
  hero = striker | sniper | wizard | tank | gale_tank; prints PIVOT and RUN (cycle, step, hips, flight) lines.
blender -b --factory-startup -P contact_check_fps.py -- <hero>_run_preview.glb run <V/60> mixamorig:LeftToeBase,mixamorig:RightToeBase out.json 60
If you change a hero's V in the preset, put the same value in hero.json "run_speed".
