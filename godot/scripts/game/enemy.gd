## One enemy walking the path.
class_name Enemy
extends RefCounted

var type := ""
var data: EnemyData
var boss := false
var hp := 1.0
var max := 1.0
var speed := 50.0
var d := 0.0 # distance along the path
var x := 0.0
var y := 0.0
var r := 9.0
var color := Color.RED
var gold := 5.0
var lives := 1
var atk := 8.0
var armor := 0.0
var aura_armor := 0.0
var regen := 0.0
var steady := false
var unslow := false
var pushback_immune := false # push-back, knockback and pulls along the path do nothing
var phase := false
var split := 0
var heal := 0.0
var shield_aura := 0.0
var slow := 0.0
var slow_t := 0.0
var stun_t := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var burn_src = null
var mark_t := 0.0
var mark := 0.0
var brittle := 0.0
var brittle_t := 0.0
var brk := 0.0
var brk_t := 0.0
var taken := 0.0
var still_t := 0.0
var hex := 0.0
var hex_t := 0.0
var hex_tick := 1.0
var hex_src = null
var hex_nova := 0.0
var heal_t := 1.0
var slowed_for := 0.0
var push_t := 0.0
var push_spd := 0.0
var taunt_t := 0.0
var spot := 0.0
var spot_t := 0.0
var chill := 0
var blocked := false
var dead := false
var fake := false
var hit_by := {} # Tower or "hero" -> true
# bosses
var pow_t := -1.0
var summons := 0
var enraged := false


func pos() -> Vector2:
	return Vector2(x, y)
