## A tower on the board. Path, mastery and fusion effects in the data files change these numbers
## (for example `t.dmg *= 1.2` or `t.chain += 1`).
class_name Tower
extends RefCounted

## Numbers merges keep the stronger value of (the original game's TRAITS list).
const TRAITS := ["splash", "slow", "slow_dur", "chain", "chain_mul", "chain_reach", "multi", "ramp", "surge", "burn", "brittle", "mark", "cluster", "orbital",
	"freeze", "zero", "stun", "prism", "execute", "nova", "echo", "death_blast", "gravity", "time_lock", "shatter", "frostfire", "storm", "chain_blast", "overload",
	"pierce", "loot", "leech", "tempo", "hex", "hex_nova", "hypo", "cold_snap", "crush", "b_dmg", "b_rate", "b_range", "b_sunder", "b_gold", "b_overdrive", "b_tempo",
	"b_light", "b_break", "b_rush"]

var type := ""
var c := 0
var r := 0
var x := 0.0
var y := 0.0
var lvl := 1
var dmg := 0.0
var rate := 1.0
var range := 100.0
var support := false
var color := Color.WHITE
var name := ""
var desc := ""
var hybrid := false
var is_super := false
var perfected := false
var parents: PackedStringArray = []
var tags: PackedStringArray = []
var fusions: Array = [] # FusionData
var up_start := 0
## Which enemy in range it shoots: "first" (farthest along the path), "strong" (most HP), "close" (nearest the tower) or "last" (nearest the entrance).
var aim := "first"

# Beacon buffs this tower gives (and Rift Beacon path bonuses).
var b_dmg := 0.0
var b_rate := 0.0
var b_range := 0.0
var b_sunder := 0.0
var b_gold := 0.0
var b_overdrive := 0.0
var b_tempo := 0.0
var b_light := 0.0
var b_break := 0.0
var b_rush := 0.0
# Grave Anvil
var press := 0.25
var press_cap := 1.5
var pin := 0.0
var shackle := false
var after := false
var tide := false
var guard := 0.0
var pact := false
var crush_exec := 0.0
var crush := 0.0
# attack traits
var splash := 0.0
var slow := 0.0
var slow_dur := 1.6
var chain := 0.0
var chain_mul := 0.7
var chain_reach := 95.0
var chain_keep := false
var multi := 0.0
var ramp := 0.0
var ramp_max := 5.0
var surge := 0.0
var burn := 0.0
var brittle := 0.0
var mark := 0.0
var cluster := 0.0
var orbital := 0.0
var freeze := 0.0
var zero := 0.0
var stun := 0.0
var prism := 0.0
var execute := 0.0
var nova := 0.0
var echo := 0.0
var death_blast := 0.0
var gravity := 0.0
var time_lock := 0.0
var shatter := 0.0
var frostfire := 0.0
var storm := 0.0
var chain_blast := 0.0
var overload := 0.0
var pierce := 0.0
var loot := 0.0
var leech := 0.0
var tempo := 0.0
var tempo_stacks := 0.0
var hex := 0.0
var hex_nova := 0.0
var hypo := 0.0
var cold_snap := 0.0
var beam := false
var retain := false
var melt := false
var lob := false
var firestorm := false
var salvo := 0.0
var quake_stun := false

# state
var stun_t := 0.0
var stun_max := 0.0
var warn_t := 0.0
# a boss curse: less damage, slower attacks or less range, for curse_t seconds
var curse_dmg := 0.0
var curse_rate := 0.0
var curse_range := 0.0
var curse_t := 0.0
# Hero Shrine: buffs to the hero, from its hero-tailored paths
var hero_buff := false
var hb_dmg := 0.0
var hb_rate := 0.0
var hb_armor := 0.0
var hb_regen := 0.0
var hb_cdr := 0.0
var hb_range := 0.0
var hb_block := 0.0
var hb_knock := 0.0
var hb_crit := 0.0
var hb_boss := 0.0
var hb_aura := 0.0
var hb_spell := 0.0
var hb_mana := 0.0
var hb_shield := 0.0
var hb_bruiser := 0.0
var hb_bounce := 0.0
var buff = null # Dictionary or null
var cd := 0.0
var shots := 0
var stacks := 0.0
var spent := 0
var base_cost := 0
var ups := {}
var rk := {}
var order: Array = []
var free_ups := 0
var dmg_wave := 0.0
var dmg_total := 0.0
var kills := 0
var takedowns := 0
var last_target = null
var shot_at := -99.0
var fired_at := -99.0
var hit_at = null # Vector2 or null
var ascend_t := 0.0
var sp_t := 0.0
var sp_idx := -1


## Points put into a path (used by fusion effects such as Static Web).
func ups_of(id: String) -> int:
	return int(ups.get(id, 0))


func pos() -> Vector2:
	return Vector2(x, y)


func base_types() -> PackedStringArray:
	return parents if parents.size() else PackedStringArray([type])


func duplicate_for_preview() -> Tower:
	var t := Tower.new()
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v = get(p.name)
			if v is Dictionary or v is Array:
				v = v.duplicate()
			t.set(p.name, v)
	return t
