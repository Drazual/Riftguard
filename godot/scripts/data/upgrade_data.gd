## Every kind of upgrade, relic and power uses this. Which fields matter depends on the list it is in.
## `effect` is code that runs when it is picked. Names you can use:
##   h = the hero, h.ab = its ability, run = the run (gold, lives, mod_* bonuses), m = strength
##   (base strength x rarity), r = rank (menu upgrades), k = curse strength.
## `desc` is a template: parts in {braces} are worked out, e.g. "+{pct(m)} hero damage."
@tool
class_name UpgradeData
extends Resource

@export var id := ""
@export var name := ""
@export_multiline var desc := ""
@export_multiline var effect := ""
## Base strength (m before rarity).
@export var m := 0.0
## Who can be offered it: any, offensive, defensive, support, or a hero id.
@export var pool := "any"
@export var also_pools: PackedStringArray = []
## Only for this ability (slam, nova, bulwark, ...). Empty = any.
@export var ability := ""
@export_enum("any", "common", "uncommon", "rare", "mythic", "legendary", "secret") var rarity := "any"
@export_enum("any", "common", "uncommon", "rare", "mythic", "legendary", "secret") var min_rarity := "any"
## Gold upgrades only appear at Legendary or rarer, and not every time (rules gold_perk_chance).
@export var gold := false
## Attack speed upgrade (never offered to the Wizard).
@export var attack_speed := false
## Wizard: only when the run's spells can freeze, wall or push.
@export var needs := ""
## Wizard: only when this element is taken.
@export var element := ""
## Upgrade "kind" so one roll never offers two of the same kind.
@export var kind := ""
@export_group("Menu upgrades")
@export var max_rank := 10
## Cost of the next rank; r is the current rank.
@export var cost := "60 + 50 * r"
## Optional "Label" and value template for the "current -> next" preview.
@export var stat_label := ""
@export var stat_value := ""
@export_group("Wave modes")
## How hard a Hard/Challenge rule is (rewards scale with the total).
@export var pts := 0
@export_group("Shop, relics and specials")
@export var price := 0
@export var shop_kind := "Tower"
## Can be taken again.
@export var repeat := false
@export var offensive_only := false
## Heroic powers: which heroes get them.
@export var heroes: PackedStringArray = []
## Specials: Boss Core cost and the hero it belongs to.
@export var cores := 0
@export var hero := ""
