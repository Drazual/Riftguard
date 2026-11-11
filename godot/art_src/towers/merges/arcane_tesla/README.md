# Railgun v2: Arcane Bolt × Tesla Coil merge (test model)

**Design.** Railgun first. A long twin-rail gun (1.64 m from breech cap to rail tips; the tips reach 1.04 m from center) sits on a chunky yaw yoke with trunnion cheeks and a real pitch pivot. That rests on a low, compact pedestal (yaw seat at 0.445 m, 32% of the 1.37 m height, 1.04 m footprint).
- **Arcane Bolt = the gun's identity:** the magenta crystal in its stone housing is the energy core lying in the breech. Two swept rune petals sit on the receiver, and magenta emitter strips line the inner faces of the rails.
- **Tesla Coil = decorations only:** two floating coil rings around the rails and one around the pedestal, three pairs of arcing electrodes on the rails, copper coil emitters on the receiver's flanks, insulator nubs on the pedestal corners, and a thin trim band, stripes and vent lights on the pedestal.

- 23.4k tris. One 2048² atlas (color / normal / ORM / emission) plus 5 small effect materials.
- Nodes: Base, Turret (yaw) > Yoke + Gun (pitch) > Receiver + Barrel > Muzzle (MuzzleGlow, MuzzleFlash). BuffPoint on top.
- Clips: `idle` 4.0 s loop, `fire` 0.6 s (shot at 0.22 s, 8 cm recoil), `spawn` 1.2 s (ends on idle's first frame).
- Path-color masks: `railgun_accent_mask.png` (Arcane, on the gun) and `railgun_accent_mask_b.png` (Tesla, on the decorations). R = trim, G = glow, B = details.

See `CLAUDE_NOTES.md` for integration. Previews:
- `previews/railgun_contact_sheet.png`: 6 views, yaw -60°, pitch +20° up / 12° down, and 4 frames each of idle, fire and spawn
- `previews/railgun_idle_fire.gif`: idle loop, then fire twice
- `previews/railgun_recolor_demo.png`: the original and 3 path-color sets, at a 3/4 view and a 30° game camera
- `previews/railgun_atlas_masks.png`: the atlas, emission and both masks
- `previews/v1_vs_v2.png`: side-by-side with the rejected v1

`source/` holds the packed .blend (clips as NLA tracks) and the Blender/Godot build scripts.
