## A hero. Base stats here; per-hero permanent upgrades are in `meta`.
@tool
class_name HeroData
extends Resource

@export var id := ""
@export var name := ""
@export var role := "Offensive"
@export_enum("offensive", "defensive", "support", "special") var category := "offensive"
@export var color := Color.WHITE
@export_multiline var desc := ""
@export var hp := 200.0
@export var dmg := 10.0
## Seconds between attacks.
@export var rate := 0.6
## 9999 = the whole map.
@export var range := 100.0
## How many enemies it can hold at once (999 = all).
@export var block := 1
@export var armor := 0.0
@export var regen := 2.0
@export var speed := 140.0
@export var aura := 0.0
## Seconds it must stand still before each shot (Sniper).
@export var brace := 0.0
@export var crit := 0.0
## How far each normal hit pushes the enemy back along the path (Gale).
@export var knock := 0.0
@export var mana := 0.0
@export var mana_regen := 0.0
## Casts spells instead of attacking (Wizard).
@export var spells := false
@export var ability: AbilityData
@export var alt: AbilityData
## Permanent upgrades bought with Rift Shards on the Heroes page.
@export var meta: Array[UpgradeData] = []
## The hero's animations: idle_N, walk_N and fire_N for each facing N (0 = north, then clockwise).
@export var frames: SpriteFrames
## 10 rows (idle 1-2, walk 1-4, fire 1-4) by 8 facings of 48px frames (the source of the animations above).
@export var sheet: Texture2D
