## Everything about the run in progress. Upgrades in the data files can change the public numbers here
## (for example `run.mod_tower_dmg += 0.15` or `run.lives += 6`).
class_name Run
extends RefCounted

var map: MapInfo
var map_id := ""
var gold := 150.0
var lives := 20
var start_lives := 20
var boss_kills := 0
var log: Array = []
var ws = null # this wave's log entry (Dictionary)
var drained = null # Tower
var boons := {}
var pending_boon := ""
var ion_t := 6.0
var shrine := {} # Hero Shrine buffs to the hero, summed (see Game.sb)
var shrine_t := 4.0
var strike_ready := false # Orbital Strike: readied, fires on the next press
var wiz_pushes := 0 # enemies the Wizard pushed back this run (toward the secret unlock)
var pending_secret := ""
var boss_proof := false # Heart of the Rift: bosses can't stun or curse towers
var wave := 0
var wave_active := false
var spawn_q: Array = []
var spawn_t := 0.0
var interval := 0.9
var enemies: Array = [] # Enemy
var towers: Array = [] # Tower
var fx: Array = [] # Dictionary
var sel = null # Tower
## The hero is selected (clicked): shows its attack range.
var hero_sel := false
var build := ""
var merge_from = null
var pending_build = null # {c, r, type}
var paused := true
var user_pause := false
var over := false
var speed := 1
var pending_levels := 0
var pending_heroic := 0
var hover = null # Vector2i
var rerolls := 2
var time := 0.0
var mode := { kind = "normal", name = "Normal" }
var relics: Array = [] # UpgradeData
var picks: Array = [] # offers
var heroics := {}
var overclock_t := 0.0
var overclock_at := Vector2.ZERO
var stasis_t := 0.0
var stasis_at := Vector2.ZERO
var time_stop_t := 25.0
var echoes: Array = []
var zones: Array = []
var walls: Array = []
var art: Array = []
var runes: Array = []
var rune_keys := {}
var delayed: Array = []
var shells: Array = []
## Razor Disc projectiles in flight.
var discs: Array = []
var proj: Array = []
var beams: Array = []
var kills := { hero = 0, towers = {} }
var takedowns := { hero = 0, towers = {} }
var built := {}
var bought := {}
var blocked := 0.0
var assists := 0
var cores := 0
var specials := {}
var second_chance := false
var boss_warned := false
var pointer = null # Vector2 or null
var aim = null # Vector2 or null
var coins: Array = []
var loadout: Array = []
var sig := {}
var path_bonus := 0
var free_levels := 0
var need_shop := false
var need_choice := false
var shops := 0
var req_failed := false
var req_limit := 0.0
var lose_reason := ""
var one_shot_ready := false
var tide := false
var drone_cd := 0.0
var el_cd := {}
var el_mana := {}
var triples: PackedStringArray = []
var hero: Hero
# run-wide modifiers
var mod_tower_dmg := 1.0
var mod_slow := 0.0
var mod_gold := 1.0
var mod_tower_rate := 1.0
var mod_enemy_hp := 1.0
var mod_enemy_speed := 1.0
var mod_phoenix := false
var mod_all_slow := 0.0
var mod_all_burn := 0.0
var mod_boss_dmg := 0.0


## Rift Crown: every tower you own gains 2 free levels of damage.
func crown() -> void:
	for t in towers:
		t.dmg *= 1.6


## A copy for "current -> new" previews of upgrades.
func copy_mods() -> Dictionary:
	var out := {}
	for k in ["gold", "lives", "path_bonus", "free_levels", "pending_levels", "mod_tower_dmg", "mod_slow", "mod_gold", "mod_tower_rate", "mod_enemy_hp",
			"mod_enemy_speed", "mod_phoenix", "mod_all_slow", "mod_all_burn", "mod_boss_dmg"]:
		out[k] = get(k)
	return out


func restore_mods(d: Dictionary) -> void:
	for k in d:
		set(k, d[k])
