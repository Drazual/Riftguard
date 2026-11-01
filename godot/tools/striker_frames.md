# Striker frames

The Striker uses its own sheet, `assets/heroes/striker.png`, built from AI-made per-direction sheets.

Layout: 64x64 frames, one column per facing (0 = N, then clockwise), rows 0-7 idle, 8-15 walk, 16-21 fire. Feet sit on pixel row 59, the same distance from the bottom as row 43 in the 48px heroes.

## How the walks were built

The sheets did not hold a clean walk cycle in row order. Most rows are a shuffle: the front foot steps and the back foot drags without ever swinging through. Each walk was rebuilt from single frames:

- **E, SE, NE** are one step each: wide stance, back foot lifts, back foot swings past the planted foot, front foot reaches and lands. The planted foot moves steadily backward through the loop. Frames where the body suddenly dips or lunges were left out.
- **S and N** alternate left foot forward, passing, right foot forward, passing, with the four steps about the same size so the rhythm is even.
- **W, SW, NW** are the E, SE and NE art mirrored. Their own sheets (6, 8 and 5) have no frames of the back foot swinging through, so they could only make a shuffle. The second SE and SW sheets (9 and 10) were not used.

Source cells are written as rROWcCOL of the original sheet.

| Facing | Source | Idle | Walk (in play order) | Walk fps | Fire |
|---|---|---|---|---|---|
| 0 N | sheet 7 (North) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r2c0, r2c6, r2c1, r1c6 | 7 | r5c2, r5c3, r5c4, r5c5, r5c6, r5c7 |
| 1 NE | sheet 4 (Northeast) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6 | r4c3, r2c6, r1c5, r1c4, r4c2, r2c1 | 18 | r5c2, r5c3, r5c4, r5c5, r5c6, r5c7 |
| 2 E | sheet 3 (East) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r4c1, r4c2, r3c0, r4c6, r4c5, r3c4, r3c6, r4c7 | 24 | r5c2, r5c3, r5c4, r5c5, r5c6 |
| 3 SE | sheet 2 (Southeast) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r2c0, r1c2, r1c4, r1c0, r2c1 | 15 | r4c2, r4c3, r4c4, r4c5, r4c6 |
| 4 S | sheet 1 (South) | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r2c0, r2c1, r1c5, r1c1 | 7 | r5c2, r5c3, r5c4, r5c5, r5c6 |
| 5 SW | sheet 2 (Southeast) mirrored | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r2c0, r1c2, r1c4, r1c0, r2c1 | 15 | r4c2, r4c3, r4c4, r4c5, r4c6 |
| 6 W | sheet 3 (East) mirrored | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6, r0c7 | r4c1, r4c2, r3c0, r4c6, r4c5, r3c4, r3c6, r4c7 | 24 | r5c2, r5c3, r5c4, r5c5, r5c6 |
| 7 NW | sheet 4 (Northeast) mirrored | r0c0, r0c1, r0c2, r0c3, r0c4, r0c5, r0c6 | r4c3, r2c6, r1c5, r1c4, r4c2, r2c1 | 18 | r5c2, r5c3, r5c4, r5c5, r5c6, r5c7 |

Idle plays at 6 fps and fire at 15 fps. Walk speeds are set so every direction takes a step about every third of a second.
