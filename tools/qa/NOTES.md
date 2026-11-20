# Reading the results for Riftguard's style

## Ignore (false positives for us)
- **duplicate verts**: the glTF importer splits vertices at UV seams and hard edges. Always present.
- **unapplied scale / zero scale** on nodes that clips scale (Warden `FlareMesh` at 0, Starbolt FX meshes, a
  merge's charge flashes): intended. QA a model **in a pose** (`--pose idle` / `walk`), never in its stored rest
  transform. Blender's glTF importer poses a model with its FIRST clip, so a GLB whose first clip is `spawn` opens
  collapsed (Starbolt v1.0); the rest-pose run is pure noise there. Starbolt v1.1 puts `idle` first.
- **no UV map** on flat emissive FX meshes (glows, flashes, rings): intended.
- **asset not on z=0**: weapon-only GLBs (centred on the shaft by design), a skinned model's bind pose (QA it in a pose).
- **floating / detached parts** on separate weapon or flare meshes riding a bone: intended (none were found anyway).
- **loop "kinks" / "dips"** on walk, run and block clips. Foot contacts make sharp velocity changes; if the seam's
  kink matches the mirrored side mid-cycle (`seam_vs_interior.py` says "none"), it's a contact, not a seam bug. A
  "dip" with equal in/out speeds is noise.
- **1-frame duplicate loop end** (last frame == first): that's our convention; engines drop it.
- **hidden back-to-back faces** under ~50 pairs on decimated scan-style meshes (Warden, Prowler): invisible, not worth it.
- **hidden back-to-back faces** that aren't hidden: thin knife edges (Starbolt's star points: front and back meet,
  both visible), and pairs between two parts that move against each other (a yawing head on its base, petals that
  flick open). The check only sees one frozen pose. Deleting those makes holes.

## Look at
- **pops** in loop_check (`loops=False`): a real seam jump.
- a bone listed by `seam_vs_interior.py` as worth a look (seam kink > 1.5x anything mid-cycle).
- **z-fighting** in the dozens or more of coplanar pairs on a hard-surface part (it can shimmer close up).
- **hidden back-to-back faces** in the hundreds: possibly wasted tris, but check first (see Ignore). Of Starbolt
  v1.0's ~470 pairs only 34 tris were really hidden.
- **degenerate faces**, **inverted normals**, **inconsistent winding**, **verts with no weights / >4 influences**,
  **missing textures / wrong colour space**: real if they show up.
- `contact_check.py`: planted frames per step and slide per frame. A few mm per frame against centimetres of
  travel is fine; blender-skills has no foot-sliding check, so keep using ours for that.

## Never
- `--fix` or `--save` on loop_check (it would key the first pose onto the last frame of OUR delivered clips).
- Running anything on the original GLB in `godot/art_src` (run_qa.py copies it first).
- Installing blender-skills into an agent-skills folder or running its install scripts: just call its scripts.
