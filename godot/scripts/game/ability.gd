## The hero's ability during a run: its numbers (from AbilityData) plus the ability upgrades picked so far.
class_name Ability
extends RefCounted

var id := ""
var name := ""
var cd := 18.0
var dmg := 0.0
var r := 0.0
var stun := 0.0
var dur := 0.0
var power := 0.0
var mult := 0.0
var w := 0.0
var desc := ""
var t := 0.0 # cooldown left
var haste := 0.0
# ability upgrades (ability_mods)
var rings := false
var magnet := false
var molten := false
var echo := false
var twin := false
var hole := false
var chain_n := false
var dash := false
var mobile := false
var chrono := false
var burst := false
var prism_f := false
var rail := false
var bounce := false
var cluster := false
var spiked := false
var overflow := false
var bloodrush := false
var afterimg := false
var shatter_s := false
var anchor := false
var carpet := false
var scorch := false
var exec_r := false


static func from_data(a: AbilityData) -> Ability:
	var b := Ability.new()
	if a == null:
		return b
	for k in ["id", "name", "cd", "dmg", "r", "stun", "dur", "power", "mult", "w", "desc"]:
		b.set(k, a.get(k))
	return b


func copy() -> Ability:
	var b := Ability.new()
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			b.set(p.name, get(p.name))
	return b


func has_mod(mod_id: String) -> bool:
	var v = get(DB.mod_prop(mod_id))
	return v == true
