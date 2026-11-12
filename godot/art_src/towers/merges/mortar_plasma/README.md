# Bombard v2: Mortar × Plasma Cannon merge (`mortar+plasma`, recipe #D8F0B0)

**v2 changes** (feedback: "make sure it has a charge up for its projectile. make the gun part thinner so the tower doesnt look so bottom heavy and out of proportion"):
- **Thinner gun, taller silhouette.**
  - The real Mortar barrel and cradle are about 26% narrower, and the barrel is 8% longer.
  - The Mortar head/gear ring is narrower.
  - The Plasma canisters are smaller and tucked in.
  - The Plasma plinth is lower and smaller.
  - Result: 1.83 m tall × 1.18 m wide (v1: 1.72 × 1.54). The plinth is 20% of the height (v1: 26%).
- **Charge-up before every shot.** `fire` is 1.0 s, with the **shot at 0.55 s**.
  - During the charge, the teal plasma glob swells inside the bore within a growing halo.
  - Three charge rings light up the barrel from breech to muzzle.
  - The two canisters pump brighter in alternation.
  - Lightning streams and energy motes flow from the canisters into the barrel.
  - The barrel strains and shivers.
  - At the shot: flash, plasma shock ring, and the heavy Mortar recoil.

The design is still the real Mortar turret (gear ring, cradle, hazard-striped wide-bore barrel at 62°) on the real Plasma Cannon plinth. The Plasma Cannon's finned radiator and two teal canisters are mounted on the turret. It aims with yaw on `Turret`; pitch is fixed at 62° via `"aim"`; the muzzle is the node `Muzzle`.

- 23,781 tris, one 2048² atlas plus 8 small FX materials.
- Clips: `idle` 4.0 s loop, `fire` 1.0 s (charge 0–0.55 s, **shot 0.55 s**), `spawn` 1.2 s. All three key the same 57 tracks; none key Turret or Gun.
- Masks: A = Mortar (barrel and cradle), B = Plasma (plinth, radiator, canisters).

Previews (`previews/`):
- `v1_vs_v2.png`
- `bombard_vs_parents.png`
- `bombard_idle_fire.gif` (idle, then fire twice with the charge)
- `bombard_contact_sheet.png` (views, aim tests, 6 fire frames across charge/shot/recoil, spawn)
- `bombard_recolor_demo.png` (72% game math)
- `bombard_atlas_masks.png`

`source/` holds `bombard_v2.blend` (packed), the build scripts (`run_all.sh`) and the Godot verify log.
