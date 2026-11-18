# Rift Prowler v2: a longer run and a slower, broader attack

This is a file swap: same clip names (idle, run, stun, frozen, knockback, attack, death), the same 27 bones, and the same
textures. enemy.json stays as it is.

**run**: the same ground speed (walk_speed 52, 0.116 m per frame native), with longer strides and a lower cadence:
- **Cycle:** 16 → 22 frames (0.533 → 0.733 s), so cadence drops 27%.
- **Step length:** 0.928 → 1.276 m native, **37.5% longer**.
- **Footing:** each foot is planted for 8 of 22 frames, with a short float between steps, so it reads as a loping run.
- **Hips:** 5.5 cm lower, and they bounce a little more, so the legs reach the longer stride.
- **Upper body:** the arms, spine, head and tail are v1's, stretched to the new cycle.
- **Contact check:**
  - 8 planted frames per foot; worst slide 2.5 mm per frame, against 116 mm of travel (same as v1).
  - In-game on plaza and coral, ground travelled ÷ (clip speed × time) = 1.000.

**attack**: 0.95 → 1.40 s.
- **Wind-up:** 0.40 s (was 0.18 s).
- **Swings:** broader; every joint's swing away from the ready pose is ×1.35.
- **Lunge:** the left foot steps 0.22 m forward into the first slash and the body drives 0.22 m forward (was 0.08 m). It then steps back into the ready crouch, so the clip still repeats in place while it's held up.
- **Timing:** the slashes land at 0.52 s and 0.92 s. The game's blocked damage is continuous, so there's no hit marker to update.

**Rebuild:** `blender -b --factory-startup -P anim_v2.py -- rift_prowler_v1.glb rift_prowler.glb`

(This works on the v1 GLB, which is the one in the repo before this swap.)
