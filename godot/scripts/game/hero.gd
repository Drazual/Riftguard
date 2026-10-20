## The hero during a run. Upgrades in the data files change these numbers (for example `h.dmg *= 1.2`).
class_name Hero
extends RefCounted

var cls := ""
var data: HeroData
var x := 0.0
var y := 0.0
var tx = null # move target x (float or null)
var ty = null
var px := 0.0
var py := 0.0
var base_hp := 200.0
var hp := 200.0
var max_hp := 200.0
var dmg := 10.0
## Damage and spell power at the start of the run (after shard upgrades). Common, uncommon and rare damage
## upgrades add a share of these; mythic and higher ones multiply the damage as it is now.
var base_dmg := 10.0
var base_spell := 1.0
## The Sniper's targeting choice, like a tower's: first, last, strong (most HP, so bosses first) or close.
var target := "strong"
var rate := 0.6
## Seconds between attacks at the start of the run. Common to legendary attack speed upgrades add a share
## of this speed; mythic and higher ones multiply the speed as it is now.
var base_rate := 0.6
var cd := 0.0
var range := 100.0
var block := 1
var regen := 2.0
var armor := 0.0
var speed := 140.0
var ko := 0.0
var lvl := 1
var xp := 0.0
var next := 30.0
var build_range := 170.0
var respawn := 8.0
var thorns := 0.0
var aura := 0.0
var aura_range := 130.0
var aura_slow := 0.0
var siphon := 0.0
var cost_mul := 1.0
var lvl_mul := 1.0
var merge_mul := 1.0
var crit := 0.0
var crit_dmg := 1.5
var multi := 0.0
var bounty := 0.0
var tower_range := 0.0
var interest := 0.0
var brace := 0.0
var brace_t := 0.0
var pierce := 0.0
var deadeye := 0.0
var shot_stun := 0.0
var grounded := 0.0
var execute := 0.0
var bullet_storm := 0.0
var attacks := 0
var unbreakable := false
var unbreak_left := 1
var unbreak_max := 1
var tithe := 0.0
var taunt := 0.0
var momentum := 0.0
var mom_stacks := 0
var mom_t := 0.0
var rapid := 0.0
var spotter := 0.0
var headhunter := 0.0
var dance_kills := 0
var time_warp := 0.0
var auto_cast := false
var ab: Ability
var shield := 0.0
var shield_max := 0.0
var shield_t := 0.0
var soaked := 0.0
var od_t := 0.0
var od_bonus := 0.0
var boon_slow := 0.0
var boon_splash := 0.0
var boon_rail := 0.0
var boon_vent := 0.0
var boon_chain := 0.0
var boon_ion := 0.0
var xp_gain := 0.0
var ret_store := 0.0
var ret_t := 4.0
var barrage_t := 5.0
var mana := 0.0
var max_mana := 0.0
var mana_regen := 0.0
var spell := 1.0
var spell_r := 1.0
var spell_cost := 1.0
var freeze_bonus := 0.0
var push_bonus := 1.0
var wall_bonus := 1.0
# Wizard wall charges: how many are ready, seconds banked toward the next, and the recharge-time multiplier
var wall_charges := 0
var wall_t := 0.0
var wall_cd_mul := 1.0
var wall_dmg := 0.0 # damage per second (x spell power) to enemies held up by a wall
var echo := 0.0
var el_pow := {}
var els: PackedStringArray = []
var can := {}
var hold := false
# Gale: how far each normal hit pushes enemies back, and the Bruiser Form switch
var knock := 0.0
var bruiser := false
var knock_slow := 0.0
# Mythic and Legendary upgrades
var free_cast := 0.0
var mana_shield := false
var aegis := false
var debt := 0.0
var free_build := 0
var ab_crit := false
var lifesteal := 0.0
var overkill := false
# boss debuffs on the hero
var stun_t := 0.0
var weak := 0.0
var weak_t := 0.0
var shred := 0.0
var shred_t := 0.0
var drag := 0.0
var drag_t := 0.0
var aim_x := 0.0
var aim_y := 0.0
var atk_at := -99.0
var cast_t := 0.0
var casts := 0


static func make(id: String, base: Vector2) -> Hero:
	var d: HeroData = DB.heroes[id]
	var h := Hero.new()
	h.cls = id
	h.data = d
	h.x = base.x - 80
	h.y = base.y - 60 if base.y > 120 else base.y + 60
	h.base_hp = d.hp
	h.hp = d.hp
	h.max_hp = d.hp
	h.dmg = d.dmg
	h.rate = d.rate
	h.base_rate = d.rate
	h.range = d.range
	h.block = d.block
	h.regen = d.regen
	h.armor = d.armor
	h.speed = d.speed
	h.aura = d.aura
	h.crit = d.crit
	h.brace = d.brace
	h.mana = d.mana
	h.max_mana = d.mana
	h.mana_regen = d.mana_regen
	h.knock = d.knock
	h.wall_charges = DB.rules.wall_charges
	h.build_range = DB.rules.build_range
	h.aura_range = DB.rules.aura_range
	h.respawn = DB.rules.respawn
	h.next = DB.rules.hero_first_level_xp
	h.ab = Ability.from_data(DB.hero_ability(id))
	return h


## Tank level-up growth: max HP from the hero's base HP, damage reduction and regen.
func grow_tank(hp_frac: float, armor_add: float, regen_frac: float) -> void:
	var add := roundf(base_hp * hp_frac)
	max_hp += add
	hp = minf(max_hp, hp + add)
	armor = minf(0.75, armor + armor_add)
	regen += max_hp * regen_frac


## Gale's Bruiser Form: far more damage and a bit tougher, but holds a set number of enemies instead of every one.
func bruiser_form() -> void:
	if bruiser:
		return
	bruiser = true
	dmg *= 3.5
	rate /= 1.25
	block = DB.rules.bruiser_block
	max_hp = roundf(max_hp * 1.2)
	hp = max_hp
	armor = minf(0.75, armor + 0.05)
	knock *= 1.5


## Elemental Attunement: spells using this element deal more damage (several stack).
func attune(el: String, m: float) -> void:
	el_pow[el] = float(el_pow.get(el, 1.0)) * (1.0 + m)


func pos() -> Vector2:
	return Vector2(x, y)


func copy() -> Hero:
	var h := Hero.new()
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var v = get(p.name)
			if v is Dictionary or v is Array or v is PackedStringArray:
				v = v.duplicate()
			h.set(p.name, v)
	h.ab = ab.copy()
	return h
