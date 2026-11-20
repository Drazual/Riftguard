# Rift Prowler v3 run: very long, loping strides

File swap only. Same clip names (idle, run, stun, frozen, knockback, attack, death), the same 27 bones and textures.
`enemy.json` doesn't change (walk_speed 52, run clip "run"). Only `run` changes; `attack` is v2's (rebuilt
by the same code, unchanged).

**run** (all numbers SUGGESTED; native mesh units, the game shows the 1.903 m mesh at 1.45 m):
- **Same ground speed:** 0.116 m per frame native (walk_speed 52). In game, ground travelled ÷ (clip speed × time) = 1.000.
- **Cycle:** 22 → 32 frames (0.733 → 1.067 s), so cadence drops another 31% (−50% vs v1).
- **Step length:** 1.276 → 1.856 m native (+45% vs v2, 2× v1). That's about 1.4 m per step in game for a 1.45 m creature.
- **Visible leg split:** the widest gap between the feet grows from 0.83 m (v2) to 1.09 m (v1 was 0.62 m).
- **Footing:**
  - Each foot is planted for 10 of 32 frames (1.16 m of ground), and the stance leg reaches full extension at toe-off.
  - Then there are 6 airborne frames per step, so it bounds.
  - The swing has a high heel kick-up behind, a knee drive, and a forward reach that paws back onto the landing spot.
- **Body:**
  - The hips sit lower (a crouched lope) and bounce 6 cm.
  - The pelvis turns ±9° with the leg that swings forward and drops a little on the swing side.
  - The shoulders counter-rotate, the trunk leans 9° into the run, and the neck takes back some of that lean so the head stays level.
- **Arms:** v1's arm swing, pumped ×1.6 around its average pose.
- **Contact check** (`contact_check.py run 0.116 LeftToeBase,RightToeBase`): 10 planted frames per foot. The worst slide is 2.3 mm per frame, against 116 mm of travel.
- **QA tuning knobs** (anim_v3.py takes `KEY=value` overrides): `N` (cycle), `DUTY` (planted frames), `HIP_Z`, `BOUNCE`, `LIFT`, `REACH`, `PUMP` (arm swing), `LEAN`, `YAW`.

**Rebuild:**
- The input is the **v1** GLB (the one in git before the v2 commit):
  `git show c0aac31^:godot/art_src/enemies/rift_prowler/rift_prowler.glb > /tmp/prowler_v1.glb`
- Then run: `blender -b --factory-startup -P anim_v3.py -- /tmp/prowler_v1.glb rift_prowler.glb`

  Blender 4.2 is fine for this.
