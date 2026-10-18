## An enemy type. HP grows every wave (see GameRules).
@tool
class_name EnemyData
extends Resource

@export var id := ""
@export var name := ""
@export var hp := 50.0
@export var speed := 50.0
@export var gold := 5
## Base HP lost if it gets through.
@export var lives := 1
## Damage per second to a hero or wall blocking it.
@export var atk := 8.0
@export var radius := 9.0
@export var color := Color.RED
@export_range(0.0, 0.8) var armor := 0.0
## Immune to slows (stuns still work).
@export var unslow := false
## Only Defensive heroes can block it.
@export var phase := false
## Splits into this many Runners when it dies.
@export var split := 0
## Heals nearby enemies this share of their max HP every second.
@export var heal := 0.0
## Gives nearby enemies this much extra armor.
@export var shield_aura := 0.0
## Special enemies: the first wave it shows up, and how many come each time.
@export var first_wave := 0
@export var per_wave := 0
@export_multiline var info := ""
@export_multiline var counter := ""
@export_group("Boss")
@export var boss := false
## Big bosses end the run if they reach the base.
@export var big_boss := false
@export var cores := 0
@export var power_name := ""
@export var power_every := 0.0
@export var power_towers := 0
@export var power_stun := 0.0
## Stuns the nearest tower instead of random ones.
@export var power_nearest := false
## Also knocks the hero back.
@export var power_roar := false
## Also stuns the hero for this many seconds (Grounded makes it shorter).
@export var power_hero_stun := 0.0
## Only stuns the hero within this distance of the boss (0 = anywhere on the map).
@export var power_hero_reach := 0.0
## A curse on the towers it hits: weaken = less damage, jam = slower attacks, blind = less range.
@export_enum("none", "weaken", "jam", "blind") var power_tower_curse := "none"
## How strong the tower curse is (0.3 = 30% less).
@export_range(0.0, 0.9) var power_tower_curse_amt := 0.0
## A curse on the hero: shred = takes more damage, weaken = less damage, drag = slower moving and attacking.
@export_enum("none", "shred", "weaken", "drag") var power_hero_curse := "none"
@export_range(0.0, 0.9) var power_hero_curse_amt := 0.0
## How long both curses last, in seconds.
@export var power_curse_dur := 0.0
