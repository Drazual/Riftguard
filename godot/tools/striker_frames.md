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

## Shots (`art/heroes/striker_fx.tres`, sheet `assets/heroes/striker_fx.png`)

32px cells, 8 columns. Rows 0-7 are the bullet flying in each facing (N, NE, E, SE, S, SW, W, NW), looping.
Row 8 is the hit burst, row 9 the bigger crit burst, rows 10 and 11 the diagonal muzzle flashes (`flash_a` for
NE/SW, `flash_b` for NW/SE; `flash_o` reuses the start of the hit burst for N/E/S/W).

The gun tip in each facing (`HeroData.muzzle`, pixels of a 64px frame, taken from the flash in fire frame 0):
N (31.7, 26.1), NE (42.5, 30.2), E (50.7, 41), SE (48.8, 43.6), S (31.9, 52.1), SW (14.2, 43.6), W (12.5, 40.8),
NW (20.6, 30.3). Bullets leave from there and fly to the target's body at 750 units/s (see `Board._sync_hero_shots`).
Shooting while moving keeps the walk cycle (backwards when backing away) and adds a muzzle flash.

## Split layers (prototype)

On the board the Striker is two layers (see `Board._sync_hero_gun`):

- **Body** (`HeroData.body_frames` = `art/heroes/striker_body.tres`, sheet `assets/heroes/striker_body.png`): the same
  sheet with the gun erased, same layout and timings. Only idle and walk play, in 8 facings, so the legs keep walking
  while it shoots. The fire rows are unused on the board.
- **Gun and arms** (`HeroData.gun` = `assets/heroes/striker_gun.png`): drawn pointing east. It turns around
  `gun_pivot` to the exact angle of the target (or the walk direction when not shooting), sits on the body at
  `HeroData.shoulder[facing]`, flips when aiming left, goes behind the body when aiming up, and kicks back 2px per shot.
- **Bullets** leave from `gun_tip`, turned with the gun (`Board.hero_muzzle`). Every shot shows the round muzzle flash.

The menus still show the full `frames`. Both PNGs are placeholders made by `tools/striker_split/split.py`
(the body by erasing gun-coloured pixels, the gun hand-pixelled). Final art needs, at the same 64px scale:

1. The body sheet without any gun, with arms posed to hold one (or arms left off for the gun layer to carry).
2. One gun-and-arms sprite drawn pointing straight right, about 22-28px long, with its turning point at the shoulder.
   Optionally a second one drawn from slightly above for aiming down/up, if the side view looks off there.
3. The shoulder point for each facing and the pivot/tip pixels of the gun (set on `data/heroes/striker.tres`).
