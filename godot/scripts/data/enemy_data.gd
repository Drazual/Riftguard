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
@export_range(0.0, 0.6) var armor := 0.0
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
