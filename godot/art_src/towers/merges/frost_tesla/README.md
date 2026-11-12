# Cryo Coil v2: Frost Pylon × Tesla Coil merge (`frost+tesla`, recipe #9AF0FF)

**Design (v2, per feedback "make the top like the frost pylon and then it should have a coil under it").** The top is the actual Frost Pylon crown: the ice-crystal spire in its cream frame, the cross-shaped crystal arms and their icicles, and the crystal finial. It comes from `ice_tower.glb` and is scaled 1.38×, so it's large: **Ø 1.43 m across the arms**, which is wider than the 1.04 m plinth. The crown sits on a Tesla coil column (copper winding over cyan glow windows, rails, insulator stacks, an energy seat ring). A small floating cryo-core orb tops the finial. Everything stands on the same low plinth as v1, whose top is at 0.30 m, or **13%** of the 2.24 m height.
- **Electric effects kept:** 4 arcs from under the crown down to the corner crystals, cyan coil glow, the tip glow, a lightning bolt that shoots up on fire, and the muzzle flash.
- **Ice effects kept:** 6 orbiting ice shards, the frost-nova ring (now bursting at crown-arm height), glowing corner crystal clusters, and collar frost spikes.
- **No aiming.** The crown is 4-fold symmetric and fires upward like the Tesla Coil. `tower.json` has yaw/pitch `"-"`, and the GLB has no Yaw/Turret/Pitch/Gun/Barrel nodes, so the loader's name fallbacks can't pick anything up either. The Muzzle sits at the cryo-core orb on top.

- 19.9k tris. One 2048² atlas (color / normal / ORM / emission) plus 6 small FX materials.
- Nodes: Base (+ Column, Crown, FrostShards, Arc0-3, FrostNova). Crown has TipGlow and Muzzle (MuzzleGlow, MuzzleFlash, Bolt). BuffPoint is on top.
- Clips: `idle` 4.0 s loop, `fire` 0.6 s (shot at 0.20 s), `spawn` 1.2 s (ends on idle's first frame).
- Masks: `cryo_coil_accent_mask.png` (A = Frost: the crown frame, crown crystals and ice decorations) and `cryo_coil_accent_mask_b.png` (B = Tesla: the coil column and plinth electrics).

Previews (`previews/`): `cryo_coil_contact_sheet.png`, `cryo_coil_idle_fire.gif`, `cryo_coil_recolor_demo.png` (uses the game's shader math with the 72% body tint), `cryo_coil_vs_parents.png`, `v1_vs_v2.png`, `cryo_coil_atlas_masks.png`. `source/` holds the packed .blend, the build scripts and the Godot verify log. v1 (toroid top, rejected) is kept in `../final_v1/`.
