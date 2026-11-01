# Striker frames

The Striker uses its own sheet, `assets/heroes/striker.png`, built from ten AI-made per-direction sheets (one per facing, plus a second SE and SW that were left out because their walks were choppier).

Layout: 64x64 frames, one column per facing (0 = N, then clockwise), rows 0-7 idle, 8-15 walk, 16-21 fire. Feet sit on pixel row 59, the same distance from the bottom as row 43 in the 48px heroes.

The source sheets did not hold a clean walk cycle in row order, so each walk was rebuilt by hand: frames were matched by leg pose and ordered so the planted foot travels backward under the body and every step to the next frame is small. Frames that jumped (a sudden lunge or crouch) were dropped. Source cells are written as rROWcCOL of the original sheet.

| Facing | Source | Idle | Walk (in play order) | Walk fps | Fire |
|---|---|---|---|---|---|
| 0 N | sheet 7 (North) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r2c0, r1c2, r2c1, r1c4, r2c5, r2c6 | 8 | r5c2, r5c3, r5c4, r5c5, r5c6, r5c7 |
| 1 NE | sheet 4 (Northeast) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6 | r2c0, r2c1, r2c2, r2c3, r2c4, r2c5, r2c6, r2c7 | 11 | r5c2, r5c3, r5c4, r5c5, r5c6, r5c7 |
| 2 E | sheet 3 (East) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r3c0, r3c3, r3c2, r3c1, r3c4, r3c5, r3c6, r3c7 | 14 | r5c2, r5c3, r5c4, r5c5, r5c6 |
| 3 SE | sheet 2 (Southeast) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r1c0, r1c1, r1c2, r1c3, r1c4, r1c5, r1c6, r1c7 | 11 | r4c2, r4c3, r4c4, r4c5, r4c6 |
| 4 S | sheet 1 (South) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r1c1, r2c0, r2c6, r2c5, r2c2, r1c5, r1c3, r1c4 | 11 | r5c2, r5c3, r5c4, r5c5, r5c6 |
| 5 SW | sheet 8 (Southwest) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r1c0, r1c1, r1c2, r1c3, r1c4, r1c5, r1c6, r1c7 | 11 | r4c2, r4c3, r4c4, r4c5, r4c6 |
| 6 W | sheet 6 (West) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6 | r3c7, r3c0, r3c1, r3c6, r3c5, r3c3, r3c2 | 13 | r5c1, r5c2, r5c3, r5c4, r5c5, r5c6 |
| 7 NW | sheet 5 (Northwest) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6 | r2c0, r2c1, r2c2, r2c3, r2c4, r2c5, r2c6 | 10 | r5c2, r5c3, r5c4, r5c5 |

Idle plays at 6 fps and fire at 15 fps. The side views (E, W) use the sheets' running rows: their slow-walk rows barely move the legs.
