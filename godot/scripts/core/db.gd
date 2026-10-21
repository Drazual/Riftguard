## Loads the game's data (res://data/rules.tres and everything it points to) and keeps quick lookups.
## Change numbers in the Inspector by opening the .tres files under res://data.
extends Node

const RULES_PATH := "res://data/rules.tres"

var rules: GameRules
var maps := {} # id -> MapInfo
var map_order: PackedStringArray = []
var towers := {} # id -> TowerData
var tower_order: PackedStringArray = []
var heroes := {} # id -> HeroData
var hero_order: PackedStringArray = []
var enemies := {} # id -> EnemyData
var special_enemies: PackedStringArray = []
var spells := {} # "fire+water" -> SpellData
var elements := {} # id -> ElementData
var el_order: PackedStringArray = []
var fusions: Array = [] # FusionData
var recipes := {} # "arcane+frost" -> RecipeData (hybrids and supers)
var simple_texts := {}
var rarities: Array = [] # {id, name, mult, w}
var rar := {}


func _ready() -> void:
	load_all()


func load_all() -> void:
	rules = load(RULES_PATH)
	maps.clear()
	map_order.clear()
	for ps in rules.maps:
		if ps == null:
			continue
		var m := MapInfo.load_scene(ps)
		maps[m.id] = m
		map_order.append(m.id)
	towers.clear()
	tower_order.clear()
	for t in rules.towers:
		towers[t.id] = t
		tower_order.append(t.id)
	heroes.clear()
	hero_order.clear()
	for h in rules.heroes:
		heroes[h.id] = h
		hero_order.append(h.id)
	enemies.clear()
	special_enemies.clear()
	for e in rules.enemies:
		enemies[e.id] = e
		if e.first_wave > 0:
			special_enemies.append(e.id)
	spells.clear()
	for s in rules.spells.items:
		spells[s.runes] = s
	elements.clear()
	el_order.clear()
	for e in rules.elements.items:
		elements[e.id] = e
		el_order.append(e.id)
	fusions = rules.fusions.items.duplicate()
	recipes.clear()
	for r in rules.recipes.items:
		recipes[r.key] = r
	simple_texts = rules.simple_texts.texts if rules.simple_texts else {}
	rarities.clear()
	rar.clear()
	var ids := ["common", "uncommon", "rare", "mythic", "legendary", "secret", "secret_mythic", "secret_legendary", "developer"]
	for i in ids.size():
		var x := { id = ids[i], name = rules.rarity_names[i], mult = rules.rarity_mults[i], w = rules.rarity_weights[i] }
		rarities.append(x)
		rar[ids[i]] = x


## Simple explanation for a key when Simple mode is on, else the detailed text.
func tx(key: String, detailed: String) -> String:
	if Save.settings.get("simple", false) and simple_texts.has(key):
		return simple_texts[key]
	return detailed


func is_simple() -> bool:
	return bool(Save.settings.get("simple", false))


func hero_ability(id: String) -> AbilityData:
	var d: HeroData = heroes[id]
	if Save.meta.get("abilities", {}).get(id, "") == "alt" and d.alt:
		return d.alt
	return d.ability


func recipe_for(types: Array) -> RecipeData:
	var k := types.duplicate()
	k.sort()
	return recipes.get("+".join(k))


## Ability upgrade id (chainN) -> its flag on the ability (chain_n).
func mod_prop(mod_id: String) -> String:
	return mod_id.to_snake_case()


func color_hex(c: Color) -> String:
	return "#" + c.to_html(false)
