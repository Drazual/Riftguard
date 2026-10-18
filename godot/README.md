# Riftguard in Godot

This folder is the Godot 4 version of Riftguard. Open it with **Godot 4.7** (the standard build, not .NET):
Project Manager → Import → pick `godot/project.godot`. Press **F5** to play.

The browser/Electron version in `src/` still works and is untouched. The two don't share code.

## Where things live

| Folder | What's in it |
|---|---|
| `data/` | Every game number, as Resource files you edit in the Inspector |
| `maps/` | One scene per map, painted with tiles |
| `art/` | Animations (SpriteFrames) built from the sprite sheets in `assets/` |
| `assets/` | The original art, music and fonts |
| `ui/` | The interface theme (colours, button art, fonts) |
| `scripts/` | The code: `game/` rules, `board/` drawing, `ui/` menus and panels, `core/` saving, sound, updates |
| `tests/` | A bot that plays runs headless, and a screenshot tour of the screens |
| `tools/` | One-off scripts that generated the data, art and theme from the JS version |

## Changing numbers

Double-click any `.tres` in `data/` and change values in the Inspector. Save, then play.

- `data/rules.tres`: run-wide numbers. Starting gold and lives, wave gold, XP curve, spawn gaps, shard rewards, the map list.
- `data/towers/*.tres`: each tower's cost, damage, rate, range, colour and its five upgrade paths.
- `data/heroes/*.tres`: each hero's HP, damage, speed, abilities and sprite sheet.
- `data/enemies/*.tres`: HP, speed, armor, gold, which wave they first show up.
- `data/lists/*.tres`: lists of upgrades. Hero upgrades (`perks`), uniques, relics, curses, the boss shop, heroic powers, menu upgrades (`global_meta`, `tower_global`, `specials`), wave challenges.
- `data/spells.tres`, `elements.tres`, `recipes.tres`, `fusions.tres`: the Wizard's spells, tower merges and boons.

### Effects and descriptions

Upgrades say what they do in two text fields.

- **effect** is a tiny piece of code that runs when you take the upgrade, one statement per line, for example `h.dmg *= 1 + m` or `t.range += 10 * r`.
- **desc** is the text players see. Anything in `{braces}` is worked out, for example `+{pct(m)} hero damage.`

The names you can use:

| Name | Means |
|---|---|
| `h` | the hero |
| `t` | a tower |
| `run` | the current run |
| `m` | the upgrade's strength after rarity |
| `r` | its rank, for menu upgrades |
| `k` | a curse's strength |

A typo prints a warning in the Output panel and that one effect is skipped, so the game keeps running.

## Editing a map

Open a scene in `maps/`. It has two tile layers and a marker:

- **Ground**: road, grass, water. The road must be one connected line of path tiles.
- **Props**: decorations. You can't build on them.
- **Spawn**: enemies enter at the path tile nearest this marker and walk to the other end, where the base is.

Select a layer, open the TileMap panel at the bottom, and paint. The map's name, waves, difficulty and theme are on the root node in the Inspector.

To add a map, duplicate a scene, give it a new `id`, and add it to the `maps` list in `data/rules.tres`. The order there is the unlock order.

## Changing art

Sprites are animations in `art/`. Open one to see its frames and speed in the SpriteFrames panel. To swap a picture, replace the PNG in `assets/` with one laid out the same way. To change timing or frames, edit the `.tres` in `art/`.

The look of the interface (panel colours, button art, fonts) is in `ui/theme.tres`.

## Testing

From a terminal in this folder:

```
godot --headless --path . res://tests/sim.tscn -- verdant 5
```

This runs a bot through 5 waves with every hero and prints how far each got. Any `SCRIPT ERROR` line means something broke.

## Releases and auto-update

Every push to `main` that touches `godot/` runs `.github/workflows/godot.yml`. That workflow tests the game, exports `Riftguard.exe` and publishes a GitHub release tagged `godot-v<version>`. The version is `config/version` from `project.godot` (major.minor) plus the build number.

When the game starts on Windows, it checks those releases. If there's a newer one, it downloads it, swaps the exe and restarts. Offline or failed checks just start the game. To raise the major or minor version, change `config/version` in Project Settings → Application → Config.

To export by hand, use Project → Export → Windows. The export templates come from Editor → Manage Export Templates.
