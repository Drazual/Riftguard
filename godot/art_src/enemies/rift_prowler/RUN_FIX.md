# Rift Prowler run fix

`rift_prowler.glb` replaces the old one. It has the same clip names and the same 27 bones; only `run` is rebuilt, and every clip now starts at t=0.

What was wrong with the old run:

1. **A hitch on every loop.** The export didn't use slide-to-zero, so all clips started at 1/30 s. Godot then showed the same pose at 0.0 and 0.033 s, which froze one frame per cycle. Idle and stun had the same problem.
2. **Sliding feet.** While a foot was planted it moved 2.3-2.5x faster than the ground, then stuck for about 3 frames.
3. **Hip bounce out of phase.** The hips were lowest in flight instead of mid-stance.
4. **Uneven timing.** 26 keys were rounded onto 16 frames, so the gait phase was irregular.

The new `run` is a 16-frame loop (0.533 s). The legs use 2-bone IK on a designed foot path at 0.116 native/frame, which matches walk_speed 52 on the iso diagonals. The ball of the foot stays planted with zero slide, the heel lifts late in stance, and the hips are lowest at mid-stance. The upper body, arms, tail and the hip/torso twist are kept from the old run.

To rebuild: `blender -b --factory-startup -P fix_run.py -- old_rift_prowler.glb rift_prowler.glb`
