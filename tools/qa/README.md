# tools/qa: optional Blender QA for delivered GLBs

These are wrappers around [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills) (MIT), plus our own
`contact_check.py`. They're an **extra pair of eyes, not a pass/fail gate**: the "game" profile fails every animated
Riftguard model on things that are fine for us (see NOTES.md).

## Needs
- **Blender 5.2 or newer** for the blender-skills scripts. The free portable build from download.blender.org works;
  there's no need to install it system-wide. Set `BLENDER=/path/to/blender`.
- A clone of blender-skills, kept *outside* this repo: `git clone https://github.com/EL4CTEO/blender-skills`. Set
  `BLENDER_SKILLS=/path/to/blender-skills`.
- `contact_check.py` (ours, foot sliding) runs on any Blender ≥ 4.2.

## Run (from the repo root; the GLB is copied to a temp folder first, never edited)
```
# mesh QA, in a real animated pose, with this asset's parts only
python tools/qa/run_qa.py asset --glb godot/art_src/enemies/rift_prowler/rift_prowler.glb --pose run --parts Prowler
python tools/qa/run_qa.py asset --glb godot/art_src/enemies/bastion/bastion.glb --pose move --parts Bastion
python tools/qa/run_qa.py asset --glb godot/art_src/towers/merges/arcane_plasma/starbolt.glb --fps 60 --pose idle \
    --parts Base FinBand Canisters Head PetalL PetalR PetalB Star
# loop seams (pops / hitches) on looping clips, never --fix
python tools/qa/run_qa.py loops --glb godot/art_src/enemies/rift_prowler/rift_prowler.glb --clips run,idle,stun,frozen
# foot sliding: native speed in mesh units per frame (enemy README / anim script), the bones whose soles plant
python tools/qa/run_qa.py contact --glb godot/art_src/enemies/rift_prowler/rift_prowler.glb --clip run --speed 0.116 --bones LeftToeBase,RightToeBase
```
- `--fps` is the clip's native rate: **30** for enemies and heroes, **60** for merge towers. Resampling a 30 fps clip
  at 60 fps creates fake "kinks" at every key.
- `--parts`: list the asset's meshes. The glTF importer adds an `Icosphere` (its bone-shape helper), which isn't part
  of the asset.
- Results print as a short summary; full JSON goes to `qa_out/`, which is git-ignored scratch space.

Files: `run_qa.py` (driver), `prep_glb.py` (import + strip the importer's NLA tracks), `pose_blend.py` (pose every
object with one clip), `seam_vs_interior.py` (is a seam kink unusual for this clip?), `contact_check.py` (ours),
`NOTES.md` (what to ignore).
