# Tower path balance harness

This drops each base tower onto Ocean Drive in a headless Test Room, levels it along every path combination, and measures its damage in fixed scenarios. Its job is to compare upgrade paths inside one tower. It isn't a full-run difficulty sim (`tests/balance_sim.gd` does that).

## Run it (repo root, Godot 4.7.2, headless, no display needed)
```
GODOT=godot bash godot/tests/_review/run_all.sh /tmp/after          # all 9 towers, about 1 minute in parallel
python3 godot/tests/_review/analyze.py /tmp/after godot/tests/_review/baseline   # after vs before
```
One tower: `godot --headless --path godot res://tests/_review/path_sim.tscn -- tesla combos` (or `singles`).
What-if numbers without editing data: `OVR="tesla.dmg=34" godot --headless ...`

## What it measures
- `combos`: all 10 three-path builds at level 13 (4/4/4). `singles`: each path at 4 points (level 5), plus `none`.
- Columns (all towers except Anvil): `boss` = a Warden (50% armor, HP ×1000) standing still, dps over 30 s; `bosswalk` = total damage to a Warden walking past; `swarm` = 60 Grunts (wave 30, 4× HP); `armored` = 20 Bastions (wave 25, 2× HP, can't be slowed); `fast` = 60 Runners (wave 30, 4× HP). The crowd tests count damage dealt over 45 s.
- Anvil columns: `boss_block`, `swarm_block` (an invulnerable Vanguard holding the lane in Anvil range), `bosswalk`, `swarm`, `armored`.
- Frost and Beacon deal little or no damage themselves, so their numbers are the damage of two maxed reference towers placed beside them (Arcane hex+surge+quick, Plasma hot+burn+auto). Their `swarm` column maxes out (1,667,325 = the whole wave), so ignore it.
- The hero is stunned and moved off-map (except in the Anvil block tests). Boss powers are switched off. Hero level-up popups are cleared every frame.
- If a path id changes or a reference path id disappears, update `_add_ref` and the combos. Path ids are NOT supposed to change in this rebalance.

## Before numbers (origin/main 7f92758): `baseline/`
`sim_<tower>.csv` are the combos and `simS_<tower>.csv` the singles. Best build per test:

| Tower | boss dps | bosswalk | swarm | armored | fast |
|---|---|---|---|---|---|
| Arcane | 2,005 | 33,711 | 269,566 | 163,135 | 105,489 |
| Plasma | 717 | 17,575 | 578,242 | 223,854 | 173,971 |
| Tesla | 132 | 2,275 | 95,013 | 60,540 | 60,024 |
| Laser | 3,013 | 44,117 | 162,044 | 249,358 | 77,509 |
| Mortar | 3,244 | 96,335 | 1,473,370 | 732,575 | 586,051 |
| Disc | 11,606 (zone-stacking exploit) | 83,563 | 731,961 | 1,261,351 | 664,284 |
| Anvil (boss_block, swarm_block, bosswalk, swarm, armored) | 1,595 | 1,617,040 | 859 | 1,224,808 | 16,673 |
| Frost (via refs) | 7,875 | 385,688 | (capped) | 2,154,000 | 1,061,025 |
| Beacon (via refs) | 13,674 | 476,401 | (capped) | 1,566,883 | 782,214 |

Path values (×, with vs without the path) and top-3 counts are printed by `analyze.py baseline`. The headline problems: Disc Searing Path ×6.33 boss / 14 of 15, Quick Loader 15/15, Frost Brittle ×2.67, Laser Focusing Lens ×2.93, Mortar Quick Reload 13/15, Tesla Static Shock 4/15, Arcane Runes 2/15, Disc Reaper Edge 4/15.

`prototype/` holds the same runs for disc, frost, tesla, laser and mortar with the throwaway `prototype_reference.diff` applied (X1 + X2 + Disc Volley/Loader + Tesla base). They're there to sanity-check the target bands only.
