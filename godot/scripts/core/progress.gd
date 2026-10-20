## Progress outside a run: mastery levels, the Wizard's elements and spellbook numbers.
class_name Progress
extends RefCounted

const BASE_ELS := ["fire", "water", "earth", "air"]
const SLOT_KEYS := ["q", "w", "e", "r"]
## How many points one unit of each role's mastery stat is worth (a kill, or 100 damage blocked).
const ROLE_PER := { defensive = 100.0, offensive = 1.0, support = 1.0, special = 1.0 }
const ROLE_NAME := { defensive = "damage blocked", offensive = "kills", support = "assisted kills", special = "kills" }


static func mastery_need(lvl: int) -> int:
	return 10 * lvl * (lvl + 1)


static func _beaten(won: Dictionary) -> int:
	var n := 0
	while n < DB.map_order.size() and won.get(DB.map_order[n], false):
		n += 1
	return n


static func hero_stat(k: String) -> float:
	var hs: Dictionary = Save.meta.hero_stat
	if hs.has(k):
		return float(hs[k])
	return float(Save.meta.kills.heroes.get(k, 0)) * ROLE_PER[DB.heroes[k].category]


## kind is "towers" or "heroes".
static func mastery_of(kind: String, k: String) -> Dictionary:
	var kills: int
	if kind == "heroes":
		kills = int(floor(hero_stat(k) / ROLE_PER[DB.heroes[k].category]))
	else:
		kills = int(Save.meta.kills[kind].get(k, 0))
	var beaten := _beaten(Save.meta.wins[kind].get(k, {}))
	var mx: int = DB.rules.mastery_max
	var cap := mini(mx, 10 * (beaten + 1))
	var raw := int(floor((sqrt(1 + 0.4 * kills) - 1) / 2))
	var lvl := mini(raw, cap)
	return { kills = kills, lvl = lvl, cap = cap, capped = raw >= cap and cap < mx, prev = mastery_need(lvl), next = mastery_need(lvl + 1) if lvl < mx else -1,
		next_map = DB.map_order[beaten] if beaten < DB.map_order.size() else "" }


## Element mastery: 1 point for every 10 mana spent on spells that use the element.
static func el_mastery(el: String, extra := 0.0) -> Dictionary:
	var pts := int(floor(float(Save.meta.el_stat.get(el, 0)) + extra))
	var beaten := _beaten(Save.meta.wins.heroes.get("wizard", {}))
	var mx: int = DB.rules.mastery_max
	var cap := mini(mx, 10 * (beaten + 1))
	var lvl := mini(cap, int(floor((sqrt(1 + 0.4 * pts) - 1) / 2)))
	return { pts = pts, lvl = lvl, cap = cap, prev = mastery_need(lvl), next = mastery_need(lvl + 1) if lvl < mx else -1 }


static func can_triple(el: String) -> bool:
	return el_mastery(el).lvl >= DB.rules.triple_at


## Secret heroes stay locked until their unlock is earned.
static func hero_open(k: String) -> bool:
	return not DB.heroes[k].secret or bool(Save.meta.secret_heroes.get(k, false))


static func el_open(el: String) -> bool:
	if BASE_ELS.has(el) or bool(Save.meta.wiz_els.get(el, false)):
		return true
	var par: String = DB.elements[el].parent if DB.elements.has(el) else ""
	return par != "" and el_mastery(par).lvl >= DB.rules.element_unlock_at


## The elements taken on the next run (saved picks still open, at most 4; by default the first owned).
static func wiz_loadout() -> Array:
	var src = Save.meta.get("wiz_load")
	var picks: Array = []
	var from: Array = src if src is Array else Array(DB.el_order).filter(el_open)
	for el in from:
		if el_open(el) and picks.size() < SLOT_KEYS.size():
			picks.append(el)
	return picks if picks.size() else BASE_ELS.duplicate()


static func spell_key(els: Array) -> String:
	var k := els.duplicate()
	k.sort_custom(func(a, b): return DB.el_order.find(a) < DB.el_order.find(b))
	return "+".join(k)


## The spells a set of elements can cast: each alone and twice, every pair, and the triple of each mastered element.
static func spells_for(els: Array, triples = null) -> Array:
	var tr: Array = triples if triples != null else els.filter(can_triple)
	var e2 := Array(DB.el_order).filter(func(e): return els.has(e))
	var out := []
	for e in e2:
		out.append(e)
	for e in e2:
		out.append(e + "+" + e)
	for k in DB.spells:
		var p: PackedStringArray = k.split("+")
		if p.size() == 2 and p[0] != p[1] and e2.has(p[0]) and e2.has(p[1]):
			out.append(k)
	for e in e2:
		if tr.has(e):
			out.append(e + "+" + e + "+" + e)
	return out


## A stand-in Wizard for spellbook numbers outside a run.
static func book_hero() -> Hero:
	var h := Hero.new()
	h.cls = "wizard"
	h.data = DB.heroes.get("wizard")
	if h.data:
		var M: Dictionary = Save.hero_meta("wizard")
		for def in h.data.meta:
			var r := Save.rank(M, def.id)
			if r:
				Fx.run(def.effect, { h = h, run = null, r = r })
	return h


static func spell_desc(key: String, h: Hero, p: float, wave := 1) -> String:
	var sp: SpellData = DB.spells[key]
	return DB.tx("spell:" + key, Fx.text(sp.desc, { sp = sp, h = h, p = p, wave = wave }))
