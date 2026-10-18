## One of a tower's 5 upgrade paths. Each level-up puts a point into a path; the last point unlocks its mastery.
## Effects are small bits of code: `t` is the tower and `rank` is the path's new rank (1 to 4).
## Example: "t.dmg *= 1.2" or "t.slow = min(0.85, t.slow + 0.07)". Several statements go on separate lines.
@tool
class_name TowerPath
extends Resource

@export var id := ""
@export var name := ""
## Merge tag: decides which fusion effects a hybrid made from this tower can learn.
@export_enum("power", "arcane", "precision", "speed", "burst", "burn", "slow", "chain", "multi") var tag := "power"
## Words used to name the ascended form: adjective, noun, title ("Runic Glyph of Runes").
@export var adjective := ""
@export var noun := ""
@export var title := ""
@export_multiline var desc := ""
## Runs once for every rank this path gains.
@export_multiline var effect := ""
@export var mastery_name := ""
@export_multiline var mastery_desc := ""
## Runs once when the path is maxed.
@export_multiline var mastery_effect := ""
