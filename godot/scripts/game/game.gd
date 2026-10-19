## The rules of a run: waves, enemies, towers, the hero, abilities, spells, upgrades and rewards.
## The numbers live in the data files (res://data); this script is what they plug into.
## The board (board.gd) draws the state and the UI (ui/*.gd) shows it; both listen to the signals below.
class_name Game
extends Node

signal toast(msg: String)
signal changed(what: String) # build_bar, inspector, hero, codex, enemy_codex, mode, runes
signal modal(kind: String, data: Dictionary) # level_up, boon, heroic, shop, wave_choice, end
signal shake(intensity: float, ms: float)

const W := 960.0
const H := 600.0
const C := 40.0
const COLS := 24
const ROWS := 15
const ALL_BLOCK := 999
const SLOT_KEYS := ["q", "w", "e", "r"]
const SHOT_SPEED := 800.0
const ATK_FPS := 24.0
const ORACLE_RANKS := [0, 2, 3, 4]
const BOSS_CORES := { knight = 1, warden = 2, tyrant = 5 }
const BIG_BOSS := { warden = true, tyrant = true }
const SHRINE_KEYS := ["dmg", "rate", "armor", "regen", "cdr", "range", "block", "knock", "crit", "boss", "aura", "spell", "mana", "shield", "bruiser"]

var S: Run = null
var _spilling := false
var R: GameRules
var max_wave := 20
var rng := RandomNumberGenerator.new()
var held := {} # movement keys held
var key_move := true


func _ready() -> void:
	R = DB.rules
	key_move = bool(Save.settings.get("keys", true))


static func col(x: int) -> Color:
	return Color.hex((x << 8) | 0xff)


func rnd() -> float:
	return randf()


func pick(arr: Array):
	return null if arr.is_empty() else arr[randi() % arr.size()]


func shuffle(arr: Array) -> Array:
	arr.shuffle()
	return arr


func say(msg: String) -> void:
	toast.emit(msg)


func refresh(what: String) -> void:
	changed.emit(what)


func sfx(name: String) -> void:
	Sound.play(name)


func do_shake(intensity: float, ms: float) -> void:
	shake.emit(intensity, ms)


func pct(v: float) -> String:
	return str(int(round(v * 100))) + "%"


# ---------- effects ----------
func ring(x: float, y: float, r: float, color, t: float, fill := false, more := {}) -> Dictionary:
	var f := { k = "ring", x = x, y = y, r = r, color = _c(color), t = t, T = t, fill = fill }
	f.merge(more, true)
	S.fx.append(f)
	return f


func line(x1: float, y1: float, x2: float, y2: float, color, t: float, w: float, more := {}) -> Dictionary:
	var f := { k = "line", x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = _c(color), t = t, T = t, w = w }
	f.merge(more, true)
	S.fx.append(f)
	return f


func fx_add(f: Dictionary) -> void:
	if f.has("color"):
		f.color = _c(f.color)
	if not f.has("T"):
		f.T = f.t
	S.fx.append(f)


func later(secs: float, fn: Callable) -> void:
	S.delayed.append({ at = S.time + secs, fn = fn })


func zone(z: Dictionary) -> Dictionary:
	if z.has("color"):
		z.color = _c(z.color)
	if not z.has("T"):
		z.T = z.t
	for k in ["dps", "slow", "brk", "end_freeze"]:
		if not z.has(k):
			z[k] = 0.0
	S.zones.append(z)
	return z


# ---------- lookups ----------
func map() -> MapInfo:
	return S.map


func pos_at(d: float) -> Vector2:
	return S.map.pos_at(d)


func tower_data(t) -> TowerData:
	return DB.towers.get(t.type if t is Tower else t)


func hero_cat() -> String:
	return S.hero.data.category


func rank(obj, id: String) -> int:
	return Save.rank(obj, id)


func map_price() -> float:
	return S.map.scene.price


func has_tough(id: String) -> bool:
	return S.mode.has("tough") and (S.mode.tough as Array).has(id)


func in_range(x: float, y: float, r: float) -> Array:
	var out := []
	var r2 := r * r
	for e in S.enemies:
		if not e.dead and (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y) <= r2:
			out.append(e)
	return out


func by_d_desc(a, b) -> bool:
	return a.d > b.d


func live_enemies() -> Array:
	return S.enemies.filter(func(e): return not e.dead)


# ---------- a new run ----------
func new_run(map_id: String) -> void:
	var m: MapInfo = DB.maps[map_id]
	var G: Dictionary = Save.meta.global
	S = Run.new()
	S.map = m
	S.map_id = map_id
	S.gold = R.start_gold + 15 * rank(G, "gold")
	S.lives = R.start_lives + int(round(1.5 * rank(G, "lives")))
	S.start_lives = S.lives
	S.rerolls = R.rerolls + rank(G, "reroll")
	S.specials = Save.meta.specials.duplicate()
	S.second_chance = bool(S.specials.get("second", false))
	S.mod_enemy_hp = m.scene.enemy_hp
	S.loadout = Array(DB.tower_order).slice(0, R.loadout_size)
	max_wave = m.scene.waves


func start_run(hero_id: String, towers: Array) -> void:
	Save.meta.loadout = { hero = hero_id, towers = towers.duplicate() }
	Save.save_meta()
	S.loadout = towers.duplicate()
	S.sig = {}
	for k in towers:
		if Save.tower_meta(k).get("sig", 0):
			S.sig[k] = true
	S.hero = Hero.make(hero_id, S.map.base)
	apply_hero_meta(S.hero)
	apply_specials(S.hero)
	S.paused = false
	if S.hero.data.spells:
		var load := wiz_loadout()
		var h := S.hero
		S.rune_keys = {}
		for i in load.size():
			S.rune_keys[SLOT_KEYS[i]] = load[i]
		S.triples = PackedStringArray(load.filter(can_triple))
		var text := ""
		for k in spells_for(load, S.triples):
			text += " " + spell_desc(k, book_hero(), 1.0).to_lower()
		h.els = PackedStringArray(load)
		var push_re := RegEx.create_from_string("push|blow|hurl|drag|back along")
		h.can = { freeze = text.contains("freez"), wall = text.contains("wall"), push = push_re.search(text) != null }
	for w in ["build_bar", "inspector", "codex", "enemy_codex", "hero"]:
		refresh(w)
	say(S.hero.data.name + " ready. Build towers, then start the wave.")


func apply_hero_meta(h: Hero) -> void:
	var M: Dictionary = Save.hero_meta(h.cls)
	for def in h.data.meta:
		var r := rank(M, def.id)
		if r:
			Fx.run(def.effect, { h = h, run = S, r = r })
	h.hp = h.max_hp
	h.respawn *= 1 - 0.05 * rank(Save.meta.global, "recovery")
	var vet := rank(Save.meta.global, "vet")
	S.pending_levels += int(floor((vet + 2) / 3.0))
	h.xp_gain += 0.04 * vet


func give_unique(id: String) -> void:
	var u: UpgradeData = R.uniques.find(id)
	if u == null:
		return
	Fx.run(u.effect, { h = S.hero, run = S, m = u.m })
	S.picks.append({ perk = u, list = "unique", rarity = DB.rar.legendary, demonic = false, m = u.m })


func apply_specials(h: Hero) -> void:
	var sp := S.specials
	if sp.get("bulwarkS", false) and h.cls == "vanguard":
		give_unique("aegis")
		give_unique("unbreak")
		h.unbreak_max = 2
		h.unbreak_left = 2
	if sp.get("galeS", false) and h.cls == "gale":
		give_unique("bruiser")
	if sp.get("sovereign", false):
		var pool := R.uniques.items.filter(func(x): return x.rarity == "legendary" and x.pool == h.cls and (x.ability == "" or x.ability == h.ab.id) and not owns(x.id))
		var u = pick(pool)
		if u:
			give_unique(u.id)
	h.hp = h.max_hp


# ---------- prices ----------
func count_type(type: String) -> int:
	var n := 0
	for t in S.towers:
		if t.type == type or t.parents.has(type):
			n += 1
	return n


func tower_cost(type: String) -> int:
	var mine: int = S.bought.get(type, 0)
	var all := 0
	for k in S.bought:
		all += S.bought[k]
	return int(round(DB.towers[type].cost * pow(R.own_price_growth, mine) * pow(R.other_price_growth, all - mine) * S.hero.cost_mul * map_price()))


func path_max() -> int:
	return 3 if S.hero and S.hero.cls == "oracle" else R.path_max


func path_limit() -> int:
	return R.path_limit + (1 if S.hero.cls == "oracle" else 0) + S.path_bonus


func level_cost(t: Tower, opt) -> int:
	if S.free_levels > 0 or t.free_ups > 0:
		return 0
	var n := t.ups_of(opt.id) if opt else 0
	var base: float
	if t.hybrid:
		base = t.up_start * (1 + 0.3 * n)
	else:
		base = t.base_cost * (R.oracle_level_cost_mult if path_max() == 3 else R.level_cost_mult) * (n + 1)
	return int(round(base * R.level_cost_extra * S.hero.lvl_mul * (1 - 0.025 * rank(Save.meta.tower_global, "cost")) * map_price()))


func hybrid_up_start(parents: PackedStringArray, sup: bool) -> int:
	var m := 0
	for k in parents:
		m = maxi(m, DB.towers[k].cost)
	return int(round(2 * (R.max_level - 1) * m * (1.5 if sup else 1.0)))


func merge_cost(t) -> int:
	if t and t.hybrid:
		return R.super_cost
	return int(round(R.merge_cost * S.hero.merge_mul * map_price()))


func t_range(t: Tower) -> float:
	var b := 1.0
	if t.buff:
		b = (1 + t.buff.range) * (2.0 if t.buff.light else 1.0)
	return t.range * (1 + S.hero.tower_range) * b * (1 - t.curse_range if t.curse_t > 0 else 1.0)


func tower_name(t: Tower) -> String:
	if t.name != "":
		return t.name
	if t.hybrid:
		return DB.recipes[t.type].name
	return DB.towers[t.type].name


func tower_blurb(t: Tower) -> String:
	if t.is_super:
		return DB.tx("super:" + "+".join(t.parents), t.desc)
	if t.hybrid:
		return DB.tx("recipe:" + t.type, DB.recipes[t.type].desc)
	return DB.tx("tower:" + t.type, DB.towers[t.type].info)


func tower_kind(t: Tower) -> String:
	return "Super " if t.is_super else "Hybrid " if t.hybrid else ""


func level_key(t: Tower) -> String:
	if not t.hybrid and DB.towers.has(t.type):
		return DB.towers[t.type].level_bonus
	return "dmg"


func level_text(t: Tower) -> String:
	var k := level_key(t)
	return _dot(DB.tx("level:" + k, R.get("level_%s_text" % k)))


func ascend_text(t: Tower) -> String:
	var k := level_key(t)
	return _dot(DB.tx("ascend:" + k, R.get("ascend_%s_text" % k)))


func _dot(s: String) -> String:
	return s if s.ends_with(".") or s.ends_with("!") else s + "."


func owns(id: String) -> bool:
	for p in S.picks:
		if p.perk.id == id:
			return true
	return false


func wiz_loadout() -> Array:
	return Progress.wiz_loadout()


func can_triple(el) -> bool:
	return Progress.can_triple(el)


func spells_for(els: Array, triples = null) -> Array:
	return Progress.spells_for(els, triples)


func book_hero() -> Hero:
	return Progress.book_hero()


func spell_desc(key: String, h: Hero, p: float) -> String:
	return Progress.spell_desc(key, h, p, wave_no())


func wave_no() -> int:
	return S.wave if S and S.wave else 1


# ---------- small helpers ----------
func _c(v) -> Color:
	return v if v is Color else col(int(v))


func dist(a, b) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length()


func hyp(x: float, y: float) -> float:
	return sqrt(x * x + y * y)


func tower_mode_mul() -> float:
	var ch = S.mode.get("challenge", "")
	return R.lone_tower if ch == "lone" else R.weak_tower if ch == "weak" else 1.0


func hero_dmg() -> float:
	var h := S.hero
	return h.dmg * (R.lone_hero if S.mode.get("challenge", "") == "lone" else 1.0) * (1 + sb("dmg")) * (1 - h.weak if h.weak_t > 0 else 1.0)


## A Hero Shrine buff to the hero (dmg, rate, armor, regen, cdr, range, block, knock, crit, boss, aura, spell, mana, shield).
func sb(k: String) -> float:
	return S.shrine.get(k, 0.0) if S else 0.0


## A tank's ability damage: the ability's own number plus a small share of the hero's max HP.
func ab_dmg(h: Hero, a: Ability) -> float:
	return a.dmg + (h.max_hp * R.tank_ability_hp if h.data.category == "defensive" else 0.0)


func hero_range(h: Hero) -> float:
	return h.range if h.range >= 9999 else h.range * (1 + sb("range"))


func spell_pow(h: Hero) -> float:
	return h.spell * (R.lone_hero if S and S.mode.get("challenge", "") == "lone" else 1.0) * (1 + sb("spell"))


func is_sprite_tower(t: Tower) -> bool:
	return not t.hybrid and DB.towers.has(t.type) and DB.towers[t.type].sheet != null


func fire_lead(t: Tower) -> float:
	return DB.towers[t.type].fire_frame / ATK_FPS if is_sprite_tower(t) else 0.0


func overclocked(t: Tower) -> bool:
	return S.overclock_t > 0 and S.overclock_at.distance_to(t.pos()) <= S.hero.ab.r


func near_aura(t: Tower) -> bool:
	var h := S.hero
	return h.ko <= 0 and h.pos().distance_to(t.pos()) <= h.aura_range


## The Oracle's aura covers exactly its build range: anything that grows one grows the other.
func sync_aura(h: Hero) -> void:
	if h.cls == "oracle":
		h.aura_range = maxf(h.aura_range, h.build_range)
		h.build_range = h.aura_range


func cores_for(type: String) -> int:
	if type == "tyrant" and S.map.scene.tyrant_cores:
		return S.map.scene.tyrant_cores
	return BOSS_CORES.get(type, 0)


func slow_enemy(e: Enemy, amt: float, dur := 1.6) -> void:
	if e.unslow:
		return
	e.slow = minf(0.85, maxf(e.slow, (amt + S.mod_slow) * (0.5 if e.steady else 1.0)))
	e.slow_t = maxf(e.slow_t, dur if dur else 1.6)


func seg_dist(px: float, py: float, z: Dictionary) -> float:
	var vx: float = z.x2 - z.x1
	var vy: float = z.y2 - z.y1
	var l := vx * vx + vy * vy
	if l == 0:
		l = 1
	var k := clampf(((px - z.x1) * vx + (py - z.y1) * vy) / l, 0, 1)
	return hyp(px - z.x1 - k * vx, py - z.y1 - k * vy)


# ---------- combat ----------
## Armor: % damage taken off, capped. Brittle enemies have none; Shieldbearers add to it; Sunder and Armor Break cut it.
func armor_of(e: Enemy, src) -> float:
	if e.brittle_t > 0:
		return 0.0
	var a := e.armor + e.aura_armor - (e.brk if e.brk_t > 0 else 0.0)
	if src is Tower and src.buff:
		a -= src.buff.sunder
	return clampf(a, 0, R.boss_armor_cap if e.boss else R.armor_cap)


## src: the Tower that dealt it, or null for the hero and spells.
## pierce: 0 normal, 1 ignores armor (burns, zones, executes), 2 = Hex Brand pulse (ignores armor and doesn't feed the brand).
func damage(e: Enemy, amt: float, src = null, pierce := 0) -> void:
	if e.dead:
		return
	var tw: bool = src is Tower
	amt *= 1 + (e.mark if e.mark_t > 0 else 0.0) + (e.brittle if e.brittle_t > 0 else 0.0) + (e.spot if e.spot_t > 0 and tw else 0.0) + (S.mod_boss_dmg if e.boss and tw else 0.0)
	if tw and src.curse_t > 0:
		amt *= 1 - src.curse_dmg
	if not pierce:
		amt *= 1 - armor_of(e, src)
	var dealt := minf(amt, e.hp)
	if pierce != 2:
		e.taken += dealt
	if tw:
		src.dmg_wave += dealt
		src.dmg_total += dealt
	elif S.ws:
		S.ws.hero_dmg += dealt
	# everything that hurt this enemy gets a takedown when it dies; whatever lands the final hit also gets the kill
	if dealt > 0:
		e.hit_by[src if tw else "hero"] = true
	e.hp -= amt
	var h := S.hero
	if not tw and h.lifesteal and dealt > 0 and h.ko <= 0:
		h.hp = minf(h.max_hp, h.hp + dealt * h.lifesteal)
	if e.hp <= 0:
		var spill := -e.hp
		_kill(e, src)
		# Overkill: what a hero hit had left over moves on to the nearest enemy
		if not tw and h.overkill and spill > 1 and not _spilling:
			var next: Enemy = null
			for o in in_range(e.x, e.y, 120):
				if not o.dead and (next == null or hyp(o.x - e.x, o.y - e.y) < hyp(next.x - e.x, next.y - e.y)):
					next = o
			if next:
				_spilling = true
				line(e.x, e.y, next.x, next.y, 0xff8a3d, 0.15, 2)
				damage(next, spill, null, 1)
				_spilling = false


func _kill(e: Enemy, src) -> void:
	e.dead = true
	var h := S.hero
	var by_hero: bool = not (src is Tower)
	var g: float = e.gold * S.mod_gold + (h.bounty if by_hero else 0.0) + h.tithe
	if not by_hero and src.buff and src.buff.gold:
		g *= 1 + src.buff.gold
	if not by_hero and src.buff and src.buff.rush and randf() < 0.08:
		S.coins.append({ x = e.x, y = e.y, t = 0.0 })
	if S.heroics.get("goldrush", 0) and randf() < 0.08 * S.heroics.goldrush:
		g += 15
		ring(e.x, e.y, 14, 0xf2c14e, 0.5, true)
	S.gold += g
	h.xp += e.gold * (1 + h.xp_gain)
	if S.ws:
		S.ws.kills += 1
		S.ws.gold += g
	if by_hero:
		S.kills.hero += 1
	else:
		src.kills += 1
		for k in src.base_types():
			S.kills.towers[k] = S.kills.towers.get(k, 0) + 1
		# support mastery: kills by towers the hero is boosting (inside its aura or its field)
		if hero_cat() == "support" and (near_aura(src) or overclocked(src)):
			S.assists += 1
	for u in e.hit_by:
		if u is String:
			S.takedowns.hero += 1
			continue
		u.takedowns += 1
		if S.towers.has(u):
			for k in u.base_types():
				S.takedowns.towers[k] = S.takedowns.towers.get(k, 0) + 1
	if e.split:
		for i in e.split:
			spawn("runner", maxf(0, e.d - 8 + 16 * i))
	if e.hex_t > 0 and e.hex_nova:
		var boom := e.taken * e.hex_nova
		ring(e.x, e.y, 80, 0xb07cff, 0.45, true)
		for o in in_range(e.x, e.y, 80):
			damage(o, boom, e.hex_src, 2)
	if e.boss:
		S.boss_kills += 1
		S.cores += cores_for(e.type)
		ring(e.x, e.y, 80, 0xff6fd8, 0.9, true)
		do_shake(0.012, 350)
	# tanks heal only from their own takedowns: enemies they hit or were holding when it died
	if h.siphon and h.ko <= 0 and (hero_cat() != "defensive" or e.hit_by.has("hero") or e.blocked):
		h.hp = minf(h.max_hp, h.hp + h.siphon)
	if by_hero:
		if h.momentum:
			h.mom_stacks = mini(10, h.mom_stacks + 1)
			h.mom_t = 4
		if h.od_t > 0 and h.ab.bloodrush and h.od_bonus < 4:
			h.od_t += 0.4
			h.od_bonus += 0.4
		if S.specials.get("oneshot", false) and h.brace:
			h.brace_t = maxf(h.brace_t, h.brace * 0.5)
		if S.specials.get("dancer", false) and h.cls == "striker":
			h.dance_kills += 1
			if h.dance_kills % 8 == 0:
				later(0.05, func(): if S.hero.ko <= 0: cast_ability(true))
	while h.xp >= h.next:
		level_hero(h)
	sfx("kill")
	if not by_hero:
		if src.loot:
			S.gold += src.loot
		if src.leech and h.ko <= 0:
			h.hp = minf(h.max_hp, h.hp + src.leech)
			h.xp += 1
		if src.death_blast:
			ring(e.x, e.y, 55, 0xff8a3d, 0.25, true)
			for o in in_range(e.x, e.y, 55):
				damage(o, e.max * src.death_blast, src)
	if e.boss:
		var n := cores_for(e.type)
		if e.type != "tyrant":
			S.pending_heroic += 1
		say(e.data.name + " defeated! +" + str(n) + " Boss Core" + ("s" if n > 1 else "") + (" and a heroic power." if e.type != "tyrant" else "."))
	ring(e.x, e.y, e.r + 6, e.color, 0.3)


func level_hero(h: Hero) -> void:
	h.xp -= h.next
	h.lvl += 1
	h.next = roundf(h.next * R.hero_xp_growth)
	S.pending_levels += 1
	var code = R.get("level_" + h.data.category)
	if code is String:
		Fx.run(code, { h = h, run = S })


## One hit from a tower. aura_slow: the Oracle's Chilling Presence for towers in its aura.
func apply_hit(t: Tower, e: Enemy, dmg: float, frz := false, aura_slow := 0.0) -> void:
	if t.shatter and e.stun_t > 0:
		dmg *= 1 + t.shatter
	if t.crush and (e.stun_t > 0 or e.blocked or e.taunt_t > 0):
		dmg *= 1 + t.crush
	var pierce := 0
	if t.execute and not e.boss and (e.hp - dmg) / e.max <= t.execute:
		dmg = e.hp + 1
		pierce = 1
	if t.frostfire and e.slow_t > 0:
		e.burn_dps = maxf(e.burn_dps, dmg * t.frostfire / 2)
		e.burn_t = 2
		e.burn_src = t
	if t.frostfire and e.burn_t > 0:
		slow_enemy(e, minf(0.5, t.frostfire / 3), 1)
	if S.mod_all_slow:
		slow_enemy(e, S.mod_all_slow, 1.2)
	if S.mod_all_burn:
		e.burn_dps = maxf(e.burn_dps, dmg * S.mod_all_burn / 2)
		e.burn_t = 2
		e.burn_src = t
	damage(e, dmg, t, pierce)
	if t.slow:
		slow_enemy(e, t.slow, t.slow_dur)
	if t.brittle:
		e.brittle = maxf(e.brittle, t.brittle)
		e.brittle_t = maxf(e.brittle_t, t.slow_dur if t.slow_dur else 1.6)
	var hx := t.hex
	if not hx and S.sig.get("arcane", false) and t.base_types().has("arcane") and t.shots % 5 == 0:
		hx = 0.02
	if hx:
		e.hex = maxf(e.hex, hx)
		e.hex_t = 4
		e.hex_src = t
		e.hex_nova = maxf(e.hex_nova, t.hex_nova)
	if t.buff and t.buff.brk:
		e.brk = minf(0.45, (e.brk if e.brk_t > 0 else 0.0) + 0.15)
		e.brk_t = 3
	if t.mark:
		e.mark = maxf(e.mark, t.mark)
		e.mark_t = 2
	if t.burn:
		e.burn_dps = maxf(e.burn_dps, dmg * t.burn / 2)
		e.burn_t = 2
		e.burn_src = t
	if frz:
		e.stun_t = maxf(e.stun_t, 1.2)
	if t.hypo and not e.dead:
		e.chill += 1
		if e.chill >= t.hypo:
			e.chill = 0
			e.stun_t = maxf(e.stun_t, 0.3 if e.boss else 0.8)
			ring(e.x, e.y, e.r + 8, 0xdff6ff, 0.45, true)
			if t.cold_snap:
				for o in in_range(e.x, e.y, 70):
					if o != e:
						o.stun_t = maxf(o.stun_t, 0.2 if o.boss else 0.5)
				ring(e.x, e.y, 70, 0x9fe6ff, 0.5, true)
	if aura_slow:
		slow_enemy(e, aura_slow, 1)


## Shots fly in game time, so the hit lands exactly when the projectile reaches its target.
func launch_shot(k: String, from: Vector2, target, wait: float, on_hit: Callable, src = null) -> void:
	if S.proj.size() >= 300:
		on_hit.call()
		return
	S.proj.append({ k = k, x = from.x, y = from.y, x0 = from.x, y0 = from.y, target = target, x1 = target.x, y1 = target.y, t = 0.0, T = 0.0, u = 0.0,
		wait = wait, on_hit = on_hit, src = src, done = false })


func move_shots(dt: float) -> void:
	for p in S.proj:
		if p.wait > 0:
			p.wait -= dt
			if p.wait > 0:
				continue
		if not p.T:
			p.T = maxf(0.05, hyp(p.target.x - p.x0, p.target.y - p.y0) / SHOT_SPEED)
		p.t += dt
		if not p.target.dead:
			p.x1 = p.target.x
			p.y1 = p.target.y
		var u := minf(1.0, p.t / p.T)
		p.u = u
		p.x = p.x0 + (p.x1 - p.x0) * u
		p.y = p.y0 + (p.y1 - p.y0) * u
		if u >= 1:
			p.done = true
			p.on_hit.call()
	S.proj = S.proj.filter(func(p): return not p.done)


func fire(t: Tower, targets: Array, mult := 1.0) -> void:
	var h := S.hero
	var oc := overclocked(t)
	t.shots += 1
	if not t.lob:
		t.shot_at = S.time
	t.fired_at = S.time
	t.hit_at = Vector2(targets[0].x, targets[0].y) if targets.size() else null
	var dmg := t.dmg * mult * S.mod_tower_dmg * tower_mode_mul()
	var aura := h.aura > 0 and near_aura(t)
	if aura:
		dmg *= 1 + h.aura * (1 + sb("aura"))
	if t.buff:
		dmg *= 1 + t.buff.dmg
		if t.buff.overdrive and randf() < 0.1:
			dmg *= 3
	if t.surge and t.shots % int(t.surge) == 0:
		dmg *= 3
	var over := t.overload > 0 and t.shots % 10 == 0
	if over:
		dmg *= 1 + t.overload
	var big := t.orbital > 0 and t.shots % int(t.orbital) == 0
	var frz := t.freeze > 0 and t.shots % int(t.freeze) == 0
	if t == S.drained:
		dmg *= 0.5
	if not t.beam:
		sfx("boom" if t.splash else "shot")
	var aslow := h.aura_slow if aura else 0.0
	var art := is_sprite_tower(t)
	for target in targets:
		var d := dmg
		if t.ramp:
			if t.last_target == target:
				t.stacks = minf(t.ramp_max if t.ramp_max else 5.0, t.stacks + (2 if t.beam and S.sig.get("laser", false) else 1))
			else:
				t.stacks = floorf(t.stacks / 2) if t.retain else 0.0
				t.last_target = target
			d *= 1 + t.ramp * t.stacks
			if t.melt and t.stacks >= t.ramp_max:
				d *= 2
		var splash := t.splash * (2 if big else 1)
		if big:
			d *= 3
		if not art and t.beam:
			line(t.x, t.y, target.x, target.y, Color.WHITE if t.stacks >= t.ramp_max else t.color, 0.22, 2 + t.stacks * 0.2)
		elif not art and not t.lob:
			line(t.x, t.y, target.x, target.y, t.color, 0.12, 3 if t.hybrid else 2)
		# Everything the shot does happens when it lands: sprite towers fire a projectile and the hit waits for it.
		var land := func(): _land(t, target, d, splash, big, frz, over, oc, aslow, art)
		if art and not t.beam and not t.lob and not (target is Dictionary):
			launch_shot(t.type, t.pos(), target, fire_lead(t), land, t)
		else:
			land.call()
	if oc and h.ab.prism_f:
		var extra = null
		for e in in_range(t.x, t.y, t_range(t)):
			if not targets.has(e):
				extra = e
				break
		if extra:
			apply_hit(t, extra, dmg * 0.7, false, aslow)
			line(t.x, t.y, extra.x, extra.y, 0xff6fd8, 0.15, 3)


## A shot landing. target is an Enemy, or a Dictionary {x, y, d, dead, fake} for a mortar shell's landing spot.
func _land(t: Tower, target, d: float, splash: float, big: bool, frz: bool, over: bool, oc: bool, aslow: float, art: bool) -> void:
	var h := S.hero
	var fake: bool = target is Dictionary
	var hits: Array = in_range(target.x, target.y, splash) if splash else ([] if fake else [target])
	if splash:
		ring(target.x, target.y, splash, t.color, 0.25, big)
	if splash and S.sig.get("plasma", false) and t.base_types().has("plasma"):
		zone({ x = target.x, y = target.y, r = splash * 0.7, t = 2.0, dps = d * 0.25, color = col(0xff8a3d), src = t })
	for e in hits:
		apply_hit(t, e, d, frz, aslow)
		if over:
			e.stun_t = maxf(e.stun_t, 0.5)
	if t.prism:
		var n := 0
		for o in in_range(target.x, target.y, 90):
			if hits.has(o):
				continue
			if n >= int(round(t.prism)):
				break
			n += 1
			line(target.x, target.y, o.x, o.y, t.color, 0.12, 1)
			apply_hit(t, o, d * 0.4, false, aslow)
	if t.pierce:
		var behind := S.enemies.filter(func(e): return not e.dead and e != target and e.d < target.d and e.d > target.d - 140)
		behind.sort_custom(by_d_desc)
		for o in behind.slice(0, int(round(t.pierce))):
			apply_hit(t, o, d * 0.6, false, aslow)
	if t.gravity and t.shots % 5 == 0:
		for e in in_range(target.x, target.y, 60):
			if not e.pushback_immune:
				e.d = maxf(0, e.d - t.gravity)
		ring(target.x, target.y, 60, 0x9a7cff, 0.3)
	if t.echo and not fake:
		S.echoes.append({ t = t, target = target, d = d * t.echo, at = S.time + 0.25, aslow = aslow })
	if t.cluster:
		var near := in_range(target.x, target.y, 90).filter(func(e): return e != target)
		near.shuffle()
		var cr := (t.splash if t.splash else 30.0) * 0.6
		for n in near.slice(0, int(t.cluster)):
			ring(n.x, n.y, cr, t.color, 0.2)
			for e in in_range(n.x, n.y, cr):
				apply_hit(t, e, d * 0.5, false, aslow)
	var chain_n := int(t.chain) + (1 if oc and h.ab.chrono else 0)
	if chain_n:
		var keep: bool = (S.sig.get("tesla", false) and t.base_types().has("tesla")) or t.chain_keep
		var hit := {}
		for e in hits:
			hit[e] = true
		var from = target
		var cd := d * (1.0 if keep else t.chain_mul)
		var wait := 0.0
		for i in chain_n:
			var best = null
			var bd := t.chain_reach
			for e in S.enemies:
				if e.dead or hit.has(e):
					continue
				var dd := hyp(e.x - from.x, e.y - from.y)
				if dd < bd:
					bd = dd
					best = e
			if best == null:
				break
			var n: Enemy = best
			var hd := cd
			var jump := func():
				apply_hit(t, n, hd, false, aslow)
				if t.chain_blast:
					for o in in_range(n.x, n.y, 40):
						if o != n:
							damage(o, hd * t.chain_blast, t)
				if t.stun and randf() < t.stun:
					n.stun_t = maxf(n.stun_t, 0.6)
			if art and t.beam:
				if S.beams.size() < 60:
					S.beams.append({ x0 = from.x, y0 = from.y, e = n, t = 0.22 })
				jump.call()
			elif art:
				launch_shot(t.type, Vector2(from.x, from.y), n, wait, jump, from)
				wait += bd / SHOT_SPEED
			else:
				line(from.x, from.y, n.x, n.y, t.color, 0.15, 1.5)
				jump.call()
			hit[n] = true
			from = n
			if not keep:
				cd *= 0.85


## Siege Mortar: shells fly slowly toward where the target will be (leading it along the path) and blast on landing.
func lob_shell(t: Tower, e: Enemy, mult: float) -> void:
	var speed := 170.0 * (1.4 if S.sig.get("mortar", false) else 1.0)
	var wait := fire_lead(t)
	var T := maxf(0.6, hyp(e.x - t.x, e.y - t.y) / speed)
	var lead := 0.0 if e.stun_t > 0 or e.blocked else e.speed * (1 - e.slow) * (T + wait)
	var p := pos_at(minf(S.map.path_len, e.d + lead))
	T = maxf(0.6, hyp(p.x - t.x, p.y - t.y) / speed)
	t.shot_at = S.time
	S.shells.append({ tw = t, x0 = t.x, y0 = t.y, x1 = p.x, y1 = p.y, t = 0.0, T = T, mult = mult, wait = wait, done = false })


func land_shell(sh: Dictionary) -> void:
	var t: Tower = sh.tw
	if not S.towers.has(t):
		return
	var spot := { x = sh.x1, y = sh.y1, d = -1.0, dead = false, fake = true }
	var keep := t.splash
	if S.sig.get("mortar", false):
		t.splash *= 1.2
	fire(t, [spot], sh.mult)
	var r := t.splash * (2.0 if t.orbital and t.shots % int(t.orbital) == 0 else 1.0)
	t.splash = keep
	if t.firestorm:
		zone({ x = spot.x, y = spot.y, r = r * 0.8, t = 3.0, dps = t.dmg * S.mod_tower_dmg * 0.25, color = col(0xff8a3d), src = t })
	if t.quake_stun and t.shots % 4 == 0:
		for e in in_range(spot.x, spot.y, r):
			e.stun_t = maxf(e.stun_t, 0.3 if e.boss else 0.8)
		ring(spot.x, spot.y, r + 15, 0xfff0a0, 0.5)
	do_shake(0.004, 110)


## Effects that trigger once per shot rather than per target.
func shot_effects(t: Tower, dmg: float) -> void:
	var R_ := t_range(t)
	if t.nova and t.shots % 6 == 0:
		for e in in_range(t.x, t.y, R_):
			apply_hit(t, e, dmg * t.nova)
		ring(t.x, t.y, R_, t.color, 0.3)
	if t.time_lock and t.shots % 8 == 0:
		for e in in_range(t.x, t.y, R_):
			e.stun_t = maxf(e.stun_t, t.time_lock)
		ring(t.x, t.y, R_, 0xb07cff, 0.3, true)
	if t.storm and t.shots % 4 == 0:
		var list := in_range(t.x, t.y, R_)
		list.shuffle()
		for e in list.slice(0, int(round(t.storm))):
			apply_hit(t, e, dmg * 0.8)
			line(e.x, e.y - 200, e.x, e.y, 0x8affff, 0.2, 2)


func beacon_power(b: Tower) -> float:
	return b.b_dmg + b.b_rate + b.b_range + b.b_sunder + b.b_gold


## Rift Beacon: each tower takes the strongest Beacon in reach (two with Twin Signal).
func compute_buffs() -> void:
	S.shrine = {}
	for b in S.towers:
		if b.hero_buff and not (b.stun_t > 0):
			# a boss curse on the Shrine weakens what it gives the hero
			var cut := 1.0 - (maxf(b.curse_dmg, maxf(b.curse_rate, b.curse_range)) if b.curse_t > 0 else 0.0)
			for k in SHRINE_KEYS:
				var v := float(b.get("hb_" + k))
				S.shrine[k] = S.shrine.get(k, 0.0) + (v if k == "bruiser" or k == "block" else v * cut)
	var beacons := S.towers.filter(func(b): return (b.support or b.b_dmg > 0) and not b.hero_buff and not (b.stun_t > 0))
	for t in S.towers:
		t.buff = null
		if t.support or t.hero_buff or beacons.is_empty():
			continue
		var near := beacons.filter(func(b): return b != t and b.pos().distance_to(t.pos()) <= t_range(b))
		if near.is_empty():
			continue
		near.sort_custom(func(a, b): return beacon_power(a) > beacon_power(b))
		near = near.slice(0, 2 if S.sig.get("beacon", false) else 1)
		var f := { dmg = 0.0, rate = 0.0, range = 0.0, sunder = 0.0, gold = 0.0, overdrive = false, tempo = false, light = false, brk = false, rush = false, from = near }
		for b in near:
			f.dmg += b.b_dmg
			f.rate += b.b_rate
			f.range += b.b_range
			f.sunder += b.b_sunder
			f.gold += b.b_gold
			f.overdrive = f.overdrive or b.b_overdrive > 0
			f.tempo = f.tempo or (b.b_tempo > 0 and fmod(S.time, 10.0) < 3)
			f.light = f.light or b.b_light > 0
			f.brk = f.brk or b.b_break > 0
			f.rush = f.rush or b.b_rush > 0
		t.buff = f


## Grave Anvil: crushes enemies that aren't moving; moving ones take 30%.
func anvil_slam(t: Tower, area: Array, mult: float) -> void:
	var h := S.hero
	t.shots += 1
	t.fired_at = S.time
	t.hit_at = t.pos()
	var base := t.dmg * S.mod_tower_dmg * mult * tower_mode_mul()
	if h.aura and near_aura(t):
		base *= 1 + h.aura * (1 + sb("aura"))
	if t.buff:
		base *= 1 + t.buff.dmg
		if t.buff.overdrive and randf() < 0.1:
			base *= 3
	if t == S.drained:
		base *= 0.5
	var hits := area.duplicate()
	if S.sig.get("anvil", false):
		for o in S.enemies:
			if o.dead or area.has(o):
				continue
			for e in area:
				if absf(o.d - e.d) <= 80:
					hits.append(o)
					ring(o.x, o.y, 14, t.color, 0.25)
					break
	for e in hits:
		var stopped: bool = e.stun_t > 0 or e.blocked or e.taunt_t > 0
		var d := base * (1 + minf(t.press_cap, t.press * e.still_t) if stopped else 0.3)
		if stopped and t.crush_exec and not e.boss and (e.hp - d) / e.max <= t.crush_exec:
			damage(e, e.hp + 1, t, 1)
			ring(e.x, e.y, e.r + 10, 0xffffff, 0.4, true)
			continue
		apply_hit(t, e, d)
		if stopped and t.pin:
			e.stun_t = maxf(e.stun_t, t.pin / 2 if e.boss else t.pin)
	if t.shackle and t.shots % 4 == 0:
		for e in hits:
			e.stun_t = maxf(e.stun_t, 0.5 if e.boss else 1.0)
		ring(t.x, t.y, t_range(t) + 10, 0x9a7cff, 0.5)
	ring(t.x, t.y, t_range(t), t.color, 0.35, true)
	if mult >= 1:
		do_shake(0.002, 90)
	sfx("boom")
	if t.after and mult >= 1:
		later(0.5, func():
			if not S.towers.has(t):
				return
			var a := in_range(t.x, t.y, t_range(t))
			if a.size():
				anvil_slam(t, a, 0.5))


func super_power(t: Tower) -> bool:
	var R_ := t_range(t)
	var area := in_range(t.x, t.y, R_)
	if area.is_empty():
		return false
	t.sp_idx = (t.sp_idx + 1) % t.parents.size()
	var k: String = t.parents[t.sp_idx]
	var d: float = t.dmg * S.mod_tower_dmg * (1 + t.buff.dmg if t.buff else 1.0)
	var hit := func(list: Array, m: float, each = null):
		for e in list:
			damage(e, d * m, t)
			if not e.dead and each:
				each.call(e)
	match k:
		"arcane":
			hit.call(area, 6.0, func(e):
				if not e.pushback_immune:
					if not (e.push_t > 0):
						e.push_spd = 0
					e.push_t = maxf(e.push_t, 1.5)
					e.push_spd = maxf(e.push_spd, 120)
				e.brittle = maxf(e.brittle, 0.3)
				e.brittle_t = maxf(e.brittle_t, 5))
			for i in 3:
				ring(t.x, t.y, R_ * (1 - i * 0.25), 0xb07cff, 0.7 + i * 0.15, true, { shrink = true })
			do_shake(0.012, 300)
		"plasma":
			hit.call(area, 10.0)
			zone({ x = t.x, y = t.y, r = R_ * 0.7, t = 4.0, dps = d * 0.8, color = col(0xff7a3d) })
			ring(t.x, t.y, R_, 0xff7a3d, 0.8, true)
			ring(t.x, t.y, R_ * 0.6, 0xffffff, 0.5, true)
			ring(t.x, t.y, R_ * 1.1, 0xffd36e, 1.1)
			do_shake(0.025, 450)
			sfx("boom")
		"frost":
			hit.call(area, 1.0, func(e):
				e.stun_t = maxf(e.stun_t, 0.8 if e.boss else 2.5)
				e.brittle = maxf(e.brittle, 0.4)
				e.brittle_t = maxf(e.brittle_t, 5)
				ring(e.x, e.y, e.r + 8, 0xdff6ff, 0.8, true))
			ring(t.x, t.y, R_, 0x9fe6ff, 1.0, true)
			ring(t.x, t.y, R_ * 0.5, 0xffffff, 0.6, true)
			do_shake(0.01, 250)
		"tesla":
			for i in 12:
				later(i * 0.07, func():
					var live := in_range(t.x, t.y, R_)
					if live.is_empty():
						return
					var e: Enemy = pick(live)
					damage(e, d * 5, t)
					if not e.dead:
						e.stun_t = maxf(e.stun_t, 0.15 if e.boss else 0.4)
					fx_add({ k = "bolt", x = e.x, y = e.y, color = col(0x9cf4dd), t = 0.3, seed = randf() * 1000 })
					ring(e.x, e.y, 26, 0x9cf4dd, 0.3, true))
			do_shake(0.01, 700)
		"beacon":
			for o in S.towers:
				if o.pos().distance_to(t.pos()) <= 260:
					o.ascend_t = 6
					fx_add({ k = "pillar", x = o.x, y = o.y, w = 8.0, color = col(0xffd36e), t = 0.8 })
			ring(t.x, t.y, 260, 0xffd36e, 1.0, true)
		"anvil":
			hit.call(area, 8.0, func(e): e.stun_t = maxf(e.stun_t, 0.5 if e.boss else 1.5))
			for i in 3:
				later(i * 0.15, func(): ring(t.x, t.y, R_ * (0.5 + i * 0.3), 0xc8a26a, 0.6, true))
			do_shake(0.035, 500)
			sfx("boom")
		"laser":
			var top: Enemy = area[0]
			for e in area:
				if e.hp > top.hp:
					top = e
			damage(top, d * 30, t)
			hit.call(in_range(top.x, top.y, 70).filter(func(e): return e != top), 8.0)
			fx_add({ k = "pillar", x = top.x, y = top.y, w = 16.0, color = col(0xff6fa0), t = 0.9 })
			ring(top.x, top.y, 70, 0xff6fa0, 0.7, true)
			do_shake(0.02, 300)
		"mortar":
			for i in 10:
				later(0.3 + i * 0.12, func():
					var live := in_range(t.x, t.y, R_)
					var x: float
					var y: float
					if live.size():
						var e: Enemy = pick(live)
						x = e.x + (randf() - 0.5) * 30
						y = e.y + (randf() - 0.5) * 30
					else:
						var a := randf() * TAU
						var rr := randf() * R_ * 0.8
						x = t.x + cos(a) * rr
						y = t.y + sin(a) * rr
					hit.call(in_range(x, y, 60), 4.0)
					line(x - 80, y - 420, x, y, 0xffb35c, 0.2, 6, { l1 = 0 })
					ring(x, y, 60, 0xff8a3d, 0.5, true)
					do_shake(0.006, 100))
	ring(t.x, t.y, 34, t.color, 0.5, true)
	return true


# ---------- the hero's ability ----------
## auto: cast by Sunforge, which skips Orbital Strike's ready-then-fire step.
func use_ability(auto := false) -> void:
	var h := S.hero if S else null
	if h == null or h.ko > 0 or h.ab.t > 0 or S.over or S.paused or h.data.spells or h.stun_t > 0:
		return
	var a := h.ab
	if a.id == "stream" and live_enemies().is_empty():
		say("No target for " + a.name + ".")
		return
	if a.id == "pierce" and pierce_goal() == null:
		say("No target for " + a.name + ". Press F to set an aim point.")
		return
	if a.id == "strike" and S.pointer == null and S.aim == null and live_enemies().is_empty():
		say("No target for " + a.name + ".")
		return
	# with an aim point set, Piercing Shot holds fire (and keeps its charge) until an enemy is on its line
	if a.id == "pierce" and not pierce_cursor() and S.aim != null and pierce_line(h, a, S.aim).is_empty():
		say("No enemy on the aim line yet. Piercing Shot holds its fire.")
		return
	# Orbital Strike: the first press readies it and shows the blast, the second fires at the cursor
	if a.id == "strike" and not auto and not S.strike_ready:
		S.strike_ready = true
		say("Orbital Strike ready: press Q again or click to fire at the cursor. Esc cancels.")
		refresh("build_bar")
		return
	S.strike_ready = false
	a.t = a.cd
	cast_ability(false)


## Runs the ability's effect. Free casts (Blade Dancer) don't touch the cooldown.
func cast_ability(_free: bool) -> void:
	var h := S.hero
	var a := h.ab
	if a.id == "pierce":
		piercing_shot(h, a)
		return
	sfx("ability")
	match a.id:
		"slam":
			slam(h, a, 1.0)
		"nova":
			rift_nova(h, a)
		"bulwark":
			bulwark_shield(h, a)
		"overdrive":
			h.od_t = a.dur
			h.od_bonus = 0
			ring(h.x, h.y, 60, 0xff6f6f, 0.6, true)
			do_shake(0.004, 120)
		"strike":
			orbital_strike(h, a)
		"whirl":
			whirlwind(h, a)
		"stream":
			air_stream(h, a)
		"stasis":
			S.stasis_t = a.dur
			S.stasis_at = h.pos()
			if a.anchor:
				for e in in_range(h.x, h.y, a.r):
					e.stun_t = maxf(e.stun_t, 0.5 if e.boss else 1.5)
			ring(h.x, h.y, a.r, 0x7fd4ff, 0.7, true)
		_:
			S.overclock_t = a.dur
			S.overclock_at = h.pos()
			ring(h.x, h.y, a.r, 0xb07cff, 0.6, true)


func bulwark_shield(h: Hero, a: Ability) -> void:
	h.shield = a.dmg * 5 * (1.5 if a.overflow else 1.0)
	h.shield_max = h.shield
	h.shield_t = a.dur
	h.soaked = 0
	ring(h.x, h.y, 34, 0x9af0ff, 0.6, true)
	do_shake(0.004, 120)


## Adds to the hero's shield (Gale's abilities, the Hero Shrine). Only the Bulwark Shield bursts when it ends.
func give_shield(h: Hero, amt: float, dur: float) -> void:
	if amt <= 0:
		return
	h.shield += amt
	h.shield_max = maxf(h.shield_max if h.shield_t > 0 else 0.0, h.shield)
	h.shield_t = maxf(h.shield_t, dur)
	ring(h.x, h.y, 30, 0x9af0ff, 0.4, true)


## Gale: a spinning strike that throws nearby enemies far back along the path and shields the hero.
func whirlwind(h: Hero, a: Ability) -> void:
	var x := h.x
	var y := h.y
	for e in in_range(x, y, a.r):
		damage(e, ab_dmg(h, a))
		if e.dead:
			continue
		push_back(e, 0.6, a.power * (1 + sb("knock")), h)
		e.stun_t = maxf(e.stun_t, a.stun * (0.5 if e.boss else 1.0))
		if h.knock_slow:
			slow_enemy(e, h.knock_slow, 2.0)
	give_shield(h, h.max_hp * a.mult, a.dur)
	for i in 3:
		later(0.08 * i, func(): ring(x, y, a.r * (0.5 + 0.25 * i), 0xd8f6ff, 0.3))
	ring(x, y, a.r, 0x9af0ff, 0.45, true)
	do_shake(0.006, 180)


## Gale: a beam of wind toward the lead enemy. After a moment every enemy it caught is stunned and hit,
## and the hero gains a shield worth a share of the damage dealt.
func air_stream(h: Hero, a: Ability) -> void:
	var goal = lead_enemy()
	if goal == null:
		return
	var dx: float = goal.x - h.x
	var dy: float = goal.y - h.y
	var len := hyp(dx, dy)
	if len == 0:
		len = 1
	var ux := dx / len
	var uy := dy / len
	var hits := S.enemies.filter(func(e):
		if e.dead:
			return false
		var along: float = (e.x - h.x) * ux + (e.y - h.y) * uy
		var off: float = absf((e.x - h.x) * uy - (e.y - h.y) * ux)
		return along > -10 and along <= a.r and off <= a.w + e.r)
	var x1 := h.x
	var y1 := h.y
	var x2 := h.x + ux * a.r
	var y2 := h.y + uy * a.r
	line(x1, y1, x2, y2, 0xd8f6ff, a.dur, a.w * 2)
	line(x1, y1, x2, y2, 0x9af0ff, a.dur, a.w * 0.7)
	if a.downdraft:
		zone({ line = true, x = x1, y = y1, x1 = x1, y1 = y1, x2 = x2, y2 = y2, r = a.w, t = 3.0, slow = 0.5, color = 0xd8f6ff })
	for e in hits:
		push_back(e, 0.25, 140 * (1 + sb("knock")), h)
		ring(e.x, e.y, e.r + 6, 0xd8f6ff, a.dur)
	later(a.dur, func():
		var dealt := 0.0
		for e in hits:
			if e.dead:
				continue
			var before: float = e.hp
			damage(e, ab_dmg(h, a))
			dealt += before - maxf(0.0, e.hp)
			if not e.dead:
				e.stun_t = maxf(e.stun_t, a.stun * (0.5 if e.boss else 1.0))
			ring(e.x, e.y, e.r + 10, 0x9af0ff, 0.35, true)
		line(x1, y1, x2, y2, 0xffffff, 0.15, a.w)
		do_shake(0.006, 160)
		if S.hero.ko <= 0:
			give_shield(S.hero, dealt * a.mult, 6.0))


func end_shield(h: Hero) -> void:
	var a := h.ab
	if a.id != "bulwark":
		h.shield = 0
		h.shield_t = 0
		h.soaked = 0
		return
	var dmg := ab_dmg(h, a) + h.soaked * 0.6
	for e in in_range(h.x, h.y, a.r):
		damage(e, dmg)
	if a.overflow and h.shield > 0:
		h.hp = minf(h.max_hp, h.hp + h.shield)
	ring(h.x, h.y, a.r, 0x9af0ff, 0.45, true)
	do_shake(0.006, 160)
	h.shield = 0
	h.shield_t = 0
	h.soaked = 0


## Damage to the hero goes through the Bulwark Shield first.
func hurt_hero(h: Hero, loss: float) -> void:
	loss *= (1 - minf(0.5, sb("armor"))) * (1 + h.shred if h.shred_t > 0 else 1.0)
	if h.shield > 0:
		var soak := minf(h.shield, loss)
		h.shield -= soak
		h.soaked += soak
		loss -= soak
		if h.shield <= 0:
			end_shield(h)
	if h.mana_shield and h.mana > 0 and loss > 0:
		var soak2 := minf(h.mana * 2, loss)
		h.mana -= soak2 / 2
		loss -= soak2
	if h.aegis and loss > 0:
		h.debt += loss # paid off over 4 seconds in update()
		loss = 0
	h.hp -= loss
	if S.heroics.get("retribution", 0):
		h.ret_store += loss


func toughest() -> Enemy:
	var best: Enemy = null
	for e in S.enemies:
		if e.dead:
			continue
		if best == null or (e.boss and not best.boss) or (e.boss == best.boss and e.hp > best.hp):
			best = e
	return best


func orbital_strike(h: Hero, a: Ability) -> void:
	var tough := toughest()
	var at = null
	if S.pointer != null:
		at = Vector2(clampf(S.pointer.x, 0, W), clampf(S.pointer.y, 0, H))
	elif S.aim != null:
		at = S.aim
	elif tough:
		at = tough.pos()
	if at == null:
		return
	sfx("snipe")
	line(at.x, 0, at.x, at.y, 0xffd36e, 0.8, 2)
	ring(at.x, at.y, a.r, 0xff5d6c, 0.8)
	var boom := func(x: float, y: float, r: float, mult: float):
		for e in in_range(x, y, r):
			damage(e, hero_dmg() * a.mult * mult * (1 + h.headhunter if e.boss else 1.0) * ab_crit_mul(h))
		line(x, 0, x, y, 0xffffff, 0.25, 10 * mult)
		ring(x, y, r, 0xffd36e, 0.5, true)
		if a.scorch:
			zone({ x = x, y = y, r = r * 0.8, t = 4.0, dps = hero_dmg() * 0.6, color = 0xff8a3d })
	later(0.8, func():
		boom.call(at.x, at.y, a.r, 1.0)
		do_shake(0.014, 280)
		sfx("boom")
		if a.carpet:
			for i in 3:
				var ang := randf() * TAU
				var dd := a.r * 0.9
				later(0.15 * (i + 1), func(): boom.call(at.x + cos(ang) * dd, at.y + sin(ang) * dd, a.r * 0.7, 0.5)))


func slam(h: Hero, a: Ability, mult: float) -> void:
	var x := h.x
	var y := h.y
	var r := a.r * (1.5 if a.magnet else 1.0)
	for e in in_range(x, y, r):
		damage(e, ab_dmg(h, a) * mult)
		e.stun_t = maxf(e.stun_t, a.stun * mult)
		if a.magnet:
			if not e.pushback_immune:
				e.d = maxf(0, e.d - 50)
			line(e.x, e.y, x, y, 0x9af0ff, 0.35, 2)
	if h.taunt:
		for e in in_range(x, y, maxf(120, r)):
			e.taunt_t = maxf(e.taunt_t, h.taunt / 2 if e.boss else h.taunt)
	ring(x, y, r, 0x5fe39a, 0.4, true)
	do_shake(0.006 * mult + 0.002, 180)
	if mult < 1:
		return
	if a.rings:
		for i in 3:
			later(0.18 * (i + 1), func():
				var rr := r * (1.3 + 0.3 * i)
				for e in in_range(x, y, rr):
					damage(e, ab_dmg(h, a) * 0.4)
					if not e.pushback_immune:
						e.d = maxf(0, e.d - 20)
				ring(x, y, rr, 0x9af0ff, 0.35))
	if a.molten:
		zone({ x = x, y = y, r = r * 0.8, t = 4.0, dps = a.dmg * 0.6, slow = 0.35, color = 0xff8a3d })
	if a.echo:
		later(1.0, func(): if S.hero.ko <= 0: slam(S.hero, a, 0.5))


func _nova_blast(a: Ability, x: float, y: float, r: float, dmg: float, depth: int) -> void:
	var hit := in_range(x, y, r)
	for e in hit:
		damage(e, dmg)
	ring(x, y, r, 0xff6fd8 if depth else 0xb07cff, 0.45, true)
	if a.chain_n and depth < 3:
		for e in hit:
			if e.dead:
				var ex: float = e.x
				var ey: float = e.y
				later(0.12, func(): _nova_blast(a, ex, ey, 55, dmg * 0.5, depth + 1))


func rift_nova(h: Hero, a: Ability) -> void:
	if a.dash and S.pointer != null:
		var dx: float = S.pointer.x - h.x
		var dy: float = S.pointer.y - h.y
		var d := hyp(dx, dy)
		if d == 0:
			d = 1
		var len := minf(220, d)
		var nx := h.x + dx / d * len
		var ny := h.y + dy / d * len
		for i in 6:
			zone({ x = h.x + (nx - h.x) * i / 5.0, y = h.y + (ny - h.y) * i / 5.0, r = 26.0, t = 3.0, dps = a.dmg * 0.5, color = 0xff6f6f })
		line(h.x, h.y, nx, ny, 0xffffff, 0.3, 6)
		h.x = nx
		h.y = ny
		h.tx = null
	if a.hole:
		var x := h.x
		var y := h.y
		for e in in_range(x, y, a.r):
			e.stun_t = maxf(e.stun_t, 1.5)
		zone({ x = x, y = y, r = a.r, t = 1.5, color = 0x9a7cff, vortex = true })
		later(1.5, func():
			_nova_blast(a, x, y, a.r, a.dmg * 1.5, 0)
			do_shake(0.015, 300)
			sfx("boom"))
	else:
		_nova_blast(a, h.x, h.y, a.r, a.dmg, 0)
		do_shake(0.006, 180)
	if a.twin:
		var tough: Enemy = null
		for e in S.enemies:
			if not e.dead and (tough == null or e.hp > tough.hp):
				tough = e
		if tough:
			later(0.25, func(): _nova_blast(a, tough.x, tough.y, a.r * 0.8, a.dmg, 0))


## Enemies a shot from the hero toward goal would pass through.
func pierce_line(h: Hero, a: Ability, goal) -> Array:
	var dx: float = goal.x - h.x
	var dy: float = goal.y - h.y
	var len := hyp(dx, dy)
	if len == 0:
		len = 1
	var ux := dx / len
	var uy := dy / len
	var w := a.w * (3.0 if a.rail else 1.0)
	return S.enemies.filter(func(e):
		if e.dead:
			return false
		var along: float = (e.x - h.x) * ux + (e.y - h.y) * uy
		var off: float = absf((e.x - h.x) * uy - (e.y - h.y) * ux)
		return along > 0 and off <= w + e.r)


## Critical Payload: ability hits roll for a crit like normal attacks.
func ab_crit_mul(h: Hero) -> float:
	if h.ab_crit and randf() < h.crit + sb("crit"):
		return h.crit_dmg
	return 1.0


## Piercing Shot can follow the cursor instead of the aim point (a setting).
func pierce_cursor() -> bool:
	return bool(Save.settings.get("pierce_cursor", false))


## Where Piercing Shot fires: the cursor (in cursor mode), else the aim point, else the lead enemy.
func pierce_goal():
	if pierce_cursor() and S.pointer != null:
		return S.pointer
	if S.aim != null:
		return S.aim
	return lead_enemy()


func lead_enemy() -> Enemy:
	var best: Enemy = null
	for e in S.enemies:
		if e.dead:
			continue
		if best == null or (e.boss and not best.boss) or (e.boss == best.boss and e.d > best.d):
			best = e
	return best


func piercing_shot(h: Hero, a: Ability) -> void:
	var lead := lead_enemy()
	var goal = pierce_goal()
	if goal == null:
		return
	var dx: float = goal.x - h.x
	var dy: float = goal.y - h.y
	var len := hyp(dx, dy)
	if len == 0:
		len = 1
	var ux := dx / len
	var uy := dy / len
	var w := a.w * (3.0 if a.rail else 1.0)
	var base := hero_dmg() * a.mult
	var hit := pierce_line(h, a, goal)
	var kills := 0
	for e in hit:
		var d := base * (1 + h.headhunter if e.boss else 1.0) * ab_crit_mul(h)
		var ex: bool = a.exec_r and not e.boss and (e.hp - d) / e.max <= 0.3
		if ex:
			d = e.hp + 1
		damage(e, d, null, 1 if ex else 0)
		if e.dead:
			kills += 1
		if a.cluster:
			for o in in_range(e.x, e.y, 50):
				if o != e:
					damage(o, base * 0.4)
			ring(e.x, e.y, 50, 0xffb35d, 0.3, true)
	var ex2 := h.x + ux * 2000
	var ey2 := h.y + uy * 2000
	line(h.x, h.y, ex2, ey2, 0xffd36e, 0.35, 14 if a.rail else 4)
	if a.rail:
		zone({ line = true, x = h.x, y = h.y, x1 = h.x, y1 = h.y, x2 = ex2, y2 = ey2, r = w, t = 3.0, dps = hero_dmg() * 0.8, color = 0xffd36e })
	if a.bounce:
		var from = lead
		if hit.size():
			from = hit[0]
			for e in hit:
				if e.d > from.d:
					from = e
		if from == null:
			from = goal
		var done := {}
		for e in hit:
			done[e] = true
		for i in 5:
			var n: Enemy = null
			var nd := INF
			for e in S.enemies:
				if e.dead or done.has(e):
					continue
				var dd := hyp(e.x - from.x, e.y - from.y)
				if dd < nd:
					nd = dd
					n = e
			if n == null:
				break
			line(from.x, from.y, n.x, n.y, 0xffd36e, 0.3, 3)
			damage(n, base * 0.6)
			done[n] = true
			from = n
	if a.exec_r and kills:
		a.t = maxf(0, a.t - a.cd * minf(0.4, 0.1 * kills))
	do_shake(0.012 if a.rail else 0.005, 200)
	sfx("snipe")


func overcharge_burst() -> void:
	var at := S.overclock_at
	var h := S.hero
	for t in S.towers:
		if at.distance_to(t.pos()) <= h.ab.r:
			var list := in_range(t.x, t.y, t_range(t))
			if list.is_empty():
				continue
			list.sort_custom(by_d_desc)
			var e: Enemy = list[0]
			apply_hit(t, e, t.dmg * S.mod_tower_dmg * 3)
			line(t.x, t.y, e.x, e.y, 0xffffff, 0.3, 5)
			ring(e.x, e.y, 30, 0xb07cff, 0.4, true)
	do_shake(0.01, 250)
	sfx("boom")


# ---------- the Wizard's spells ----------
func freeze_for(e: Enemy, s: float, h: Hero) -> float:
	return s * 0.3 if e.boss else s + h.freeze_bonus


func freeze_enemy(e: Enemy, s: float, h: Hero) -> void:
	e.stun_t = maxf(e.stun_t, freeze_for(e, s, h))
	ring(e.x, e.y, e.r + 6, 0xdff6ff, 0.5, true)


func push_back(e: Enemy, dur: float, spd: float, h: Hero) -> void:
	if e.pushback_immune:
		return
	if h.cls == "wizard" and not e.dead:
		_wizard_push()
	if not (e.push_t > 0):
		e.push_spd = 0
	e.push_t = maxf(e.push_t, (0.35 if e.boss else 1.0) * dur * h.push_bonus)
	e.push_spd = maxf(e.push_spd, spd)


func hit_area(x: float, y: float, r: float, dmg: float, each = null) -> void:
	for e in in_range(x, y, r):
		damage(e, dmg)
		if not e.dead and each:
			each.call(e)


func root_enemy(e: Enemy, s: float) -> void:
	e.stun_t = maxf(e.stun_t, s * 0.3 if e.boss else s)


func heal_hero(h: Hero, f: float) -> void:
	if h.ko <= 0:
		h.hp = minf(h.max_hp, h.hp + h.max_hp * f)
		ring(h.x, h.y, 24, 0x7dffb0, 0.5, true)


## Lightning that starts at the enemy nearest (x, y) and jumps to the nearest enemy it hasn't hit yet.
func chain_zap(h: Hero, x: float, y: float, jumps: int, dmg: float, color, each = null) -> void:
	var near := in_range(x, y, 80 * h.spell_r)
	var cur: Enemy = null
	for e in near:
		if cur == null or hyp(e.x - x, e.y - y) < hyp(cur.x - x, cur.y - y):
			cur = e
	var from = h.pos()
	var hit := {}
	var i := 0
	while cur and i <= jumps:
		hit[cur] = true
		line(from.x, from.y, cur.x, cur.y, color, 0.25, 3)
		damage(cur, dmg)
		if not cur.dead and each:
			each.call(cur)
		from = cur
		var nxt: Enemy = null
		var nd := 110.0
		for e in S.enemies:
			if e.dead or hit.has(e):
				continue
			var dd := hyp(e.x - from.x, e.y - from.y)
			if dd <= nd:
				nd = dd
				nxt = e
		cur = nxt
		i += 1


## A beam from the staff through (x, y): everything within w of the line, up to len long.
func line_hit(h: Hero, x: float, y: float, len: float, w: float, dmg: float, color, each = null) -> void:
	var dx := x - h.x
	var dy := y - h.y
	var d := hyp(dx, dy)
	if d == 0:
		d = 1
	var z := { x1 = h.x, y1 = h.y, x2 = h.x + dx / d * len, y2 = h.y + dy / d * len }
	for e in S.enemies:
		if not e.dead and seg_dist(e.x, e.y, z) <= w + e.r:
			damage(e, dmg)
			if not e.dead and each:
				each.call(e)
	line(z.x1, z.y1, z.x2, z.y2, color, 0.35, w * 0.8)
	line(z.x1, z.y1, z.x2, z.y2, 0xffffff, 0.25, 2)


## Lightning bolts on random enemies inside a circle, one every gap seconds.
func strikes(x: float, y: float, r: float, n: int, gap: float, dmg: float, each = null) -> void:
	for i in n:
		later(i * gap, func():
			var live := in_range(x, y, r)
			if live.is_empty():
				return
			var e: Enemy = pick(live)
			damage(e, dmg)
			if not e.dead and each:
				each.call(e)
			fx_add({ k = "bolt", x = e.x, y = e.y, color = 0x9cf4dd, t = 0.25, seed = randf() * 1000 }))


func burn_ground(x: float, y: float, r: float, t: float, dps: float, color = 0xff8a3d) -> void:
	zone({ x = x, y = y, r = r, t = t, dps = dps, color = color })


## The point on the path nearest (x, y), as a path distance, if it's within reach (else -1).
func path_point_near(x: float, y: float, reach: float) -> float:
	var best := -1.0
	var bd := reach
	var d := 0.0
	while d <= S.map.path_len:
		var p := pos_at(d)
		var dd := hyp(p.x - x, p.y - y)
		if dd < bd:
			bd = dd
			best = d
		d += 4
	return best


## Walls lock onto the grid: the centre of the path tile nearest the cursor.
func wall_spot(x: float, y: float):
	var best = null
	var bd := 140.0
	for cell in S.map.path_cells:
		var cx: float = cell.x * C + C / 2
		var cy: float = cell.y * C + C / 2
		var dd := hyp(cx - x, cy - y)
		if dd < bd:
			bd = dd
			best = Vector2(cx, cy)
	if best == null:
		return null
	var d := path_point_near(best.x, best.y, 30)
	if d < 0:
		return null
	var a := pos_at(maxf(0, d - 6))
	var b := pos_at(minf(S.map.path_len, d + 6))
	return { d = d, x = best.x, y = best.y, across = absf(b.x - a.x) > absf(b.y - a.y) }


func raise_wall(h: Hero, x: float, y: float, hp: float, dur: float, pow: float, slam_dmg: float, more := {}) -> bool:
	var p = wall_spot(x, y)
	if p == null:
		return false
	var w := { d = p.d, x = p.x, y = p.y, across = p.across, hp = hp * h.wall_bonus, max = hp * h.wall_bonus, t = dur, T = dur,
		art = "greatwall" if slam_dmg else "stonewall", born = S.time, thorns = 0.0, color = null }
	w.merge(more, true)
	S.walls.append(w)
	if slam_dmg:
		hit_area(p.x, p.y, 45, slam_dmg * pow, func(e): e.stun_t = maxf(e.stun_t, 0.3 if e.boss else 1.0))
	do_shake(0.004, 120)
	return true


func flight(h: Hero, x: float, y: float) -> float:
	return maxf(0.12, hyp(x - h.x, y - h.y) / 650)


## A fireball flies from the staff to the target, then bursts.
func launch(h: Hero, x: float, y: float, color, size: float, land: Callable) -> void:
	var T := flight(h, x, y)
	fx_add({ k = "orb", x1 = h.x, y1 = h.y, x2 = x, y2 = y, r = size, color = color, t = T })
	later(T, land)


## What one enemy hit by a spell gets: freezes, stuns, roots, push-back, poison, exposure, armor break.
func _spell_each(sp: SpellData, h: Hero, p: float):
	var any := sp.freeze or sp.stun or sp.root or sp.push or sp.poison_dps or sp.expose or sp.armor_break
	if not any:
		return null
	return func(e: Enemy):
		if sp.freeze:
			freeze_enemy(e, sp.freeze, h)
		if sp.stun:
			e.stun_t = maxf(e.stun_t, sp.stun_boss if e.boss else sp.stun)
		if sp.root:
			root_enemy(e, sp.root)
		if sp.push:
			push_back(e, sp.push, sp.push_speed, h)
		if sp.poison_dps:
			e.burn_t = maxf(e.burn_t, sp.poison_time)
			e.burn_dps = maxf(e.burn_dps, sp.poison_dps * p)
		if sp.expose:
			e.brittle = maxf(e.brittle, sp.expose)
			e.brittle_t = maxf(e.brittle_t, sp.expose_time)
		if sp.armor_break:
			e.brk = maxf(e.brk, sp.armor_break)
			e.brk_t = maxf(e.brk_t, sp.armor_break_time)


## The blast of an area spell at (x, y): damage, effects, burning ground, the ring and the shake.
func _spell_burst(sp: SpellData, h: Hero, x: float, y: float, p: float) -> void:
	var r := sp.r * h.spell_r
	var each = _spell_each(sp, h, p)
	if sp.dmg or each:
		hit_area(x, y, r, sp.dmg * p, each)
	if sp.burn_time:
		burn_ground(x, y, r * sp.burn_r, sp.burn_time, sp.burn_dps * p, sp.burn_color if sp.burn_color.a > 0 else col(0xff8a3d))
	if sp.ring_time:
		ring(x, y, r, sp.color, sp.ring_time, sp.ring_fill, { shrink = sp.ring_shrink })
	if sp.shake:
		do_shake(sp.shake, 200 + sp.shake * 15000)
	if sp.boom:
		sfx("boom")


## Casts a spell at (x, y) with power p. Returns false when it can't be cast there (walls off the path).
func cast_spell(key: String, h: Hero, x: float, y: float, p: float) -> bool:
	var sp: SpellData = DB.spells[key]
	var r := sp.r * h.spell_r
	var each = _spell_each(sp, h, p)
	match sp.delivery:
		"launch":
			launch(h, x, y, sp.color, sp.size, func(): _spell_burst(sp, h, x, y, p))
		"delayed":
			ring(x, y, r, 0xff5d3d, sp.delay)
			later(sp.delay, func():
				_spell_burst(sp, h, x, y, p)
				line(x - 60, y - 400, x, y, 0xff9a3d, 0.25, 10))
		"map":
			for e in live_enemies():
				damage(e, sp.dmg * p)
				if not e.dead and each:
					each.call(e)
			ring(x, y, sp.r, sp.color, sp.ring_time, true)
			if sp.shake:
				do_shake(sp.shake, 300)
		"chain":
			chain_zap(h, x, y, sp.jumps, sp.dmg * p, sp.color, each)
		"line":
			line_hit(h, x, y, sp.length, sp.width, sp.dmg * p, sp.color, each)
		"strikes":
			strikes(x, y, r, sp.count, sp.gap, sp.dmg * p, each)
			ring(x, y, r, sp.color, sp.ring_time, false)
			if sp.shake:
				do_shake(sp.shake, 800)
		"toughest":
			var list := live_enemies()
			list.sort_custom(func(a, b): return a.hp > b.hp)
			for i in mini(sp.count, list.size()):
				var e: Enemy = list[i]
				later(i * sp.gap, func():
					if e.dead:
						return
					damage(e, sp.dmg * p)
					fx_add({ k = "pillar", x = e.x, y = e.y, w = 12.0, color = sp.color, t = 0.7 })
					ring(e.x, e.y, 40, sp.color, 0.5, true)
					do_shake(sp.shake, 120))
		"divine":
			var near := in_range(x, y, r)
			if near.is_empty():
				return true
			var top: Enemy = near[0]
			for e in near:
				if e.hp > top.hp:
					top = e
			damage(top, sp.dmg * p)
			fx_add({ k = "pillar", x = top.x, y = top.y, w = 10.0, color = sp.color, t = 0.5 })
			chain_zap(h, top.x, top.y, sp.jumps, sp.dmg * p * 0.5, sp.color)
		"wall":
			var more := {}
			if sp.wall_thorns:
				more.thorns = sp.wall_thorns * p
			if sp.wall_color.a > 0:
				more.color = sp.wall_color
			return raise_wall(h, x, y, sp.wall_hp + sp.wall_hp_per_wave * wave_no(), sp.wall_time, p, sp.wall_slam, more)
		"zone":
			if sp.heal:
				heal_hero(h, sp.heal)
			zone({ x = x, y = y, r = r, t = sp.zone_time, dps = sp.zone_dps * p, slow = sp.zone_slow, color = sp.color, vortex = sp.zone_vortex,
				end_freeze = sp.zone_end_freeze, brk = sp.zone_break })
			if sp.implode_dmg:
				later(sp.zone_time, func():
					hit_area(x, y, r, sp.implode_dmg * p)
					ring(x, y, r, 0xb07cff, 0.6, true, { shrink = true })
					do_shake(0.01, 200))
		_: # area
			_spell_burst(sp, h, x, y, p)
			if sp.zone_time:
				zone({ x = x, y = y, r = r, t = sp.zone_time, dps = sp.zone_dps * p, slow = sp.zone_slow, color = sp.color, vortex = sp.zone_vortex,
					end_freeze = sp.zone_end_freeze, brk = sp.zone_break })
			if sp.heal:
				heal_hero(h, sp.heal)
			if sp.pillar:
				fx_add({ k = "pillar", x = x, y = y, w = 10.0, color = sp.color, t = 0.5 })
			if sp.fx_strikes:
				strikes(x, y, r, sp.fx_strikes, sp.fx_strike_gap, 0)
	return true


## Marks the circles and lines a spell draws as stand-ins, hidden under its painted effect.
func quietly(fn: Callable):
	var f0 := S.fx.size()
	var z0 := S.zones.size()
	var d0 := S.delayed.size()
	var out = fn.call()
	for i in range(f0, S.fx.size()):
		S.fx[i].quiet = true
	for i in range(z0, S.zones.size()):
		S.zones[i].quiet = true
	for i in range(d0, S.delayed.size()):
		var d: Dictionary = S.delayed[i]
		var g: Callable = d.fn
		d.fn = func(): quietly(g)
	return out


## Queues the painted effect of a spell (fx_spells.png) for the board to draw.
func spell_art(key: String, h: Hero, x: float, y: float) -> void:
	var sp: SpellData = DB.spells[key]
	if sp.art == "":
		return
	var r := (sp.art_r if sp.art_r else 60.0) * h.spell_r
	var base := { a = sp.art, x = x, y = y, r = r, tint = sp.art_tint, low = sp.art_low, fps = sp.art_fps }
	var area := func(at: float, more := {}):
		var it := base.duplicate()
		it.t0 = at
		if sp.art_dur:
			it.dur = sp.art_dur
			it.loop = sp.art_loop
		it.merge(more, true)
		S.art.append(it)
	if sp.art_mode == "fly":
		var T := flight(h, x, y)
		var fa := sp.art_fly if sp.art_fly != "" else sp.art
		S.art.append({ a = fa, fly = true, frames = (Array(sp.art_fly_frames) if sp.art_fly == "" else [0, 1, 2]), x1 = h.x, y1 = h.y, x2 = x, y2 = y,
			t0 = S.time, dur = T, tint = sp.art_tint, size = minf(1.3, 0.5 + r / 200) })
		area.call(S.time + T, { frames = Array(sp.art_hit_frames) } if sp.art_hit_frames.size() else {})
	elif sp.art_mode == "meteor":
		S.art.append({ a = sp.art, meteor = true, frames = [0, 1, 2], x = x, y = y, t0 = S.time, dur = 0.7, size = r / 95, tint = sp.art_tint })
		area.call(S.time + 0.7, { frames = [3, 4, 5, 6, 7], fps = 11.0 })
	elif sp.art_mode == "beam":
		S.art.append({ a = sp.art, beam = true, x1 = h.x, y1 = h.y, x2 = x, y2 = y, t0 = S.time, fps = 16.0, tint = sp.art_tint })
	else:
		area.call(S.time, { ang = atan2((y - h.y) * 0.75, x - h.x) } if sp.art_turn else {})


## What the readied runes cast: { key, spell, mana } or null.
func resolve_runes(runes: Array):
	if runes.is_empty():
		return null
	var key := Progress.spell_key(runes)
	if not DB.spells.has(key):
		return null
	return { key = key, spell = DB.spells[key], mana = DB.spells[key].mana }


## Two runes are kept (the oldest drops off); a third only when all three are one element mastered to level 10.
## An element just cast rests for 2 seconds before it can be readied again.
func ready_rune(k: String) -> void:
	var h := S.hero if S else null
	if h == null or h.ko > 0 or S.over or not S.rune_keys.has(k):
		return
	var el: String = S.rune_keys[k]
	if S.time < S.el_cd.get(el, 0.0):
		return
	var rr: Array = S.runes.duplicate()
	rr.append(el)
	rr = rr.slice(-3)
	if not (rr.size() == 3 and rr.all(func(x): return x == el) and S.triples.has(el)):
		rr = rr.slice(-2)
	S.runes = rr
	sfx("click")
	refresh("runes")


func el_boost(h: Hero, key: String) -> float:
	var m := 1.0
	var seen := {}
	for e in key.split("+"):
		if not seen.has(e):
			seen[e] = true
			m *= float(h.el_pow.get(e, 1.0))
	return m


func cast_runes(x: float, y: float) -> void:
	var h := S.hero
	var r = resolve_runes(S.runes)
	if r == null or h.ko > 0 or S.over or S.paused:
		return
	if S.mode.get("challenge", "") == "benched":
		say("Benched: your hero can’t attack this wave.")
		return
	if S.time < h.cast_t:
		return
	var mana: float = r.mana * h.spell_cost
	if h.mana < mana:
		say("Not enough mana for %s (%d needed)." % [r.spell.name, ceili(mana)])
		return
	var p := spell_pow(h) * el_boost(h, r.key)
	var key: String = r.key
	var painted: bool = r.spell.art != ""
	var f0 := S.fx.size()
	var z0 := S.zones.size()
	var w0 := S.walls.size()
	var cast := func(): return cast_spell(key, h, x, y, p)
	var ok = quietly(cast) if painted else cast.call()
	if ok == false:
		say("Walls go on the path: point at a path tile to raise one.")
		return
	spell_art(key, h, x, y)
	# spells without painted art always mark where they landed, even when they found nothing to hit
	if not painted and S.fx.size() == f0 and S.zones.size() == z0 and S.walls.size() == w0:
		ring(x, y, 40 * h.spell_r, DB.elements[S.runes[0]].color, 0.45, true)
	if h.free_cast and randf() < h.free_cast:
		ring(h.x, h.y, 26, 0x5fa8ff, 0.4, true)
		say("Archmage: that spell was free!")
	else:
		h.mana -= mana
	var seen := {}
	for el in S.runes:
		if seen.has(el):
			continue
		seen[el] = true
		S.el_cd[el] = S.time + R.element_rest
		S.el_mana[el] = S.el_mana.get(el, 0.0) + mana
	h.cast_t = S.time + 0.3
	h.aim_x = x
	h.aim_y = y
	h.atk_at = S.time
	h.casts += 1
	if h.echo and h.casts % int(h.echo) == 0:
		later(0.4, func():
			if h.ko > 0:
				return
			var again := func(): return cast_spell(key, h, x, y, p * 0.6)
			if (quietly(again) if painted else again.call()) != false:
				spell_art(key, h, x, y)
				say("Arcane Echo!"))
	sfx("ability")
	S.runes = []
	refresh("runes")


## Walls: enemies walking into one stop and batter it.
func wall_ahead(e: Enemy, step: float):
	for w in S.walls:
		if w.hp > 0 and e.d < w.d and e.d + step >= w.d - e.r:
			return w
	return null


func update_walls(dt: float) -> void:
	for w in S.walls:
		w.t -= dt
		if w.thorns:
			for e in in_range(w.x, w.y, 36):
				damage(e, w.thorns * dt)
		if w.t <= 0 or w.hp <= 0:
			w.gone = true
			S.art.append({ a = w.art, wall = w, frames = [7, 6, 5, 4, 3, 2, 1, 0], x = w.x, y = w.y, t0 = S.time, fps = 20.0, tint = w.color if w.color != null else Color.WHITE })
	S.walls = S.walls.filter(func(w): return not w.get("gone", false))


# ---------- waves ----------
func boss_for(n: int) -> String:
	if n == max_wave:
		return "tyrant"
	if n % R.warden_every == 0:
		return "warden"
	if n % R.knight_every == 0:
		return "knight"
	return ""


func first_wave_of(k: String) -> int:
	return DB.enemies[k].first_wave - S.map.scene.early_specials


func make_wave(n: int, mode: Dictionary) -> Array:
	var q: Array = []
	for i in R.grunts_base + n * R.grunts_per_wave:
		q.append("grunt")
	if n >= R.runners_from:
		for i in n * R.runners_per_wave:
			q.append("runner")
	if n >= R.brutes_from:
		for i in n - 2:
			q.append("brute")
	# Special enemies join from their first wave (earlier on some maps) and grow every 2 waves. Once more than 3 are
	# available, each wave brings 2 or 3 of them so waves feel different.
	var open := Array(DB.special_enemies).filter(func(k): return n >= first_wave_of(k))
	var types := open
	if open.size() > 3:
		types = open.duplicate()
		types.shuffle()
		types = types.slice(0, 2 if randf() < 0.5 else 3)
	for k in types:
		for i in DB.enemies[k].per_wave * (1 + int(floor((n - first_wave_of(k)) / 2.0))):
			q.append(k)
	if (mode.get("tough", []) as Array).has("horde"):
		q += q.slice(0, int(round(q.size() * R.tough_horde)))
	var ch = mode.get("challenge", "")
	if ch == "swarm":
		q += q.duplicate()
	if ch == "iron":
		var nb := maxi(4, int(round(q.size() / 3.0)))
		q = []
		for i in nb:
			q.append("brute")
	q.shuffle()
	var boss := boss_for(n)
	if boss != "":
		q.append(boss)
	return q


## Hard: modest gold per toughness rule. Challenge: gold per point of difficulty, a hero upgrade from 4 points and a relic
## from 5. Legendary and Secret waves keep their relic, but it is only paid if the requirement is met.
func wave_reward(n: int, kind: String, pts := 0):
	if kind == "normal":
		return null
	var owned := {}
	for r in S.relics:
		owned[r.id] = true
	if kind == "legendary" or kind == "secret":
		var src: UpgradeList = R.secret_relics if kind == "secret" else R.legendary_relics
		var pool := src.items.filter(func(r): return r.repeat or not owned.has(r.id))
		var relic: UpgradeData = pick(pool) if pool.size() else R.relics.find("repair")
		var g := (120 if kind == "secret" else 80) + 8 * n
		return { gold = g, relic = relic, perk = false, label = "%s relic: %s (%s) and +%d gold" % [DB.rar[kind].name, relic.name, relic_desc(relic).trim_suffix("."), g] }
	var gold := int(round((15 + 3 * n if kind == "hard" else 12 + 3 * n) * pts))
	if kind == "hard":
		return { gold = gold, perk = false, relic = null, label = "+%d gold" % gold }
	var out := { gold = gold, perk = pts >= 4, relic = null }
	if pts >= 5:
		out.relic = pick(R.relics.items.filter(func(x): return (x.repeat or not owned.has(x.id)) and (not x.offensive_only or hero_cat() == "offensive")))
	out.label = "+%d gold" % gold + (", a free hero upgrade" if out.perk else "") + (" and the %s relic (%s)" % [out.relic.name, relic_desc(out.relic).trim_suffix(".")] if out.relic else "")
	return out


func relic_desc(r: UpgradeData) -> String:
	return DB.tx("relic:" + r.id, r.desc)


## The text for a mode's rules: toughness rules, the handicap and the goal. Each: { k, name, rule }.
func mode_lines(m: Dictionary) -> Array:
	var out := []
	for id in m.get("tough", []):
		var t: UpgradeData = R.tough.find(id)
		out.append({ k = "tough", name = t.name, rule = DB.tx("tough:" + id, t.desc) })
	if m.get("challenge", "") != "":
		var c: UpgradeData = R.challenges.find(m.challenge)
		out.append({ k = "debuff", name = c.name, rule = DB.tx("challenge:" + c.id, c.desc) })
	if m.get("gilded", false):
		out.append({ k = "debuff", name = "Gilded", rule = "Golden enemies with double HP. Every kill drops triple gold." })
	if m.get("req", "") != "":
		var q: UpgradeData = R.requirements.find(m.req)
		out.append({ k = "req", name = q.name, rule = DB.tx("req:" + q.id, q.desc) })
	return out


var wave_opts: Array = []


func offer_wave_choice() -> void:
	var n := S.wave + 1
	var ch: UpgradeData = pick(R.challenges.items)
	var req: UpgradeData = pick(R.requirements.items)
	var tl := R.tough.items.duplicate()
	tl.shuffle()
	var hard_tough := tl.slice(0, 1 if randf() < 0.5 else 2)
	var ch_tough: UpgradeData = pick(R.tough.items)
	var ch_pts := ch_tough.pts + ch.pts + req.pts
	var ids := func(list): return list.map(func(x): return x.id)
	wave_opts = [
		{ kind = "normal", name = "Normal", reward = null },
		{ kind = "hard", name = "Hard", tough = ids.call(hard_tough), reward = wave_reward(n, "hard", hard_tough.size()) },
		{ kind = "challenge", name = "Challenge: " + req.name, challenge = ch.id, tough = [ch_tough.id], req = req.id, pts = ch_pts, reward = wave_reward(n, "challenge", ch_pts) },
	]
	var roll := randf()
	if roll < 0.03:
		wave_opts[2] = { kind = "secret", rarity = "secret", name = "Secret: Gilded Breach", gilded = true, hp_mul = 2.0, req = req.id, reward = wave_reward(n, "secret") }
	elif roll < 0.13:
		tl.shuffle()
		wave_opts[2] = { kind = "legendary", rarity = "legendary", name = "Legendary: " + req.name, challenge = ch.id, req = req.id, tough = ids.call(tl.slice(0, 2)),
			reward = wave_reward(n, "legendary") }
	S.paused = true
	modal.emit("wave_choice", { n = n, boss = boss_for(n) != "", opts = wave_opts })


func choose_mode(i: int) -> void:
	S.mode = wave_opts[i]
	S.paused = false
	refresh("build_bar")
	refresh("mode")
	say(S.mode.name + " chosen. Build up, then start the wave.")


func start_wave() -> void:
	if S.wave_active or S.over or S.paused:
		return
	S.wave += 1
	S.spawn_q = make_wave(S.wave, S.mode)
	S.spawn_t = 0.3
	S.interval = maxf(R.spawn_gap_min, R.spawn_gap_start - S.wave * R.spawn_gap_per_wave) * (0.6 if S.mode.get("challenge", "") == "swarm" else 1.0)
	S.wave_active = true
	S.hero.unbreak_left = S.hero.unbreak_max
	S.boss_warned = false
	S.one_shot_ready = bool(S.specials.get("oneshot", false)) and S.hero.cls == "sniper"
	S.ws = { wave = S.wave, mode = S.mode.name, lives_lost = 0, kills = 0, gold = 0.0, hero_dmg = 0.0, hero_kos = 0, start = S.time, enemies = S.spawn_q.size() }
	# Against the Clock: time to spawn everything, plus 20s (plus 50s with a boss).
	S.req_failed = false
	S.req_limit = round(S.spawn_q.size() * S.interval + (50 if boss_for(S.wave) != "" else 20)) if S.mode.get("req", "") == "timed" else 0.0
	var b := boss_for(S.wave)
	var msg = { knight = "A Rift Knight leads this wave.", warden = "The Rift Warden approaches.", tyrant = "Final wave. The Rift Tyrant is coming." }.get(b)
	say(msg if msg else "Wave %d incoming." % S.wave)
	sfx("boss" if msg else "wave")
	refresh("build_bar")
	refresh("mode")


func close_wave_log(cleared: bool) -> void:
	if S.ws == null:
		return
	var towers := S.towers.map(func(t): return { name = tower_name(t) + " L" + str(t.lvl), dmg = int(round(t.dmg_wave)) })
	towers.sort_custom(func(a, b): return a.dmg > b.dmg)
	var tower_dmg := 0.0
	for t in S.towers:
		tower_dmg += t.dmg_wave
	S.ws.merge({ cleared = cleared, seconds = int(round(S.time - S.ws.start)), tower_dmg = int(round(tower_dmg)), hero_dmg = int(round(S.ws.hero_dmg)), gold = int(round(S.ws.gold)),
		gold_bank = int(floor(S.gold)), hero_lvl = S.hero.lvl, tower_count = S.towers.size(), towers = towers }, true)
	S.log.append(S.ws)
	S.ws = null


func apply_relic(r: UpgradeData) -> void:
	Fx.run(r.effect, { run = S, h = S.hero })
	if not r.repeat:
		S.relics.append(r)


func end_wave() -> void:
	S.wave_active = false
	var hh := S.hero
	hh.debt = 0.0 # Aegis Core: pending damage is forgiven
	if hh.max_mana:
		hh.mana = minf(hh.max_mana, hh.mana + hh.max_mana * R.wave_mana_refill)
	if S.map.scene.drain and S.towers.size():
		var top: Tower = S.towers[0]
		for t in S.towers:
			if t.dmg_wave > top.dmg_wave:
				top = t
		S.drained = top if top.dmg_wave else null
	close_wave_log(true)
	for t in S.towers:
		t.dmg_wave = 0
	var bonus := R.wave_gold_base + R.wave_gold_per_wave * S.wave
	S.gold += bonus
	var msgs := ["+%d gold" % bonus]
	if S.coins.size():
		S.gold += 25 * S.coins.size()
		msgs.append("+%d from coins" % (25 * S.coins.size()))
		S.coins = []
	if S.hero.interest:
		var i := int(round(S.gold * minf(0.3, S.hero.interest)))
		S.gold += i
		msgs.append("+%d interest" % i)
	var r = S.mode.get("reward")
	if r and S.req_failed:
		msgs.append("challenge failed, no reward")
	elif r:
		S.gold += r.gold
		msgs.append("+%d reward gold" % r.gold)
		if r.perk:
			S.pending_levels += 1
			msgs.append("a free hero upgrade")
		if r.relic:
			apply_relic(r.relic)
			msgs.append(r.relic.name)
	if S.wave >= max_wave:
		end_run(true)
		return
	say("Wave %d cleared: %s.%s" % [S.wave, ", ".join(msgs), (" " + tower_name(S.drained) + " is drained next wave.") if S.drained else ""])
	S.mode = { kind = "normal", name = "Normal" }
	S.req_failed = false
	refresh("build_bar")
	refresh("hero")
	refresh("mode")
	if S.wave >= R.choice_from:
		S.need_choice = true
	if S.wave % R.shop_every == 0:
		S.need_shop = true


func fail_req(why: String) -> void:
	if S.req_failed or S.mode.get("req", "") == "" or not S.wave_active:
		return
	S.req_failed = true
	say("Challenge failed: " + why + ". No reward this wave.")
	sfx("leak")
	refresh("mode")


## at_d >= 0: spawn partway along the path (Splitter pieces, boss summons).
func spawn(type: String, at_d := -1.0) -> void:
	var d: EnemyData = DB.enemies[type]
	var m := S.mode
	# Enemies get much tougher each wave; bosses also scale with the wave they lead.
	var w := S.wave - 1
	var scale := 1 + R.boss_hp_growth * maxi(0, S.wave - 5) if d.boss else 1 + R.hp_growth_a * w + R.hp_growth_b * w * w
	scale *= S.mod_enemy_hp * R.enemy_hp_mult
	if has_tough("hp"):
		scale *= R.tough_hp
	scale *= float(m.get("hp_mul", 1.0))
	if m.get("challenge", "") == "swarm":
		scale *= R.swarm_hp
	var speed := d.speed * S.mod_enemy_speed * (R.blitz_speed if m.get("challenge", "") == "blitz" else 1.0) * (R.tough_speed if has_tough("speed") else 1.0)
	var at := maxf(0, at_d)
	var p := pos_at(at)
	if not Save.meta.seen.get(type, false):
		Save.meta.seen[type] = true
		Save.save_meta()
		refresh("enemy_codex")
		say("New enemy: " + d.name + ". " + DB.tx("enemy:" + type, d.info))
	var e := Enemy.new()
	e.type = type
	e.data = d
	e.boss = d.boss
	e.hp = d.hp * scale
	e.max = e.hp
	e.speed = speed
	e.d = at
	e.x = p.x if at_d >= 0 else p.x - 30
	e.y = p.y
	e.armor = (d.armor + S.map.scene.armor_bonus if d.armor else 0.0) + (R.tough_armor if has_tough("armor") else 0.0)
	e.regen = R.tough_regen if has_tough("regen") else 0.0
	e.steady = has_tough("steady")
	e.unslow = d.unslow
	e.pushback_immune = d.pushback_immune or d.boss
	e.phase = d.phase
	e.split = d.split
	e.heal = d.heal
	e.shield_aura = d.shield_aura
	e.gold = d.gold * (3 if m.get("gilded", false) else 1)
	e.lives = d.lives
	e.atk = d.atk
	e.r = d.radius
	e.color = col(0xf2c14e) if m.get("gilded", false) else d.color
	if d.boss and d.power_every:
		e.pow_t = d.power_every * 0.6
	S.enemies.append(e)


## Boss powers. Targeted towers flash red for 1s before the stun lands.
func boss_act(e: Enemy, dt: float) -> void:
	var p := e.data
	if p.power_every:
		if e.stun_t <= 0:
			e.pow_t -= dt
		if e.pow_t <= 0:
			e.pow_t = p.power_every
			boss_power(e, p)
	if e.type == "warden":
		var steps := [0.75, 0.5, 0.25]
		while e.summons < 3 and e.hp / e.max <= steps[e.summons]:
			e.summons += 1
			for i in 4:
				spawn("grunt", maxf(0, e.d - 15 - 12 * i))
			ring(e.x, e.y, 70, 0xff2e4d, 0.6, true)
			do_shake(0.006, 200)
			say("The Rift Warden tears open a rift!")
	if e.type == "tyrant" and not e.enraged and e.hp / e.max <= 0.5:
		e.enraged = true
		e.speed *= 1.3
		e.color = Color(1, 0, 0)
		for i in 2:
			spawn("juggernaut", maxf(0, e.d - 25 - 20 * i))
		ring(e.x, e.y, 140, 0xff0000, 0.9, true)
		do_shake(0.02, 500)
		sfx("boss")
		say("The Rift Tyrant is enraged! +30% speed, and 2 Juggernauts join it.")


func boss_power(e: Enemy, p: EnemyData) -> void:
	var live := [] if S.boss_proof else S.towers.filter(func(t): return not (t.stun_t > 0) and not (t.warn_t > 0))
	var targets: Array
	if p.power_nearest:
		targets = live.filter(func(t): return hyp(t.x - e.x, t.y - e.y) <= 260)
		targets.sort_custom(func(a, b): return hyp(a.x - e.x, a.y - e.y) < hyp(b.x - e.x, b.y - e.y))
		targets = targets.slice(0, maxi(1, p.power_towers))
	else:
		live.shuffle()
		targets = live.slice(0, p.power_towers)
	for t in targets:
		t.warn_t = 1
		line(e.x, e.y, t.x, t.y, 0xff2e4d, 1.0, 2)
		later(1.0, func():
			t.warn_t = 0
			if not S.towers.has(t):
				return
			t.stun_t = maxf(t.stun_t, p.power_stun * (1 - minf(0.8, S.hero.grounded)))
			t.stun_max = t.stun_t
			curse_tower(t, p)
			ring(t.x, t.y, 26, 0xff2e4d, 0.4, true))
	var h := S.hero
	var hits_hero: bool = (p.power_hero_stun > 0 or p.power_hero_curse != "none") and h.ko <= 0 \
		and (p.power_hero_reach <= 0 or hyp(h.x - e.x, h.y - e.y) <= p.power_hero_reach)
	if hits_hero:
		line(e.x, e.y, h.x, h.y, 0xb07cff, 1.0, 2)
		ring(h.x, h.y, 30, 0xb07cff, 1.0)
		later(1.0, func():
			if h.ko > 0:
				return
			if p.power_hero_stun > 0:
				h.stun_t = maxf(h.stun_t, p.power_hero_stun * (1 - minf(0.8, h.grounded)))
				h.tx = null
			curse_hero(h, p)
			ring(h.x, h.y, 34, 0xb07cff, 0.5, true))
	if p.power_roar:
		do_shake(0.014, 450)
		sfx("boss")
		ring(e.x, e.y, 220, 0xff2e4d, 0.7)
		if h.ko <= 0:
			var dx := h.x - e.x
			var dy := h.y - e.y
			var d := hyp(dx, dy)
			if d == 0:
				d = 1
			h.x = clampf(h.x + dx / d * 120, 10, W - 10)
			h.y = clampf(h.y + dy / d * 120, 10, H - 10)
			h.tx = null
	if targets.size() or p.power_roar or hits_hero:
		say(p.name + ": " + p.power_name + "!")


func curse_tower(t: Tower, p: EnemyData) -> void:
	if p.power_tower_curse == "none" or p.power_curse_dur <= 0:
		return
	t.curse_dmg = 0.0
	t.curse_rate = 0.0
	t.curse_range = 0.0
	t.set("curse_" + { weaken = "dmg", jam = "rate", blind = "range" }[p.power_tower_curse], p.power_tower_curse_amt)
	t.curse_t = maxf(t.curse_t, p.power_curse_dur)


func curse_hero(h: Hero, p: EnemyData) -> void:
	if p.power_hero_curse == "none" or p.power_curse_dur <= 0:
		return
	var k: String = { shred = "shred", weaken = "weak", drag = "drag" }[p.power_hero_curse]
	h.set(k, p.power_hero_curse_amt)
	h.set(k + "_t", maxf(h.get(k + "_t"), p.power_curse_dur))


## The secret unlock: Gale opens once the Wizard has pushed enough enemies back, counting every run.
func _wizard_push() -> void:
	S.wiz_pushes += 1
	if Progress.hero_open("gale"):
		return
	if int(Save.meta.get("wiz_pushes", 0)) + S.wiz_pushes >= R.gale_unlock_pushes:
		Save.meta.wiz_pushes = int(Save.meta.get("wiz_pushes", 0)) + S.wiz_pushes
		S.wiz_pushes = 0
		Save.meta.secret_heroes["gale"] = true
		Save.save_meta()
		S.pending_secret = "gale"


## Hero Shrine extras: a shield every 12s of a wave, and Gale's Bruiser Form once the Bruiser path is maxed.
func _shrine_step(h: Hero, dt: float) -> void:
	if sb("bruiser") > 0 and h.cls == "gale" and not h.bruiser:
		h.bruiser_form()
		ring(h.x, h.y, 80, 0xff8a3d, 0.8, true)
		do_shake(0.01, 250)
		say("Bruiser Form! Gale hits far harder and holds %d enemies at once." % h.block)
		refresh("hero")
	if sb("shield") <= 0 or not S.wave_active or h.ko > 0:
		return
	S.shrine_t -= dt
	if S.shrine_t <= 0:
		S.shrine_t = 12.0
		give_shield(h, h.max_hp * sb("shield"), 6.0)


## Second Chance: the current wave starts over instead of the run ending.
func restart_wave(reason: String) -> void:
	S.second_chance = false
	S.enemies = []
	S.zones = []
	S.delayed = []
	S.echoes = []
	S.shells = []
	S.proj = []
	S.spawn_q = make_wave(S.wave, S.mode)
	S.spawn_t = 1.5
	S.lives = maxi(S.lives, 10)
	S.boss_warned = false
	for t in S.towers:
		t.warn_t = 0
		t.stun_t = 0
	ring(S.map.base.x, S.map.base.y, 220, 0xf2c14e, 1.2, true)
	do_shake(0.015, 500)
	say(reason + ". Second Chance: the wave starts over!")
	sfx("boss")


func knock_out(h: Hero) -> void:
	if h.unbreakable and h.unbreak_left > 0:
		h.unbreak_left -= 1
		h.hp = h.max_hp
		ring(h.x, h.y, 90, 0x5fe39a, 0.7, true)
		do_shake(0.01, 250)
		say("Unbreakable! Back to full HP.")
		return
	h.hp = 0
	h.ko = h.respawn
	h.tx = null
	S.pending_build = null
	if S.ws:
		S.ws.hero_kos += 1
	if S.mode.get("req", "") == "alive":
		fail_req("your hero was knocked out")
	h.shield = 0
	h.shield_t = 0
	h.od_t = 0
	h.stun_t = 0
	h.debt = 0.0
	S.strike_ready = false
	# Respawning at the base with Hold on would pin the hero there, so Hold always turns off.
	if h.hold:
		h.hold = false
		refresh("build_bar")
	if S.heroics.get("phoenix", 0):
		h.ko = 2
		for e in in_range(h.x, h.y, 150):
			damage(e, 150 * S.heroics.phoenix)
		ring(h.x, h.y, 150, 0xff8a3d, 0.6, true)
	say("Hero knocked out. Back in %ds." % ceili(h.ko))


# ---------- the main loop ----------
## Advances the run by dt seconds of real time (the game speed is applied here). Called every frame by the board.
func update(dt: float) -> void:
	if S == null or S.paused or S.over or S.hero == null:
		return
	sync_aura(S.hero)
	if S.pending_secret != "":
		S.paused = true
		modal.emit("secret", { hero = S.pending_secret })
		S.pending_secret = ""
		return
	if S.pending_boon != "":
		show_boon()
		return
	if S.pending_heroic > 0:
		show_heroic()
		return
	if S.pending_levels > 0:
		show_level_up()
		return
	if S.need_shop:
		show_shop()
		return
	if S.need_choice:
		S.need_choice = false
		offer_wave_choice()
		return
	dt *= S.speed
	S.time += dt
	if S.req_limit and S.wave_active and S.ws and not S.req_failed and S.time - S.ws.start > S.req_limit:
		fail_req("time ran out")
	var h := S.hero
	var HX := S.heroics

	if S.wave_active:
		S.spawn_t -= dt
		if S.spawn_t <= 0 and S.spawn_q.size():
			spawn(S.spawn_q.pop_front())
			S.spawn_t = S.interval
		if S.spawn_q.is_empty() and S.enemies.is_empty():
			end_wave()
			return
	if S.overclock_t > 0:
		if h.ab.mobile:
			S.overclock_at = h.pos()
		S.overclock_t -= dt
		if S.overclock_t <= 0 and h.ab.burst:
			overcharge_burst()
	if h.mom_t > 0:
		h.mom_t -= dt
		if h.mom_t <= 0:
			h.mom_stacks = 0
	if h.shield_t > 0:
		h.shield_t -= dt
		if h.shield_t <= 0:
			end_shield(h)
	if h.od_t > 0:
		h.od_t -= dt
	if h.debt > 0 and h.ko <= 0:
		var pay := minf(h.debt, maxf(h.debt / 4.0, 5.0) * dt)
		h.debt -= pay
		h.hp -= pay
	if S.stasis_t > 0 and h.ab.follow_s and h.ko <= 0:
		S.stasis_at = h.pos()
	for k in ["weak_t", "shred_t", "drag_t"]:
		if h.get(k) > 0:
			h.set(k, h.get(k) - dt)
	_shrine_step(h, dt)
	if S.stasis_t > 0:
		S.stasis_t -= dt
	if HX.get("timestop", 0) and S.wave_active:
		S.time_stop_t -= dt
		if S.time_stop_t <= 0:
			S.time_stop_t = 25
			for e in S.enemies:
				e.stun_t = maxf(e.stun_t, 1 + HX.timestop)
			say("Time Stop!")

	if h.ko > 0:
		h.ko -= dt
		if h.ko <= 0:
			h.ko = 0
			h.hp = h.max_hp
			h.x = S.map.base.x - 40
			h.y = S.map.base.y
			h.tx = null
			say("Your hero is back.")
	else:
		_hero_step(h, HX, dt)
	if h.ab.t > 0 and S.wave_active:
		h.ab.t = maxf(0, h.ab.t - dt * (1 + sb("cdr")))
	elif h.auto_cast and h.ko <= 0 and S.enemies.size() and not h.data.spells and h.ab.t <= 0:
		var go := true
		if h.ab.id in ["slam", "nova", "stasis", "whirl"]:
			go = in_range(h.x, h.y, h.ab.r).size() > 0
		elif h.ab.id == "pierce" and pierce_goal() != null:
			go = pierce_line(h, h.ab, pierce_goal()).size() > 0
		elif h.ab.id == "stream":
			var lead := lead_enemy()
			go = lead != null and hyp(lead.x - h.x, lead.y - h.y) <= h.ab.r
		if go:
			use_ability(true)
	if _enemies_step(h, dt):
		return
	if h.ko <= 0 and h.hp <= 0:
		knock_out(h)
	if not S.boss_warned:
		for e in S.enemies:
			if not e.dead and BIG_BOSS.has(e.type) and e.d / S.map.path_len >= 0.75:
				S.boss_warned = true
				say("Boss approaching your base! If it gets through, the run is lost.")
				sfx("boss")
				break
	for z in S.zones:
		z.t -= dt
		if z.dps or z.slow:
			for e in S.enemies:
				if e.dead:
					continue
				if z.get("line", false):
					if seg_dist(e.x, e.y, z) > z.r + e.r:
						continue
				elif hyp(e.x - z.x, e.y - z.y) > z.r:
					continue
				if z.dps:
					damage(e, z.dps * dt, z.get("src"), 1)
				if z.slow:
					slow_enemy(e, z.slow, 0.3)
				if z.brk and not e.dead:
					e.brk = maxf(e.brk, z.brk)
					e.brk_t = maxf(e.brk_t, 0.3)
		if z.end_freeze and z.t <= 0:
			for e in in_range(z.x, z.y, z.r):
				freeze_enemy(e, z.end_freeze, h)
	if S.walls.size():
		update_walls(dt)
	S.zones = S.zones.filter(func(z): return z.t > 0)
	var due := S.delayed.filter(func(d): return S.time >= d.at)
	S.delayed = S.delayed.filter(func(d): return S.time < d.at)
	for d in due:
		if S.over:
			break
		d.fn.call()
	for sh in S.shells:
		if sh.wait > 0:
			sh.wait -= dt
			continue
		sh.t += dt
		if sh.t >= sh.T:
			sh.done = true
			land_shell(sh)
	move_shots(dt)
	S.shells = S.shells.filter(func(sh): return not sh.done)
	_towers_step(h, dt)
	if h.ko <= 0:
		for c in S.coins:
			if not c.get("got", false) and hyp(c.x - h.x, c.y - h.y) <= 30:
				c.got = true
				S.gold += 25
				ring(c.x, c.y, 20, 0xf2c14e, 0.4, true)
				sfx("kill")
		S.coins = S.coins.filter(func(c): return not c.get("got", false))
	for ec in S.echoes:
		if S.time >= ec.at:
			ec.done = true
			if not ec.target.dead:
				apply_hit(ec.t, ec.target, ec.d, false, ec.aslow)
				ring(ec.target.x, ec.target.y, 8, ec.t.color, 0.15)
	S.echoes = S.echoes.filter(func(ec): return not ec.get("done", false))
	S.enemies = S.enemies.filter(func(e): return not e.dead)
	for f in S.fx:
		f.t -= dt
	S.fx = S.fx.filter(func(f): return f.t > 0)
	for b in S.beams:
		b.t -= dt
	S.beams = S.beams.filter(func(b): return b.t > 0)


func _hero_step(h: Hero, HX: Dictionary, dt: float) -> void:
	# a boss stun freezes the hero in place: no moving, attacking or healing
	if h.stun_t > 0:
		h.stun_t -= dt
		return
	var kx := (1 if held.get("right", false) else 0) - (1 if held.get("left", false) else 0)
	var ky := (1 if held.get("down", false) else 0) - (1 if held.get("up", false) else 0)
	if key_move and (kx or ky) and not h.hold and h.cls != "wizard":
		var n := hyp(kx, ky)
		var step := h.speed * dt * (1 - h.drag if h.drag_t > 0 else 1.0)
		h.x = clampf(h.x + kx / n * step, 10, W - 10)
		h.y = clampf(h.y + ky / n * step, 10, H - 10)
		h.tx = null
		S.pending_build = null
	elif h.tx != null:
		var dx: float = h.tx - h.x
		var dy: float = h.ty - h.y
		var dd := hyp(dx, dy)
		var step := h.speed * dt * (1 - h.drag if h.drag_t > 0 else 1.0)
		if dd <= step:
			h.x = h.tx
			h.y = h.ty
			h.tx = null
		else:
			h.x += dx / dd * step
			h.y += dy / dd * step
	var pb = S.pending_build
	if pb and hyp(pb.c * C + C / 2 - h.x, pb.r * C + C / 2 - h.y) <= h.build_range:
		S.pending_build = null
		h.tx = null
		var why := build_problem(pb.c, pb.r, pb.type)
		if why != "":
			say(why)
		else:
			place_tower(pb.c, pb.r, pb.type)
	# No healing between waves, so waiting it out isn't free. Mana only flows during a wave.
	if S.wave_active:
		h.hp = minf(h.max_hp, h.hp + (h.regen + h.max_hp * sb("regen")) * dt)
	if h.max_mana and S.wave_active:
		h.mana = minf(h.max_mana, h.mana + h.mana_regen * (1 + sb("mana")) * dt)
	h.cd -= dt
	# Sniper: has to stand still for h.brace seconds before it can shoot.
	if h.brace:
		h.brace_t = minf(h.brace, h.brace_t + dt) if h.x == h.px and h.y == h.py else 0.0
	h.px = h.x
	h.py = h.y
	if h.cd <= 0 and (not h.brace or h.brace_t >= h.brace) and S.mode.get("challenge", "") != "benched" and h.range > 0:
		var inr := in_range(h.x, h.y, hero_range(h))
		if h.brace:
			inr.sort_custom(func(a, b): return (a.boss and not b.boss) or (a.boss == b.boss and a.d > b.d))
		else:
			inr.sort_custom(by_d_desc)
		if inr.size():
			_hero_attack(h, HX, inr)
	if HX.get("blades", 0):
		var nb: int = HX.blades + 1
		for i in nb:
			var ang := S.time * 3 + i * TAU / nb
			for e in in_range(h.x + cos(ang) * 42, h.y + sin(ang) * 42, 14):
				damage(e, 20 * HX.blades * dt)
	if h.boon_vent:
		for e in in_range(h.x, h.y, 80):
			damage(e, h.boon_vent * dt)
			slow_enemy(e, 0.15, 0.3)
	if h.boon_ion and S.enemies.size():
		S.ion_t -= dt
		if S.ion_t <= 0:
			S.ion_t = h.boon_ion
			var list := S.enemies.duplicate()
			list.shuffle()
			for e in list.slice(0, 4):
				damage(e, 60 + 2 * hero_dmg())
				line(e.x, 0, e.x, e.y, 0xffd36e, 0.2, 3)
	if HX.get("retribution", 0) and S.wave_active:
		h.ret_t -= dt
		var near := in_range(h.x, h.y, 110) if h.ret_t <= 0 else []
		if near.size():
			var dmg: float = 20 * HX.retribution + h.ret_store * 0.3 * HX.retribution
			for e in near:
				damage(e, dmg)
			ring(h.x, h.y, 110, 0x5fe39a, 0.4, true)
			if dmg > 80:
				do_shake(0.004, 120)
			h.ret_t = 4
			h.ret_store = 0
	if HX.get("barrage", 0) and S.wave_active:
		h.barrage_t -= dt
		var reach := minf(h.range, 400)
		var pool := in_range(h.x, h.y, reach + 60) if h.barrage_t <= 0 else []
		if pool.size():
			h.barrage_t = 5
			var n: int = 2 + 2 * HX.barrage
			var per: float = hero_dmg() * 1.5 + 10 * HX.barrage
			for i in n:
				later(0.08 * i, func():
					var live := S.enemies.filter(func(e): return not e.dead and hyp(e.x - h.x, e.y - h.y) <= reach + 120)
					if live.is_empty():
						return
					var e: Enemy = pick(live)
					line(h.x, h.y, e.x, e.y, 0xff6fd8, 0.18, 2)
					ring(e.x, e.y, 14, 0xff6fd8, 0.25, true)
					damage(e, per))
	if HX.get("wither", 0):
		for e in in_range(h.x, h.y, 90 + 20 * HX.wither):
			damage(e, 10 * HX.wither * dt)
			slow_enemy(e, 0.2, 0.3)
	if HX.get("drone", 0):
		S.drone_cd -= dt
		if S.drone_cd <= 0:
			var ts := in_range(h.x, h.y, 150)
			ts.sort_custom(by_d_desc)
			ts = ts.slice(0, HX.drone)
			if ts.size():
				S.drone_cd = 0.6
				for i in ts.size():
					var t: Enemy = ts[i]
					damage(t, 10 + 8 * HX.drone)
					line(h.x + (-22 if i else 22), h.y - 22, t.x, t.y, 0x5fe39a, 0.1, 1.5)


func _hero_attack(h: Hero, HX: Dictionary, inr: Array) -> void:
	h.cd = h.rate / (1 + h.momentum * h.mom_stacks) / (1 + h.ab.power if h.od_t > 0 else 1.0) / (1 + sb("rate")) / (1 - h.drag if h.drag_t > 0 else 1.0)
	h.attacks += 1
	sfx("snipe" if h.brace else "shot")
	var ts := inr if h.bullet_storm and h.attacks % int(h.bullet_storm) == 0 else inr.slice(0, 1 + int(h.multi) + (2 if h.od_t > 0 and h.ab.afterimg else 0))
	for t in ts:
		var crit := randf() < h.crit + sb("crit") or (h.deadeye and h.attacks % int(h.deadeye) == 0)
		var dmg := hero_dmg() * (h.crit_dmg if crit else 1.0)
		if t == ts[0]:
			h.aim_x = t.x
			h.aim_y = t.y
			h.atk_at = S.time
		if t.boss and (h.headhunter or sb("boss")):
			dmg *= 1 + h.headhunter + sb("boss")
		if S.one_shot_ready:
			dmg *= 10
			S.one_shot_ready = false
			ring(t.x, t.y, 46, 0xffffff, 0.6, true)
			do_shake(0.012, 250)
			say("One Shot!")
		if h.boon_rail and h.attacks % int(h.boon_rail) == 0:
			dmg *= 4
		var ex: bool = h.execute and not t.boss and (t.hp - dmg) / t.max <= h.execute
		if ex:
			dmg = t.hp + 1
		damage(t, dmg, null, 1 if ex else 0)
		if h.knock and not t.dead:
			# Gale: every hit shoves the enemy back a little (bosses barely move)
			push_back(t, 0.15, h.knock * (1 + sb("knock")) / 0.15, h)
			if h.knock_slow:
				slow_enemy(t, h.knock_slow, 2.0)
		if h.shot_stun:
			t.stun_t = maxf(t.stun_t, 0.2 if t.boss else h.shot_stun)
		if h.spotter:
			t.spot = maxf(t.spot, h.spotter)
			t.spot_t = 3
		if HX.get("marked", 0) and h.attacks % 5 == 0:
			t.mark = maxf(t.mark, 0.2 * HX.marked)
			t.mark_t = 4
			ring(t.x, t.y, t.r + 12, 0xff2e4d, 0.5)
		if HX.get("ricochet", 0):
			var from: Enemy = t
			var done := { t: true }
			for i in HX.ricochet:
				var n: Enemy = null
				for e in in_range(from.x, from.y, 160):
					if not done.has(e):
						n = e
						break
				if n == null:
					break
				damage(n, dmg * 0.5)
				line(from.x, from.y, n.x, n.y, 0xffd36e, 0.15, 2)
				done[n] = true
				from = n
		if h.pierce:
			for o in in_range(t.x, t.y, 60).filter(func(e): return e != t).slice(0, int(h.pierce)):
				damage(o, dmg * 0.5)
		if h.boon_slow:
			slow_enemy(t, h.boon_slow, 1.2)
		if h.boon_splash:
			for o in in_range(t.x, t.y, 45):
				if o != t:
					damage(o, dmg * h.boon_splash)
			ring(t.x, t.y, 45, 0xff6fd8, 0.2)
		if h.boon_chain:
			for o in in_range(t.x, t.y, 100).filter(func(e): return e != t).slice(0, int(h.boon_chain)):
				damage(o, dmg * 0.5)
				slow_enemy(o, 0.3, 1.2)
				line(t.x, t.y, o.x, o.y, 0x9af0ff, 0.12, 1)
		line(h.x, h.y, t.x, t.y, 0xffffff if crit else 0xf2c14e, 0.1, 3 if crit else 2, { l1 = 22, hero = true })
		if HX.get("chainstrike", 0):
			for o in in_range(t.x, t.y, 100).filter(func(e): return e != t).slice(0, 1 + HX.chainstrike):
				damage(o, dmg * 0.6)
				line(t.x, t.y, o.x, o.y, 0xf2c14e, 0.12, 1)


## Moves and hurts every enemy. Returns true when the run ended or the wave restarted.
func _enemies_step(h: Hero, dt: float) -> bool:
	var blocking := 0
	var order := S.enemies.duplicate()
	order.sort_custom(by_d_desc)
	var tank := hero_cat() == "defensive"
	for e in order:
		e.blocked = false
		e.aura_armor = 0
		if e.phase and not tank:
			continue # Phantoms walk through every hero except Defensive ones
		if h.ko <= 0 and blocking < h.block + int(sb("block")) and hyp(e.x - h.x, e.y - h.y) <= e.r + 14:
			e.blocked = true
			blocking += 1
	for sb in S.enemies:
		if sb.shield_aura and not sb.dead:
			for o in in_range(sb.x, sb.y, 70):
				if o != sb:
					o.aura_armor += sb.shield_aura
	var anvils := S.towers.filter(func(t): return t.type == "anvil" and not (t.stun_t > 0))
	S.tide = anvils.any(func(t): return t.tide)
	for e in S.enemies:
		if e.dead:
			continue
		if e.slow_t > 0:
			e.slow_t -= dt
			if e.slow_t <= 0:
				e.slow = 0
		if e.brittle_t > 0:
			e.brittle_t -= dt
			if e.brittle_t <= 0:
				e.brittle = 0
		if e.brk_t > 0:
			e.brk_t -= dt
		if e.boss:
			boss_act(e, dt)
		if e.regen and e.hp < e.max:
			e.hp = minf(e.max, e.hp + e.max * e.regen * dt)
		if e.heal:
			e.heal_t -= dt
			if e.heal_t <= 0:
				e.heal_t = 1
				var near := in_range(e.x, e.y, 70).filter(func(o): return o != e and not o.boss and o.hp < o.max)
				for o in near:
					o.hp = minf(o.max, o.hp + o.max * e.heal)
				if near.size():
					ring(e.x, e.y, 70, 0x7dffb0, 0.4)
		if e.hex_t > 0:
			e.hex_t -= dt
			e.hex_tick -= dt
			if e.hex_tick <= 0:
				e.hex_tick = 1
				var pulse: float = e.taken * e.hex
				if pulse > 0:
					for o in in_range(e.x, e.y, 60):
						damage(o, pulse, e.hex_src, 2)
					ring(e.x, e.y, 60, 0xb07cff, 0.35, true)
				if e.dead:
					continue
		# Deep Freeze (Frost signature): slowed for 3s straight freezes solid for 1s.
		if S.sig.get("frost", false):
			if e.slow_t > 0:
				e.slowed_for += dt
				if e.slowed_for >= 3:
					e.slowed_for = 0
					e.stun_t = maxf(e.stun_t, 1)
					ring(e.x, e.y, e.r + 8, 0xdff6ff, 0.5, true)
			else:
				e.slowed_for = 0
		# Grave Anvil pressure: time spent not moving.
		if e.stun_t > 0 or e.blocked or e.taunt_t > 0:
			e.still_t += dt
		else:
			e.still_t = maxf(0, e.still_t - dt * 2) if S.tide else 0.0
		if e.mark_t > 0:
			e.mark_t -= dt
		if e.spot_t > 0:
			e.spot_t -= dt
		if S.stasis_t > 0 and e.pos().distance_to(S.stasis_at) <= h.ab.r:
			slow_enemy(e, minf(0.85, h.ab.power * 0.75), 0.3)
			if h.ab.shatter_s:
				e.mark = maxf(e.mark, 0.25)
				e.mark_t = maxf(e.mark_t, 0.3)
		if S.overclock_t > 0 and h.ab.chrono and e.pos().distance_to(S.overclock_at) <= h.ab.r:
			slow_enemy(e, 0.3, 0.3)
		if e.burn_t > 0:
			e.burn_t -= dt
			damage(e, e.burn_dps * dt, e.burn_src, 1)
			if e.dead:
				continue
		if S.overclock_t > 0 and h.time_warp and e.pos().distance_to(S.overclock_at) <= h.ab.r:
			slow_enemy(e, h.time_warp, 0.3)
		if e.push_t > 0 and not e.pushback_immune:
			e.push_t -= dt
			if e.stun_t > 0:
				e.stun_t -= dt
			e.d = maxf(0, e.d - e.push_spd * dt)
		elif e.stun_t > 0:
			e.stun_t -= dt
		elif e.taunt_t > 0 and h.ko <= 0:
			e.taunt_t -= dt
			hurt_hero(h, e.atk * (1 - h.armor) * dt * 0.5)
			S.blocked += e.atk * dt * 0.5
		elif e.blocked:
			var guard := 0.0
			for t in anvils:
				if t.guard and hyp(t.x - e.x, t.y - e.y) <= t_range(t):
					guard = maxf(guard, t.guard)
			hurt_hero(h, e.atk * (1 - h.armor) * (1 - minf(0.6, guard)) * dt)
			S.blocked += e.atk * dt # defensive mastery: damage held off the base
			if h.shield > 0 and h.ab.spiked:
				damage(e, 40 * dt)
			if h.thorns:
				damage(e, h.thorns * dt)
		else:
			# Stone walls stop enemies (Phantoms drift through) and take their attacks
			var step: float = e.speed * (1 - e.slow) * dt
			var wall = wall_ahead(e, step) if not e.phase and S.walls.size() else null
			if wall:
				e.d = maxf(e.d, wall.d - e.r)
				wall.hp -= e.atk * dt
				e.still_t += dt
			else:
				e.d += step
			if e.d >= S.map.path_len:
				if _leak(e):
					return true
				continue
		if not e.dead:
			var p := pos_at(e.d)
			e.x = p.x
			e.y = p.y
	return false


## An enemy reached the base. Returns true when that ended the run or restarted the wave.
func _leak(e: Enemy) -> bool:
	e.dead = true
	sfx("leak")
	var big := BIG_BOSS.has(e.type)
	ring(S.map.base.x, S.map.base.y, 120 if big else 30, 0xff5d6c, 0.6, e.boss)
	do_shake(0.02 if e.boss else 0.004, 450 if e.boss else 120)
	# Big bosses end the run if they get through; mini bosses cost 5 base HP.
	if big:
		if S.mod_phoenix:
			S.mod_phoenix = false
			say("Phoenix Core destroyed the " + e.data.name + " at your gate!")
			return false
		if S.second_chance:
			restart_wave("The " + e.data.name + " broke through")
			return true
		S.lose_reason = "The " + e.data.name + " broke through your base."
		S.lives = 0
		end_run(false)
		return true
	S.lives -= e.lives
	if S.ws:
		S.ws.lives_lost += e.lives
	if S.mode.get("req", "") == "last" and S.wave_active:
		S.lose_reason = "Last Stand: an enemy got through."
		S.lives = 0
		end_run(false)
		return true
	if S.mode.get("req", "") == "flawless":
		fail_req("you lost base HP")
	if S.lives <= 0 and S.mod_phoenix:
		S.mod_phoenix = false
		S.lives = 10
		say("Phoenix Core saved your base!")
	if S.lives <= 0 and S.second_chance:
		restart_wave("Your base was about to fall")
		return true
	if S.lives <= 0:
		S.lives = 0
		end_run(false)
		return true
	refresh("hud")
	return false


func _towers_step(h: Hero, dt: float) -> void:
	var conductor: bool = S.specials.get("conductor", false) and h.cls == "oracle"
	compute_buffs()
	for t in S.towers:
		if t.curse_t > 0:
			t.curse_t -= dt
		if t.stun_t > 0:
			t.stun_t -= dt
			continue
		if t.support or t.hero_buff:
			continue
		if t.zero:
			for e in in_range(t.x, t.y, t_range(t)):
				slow_enemy(e, t.zero, 0.2)
		var spd := 1 + h.ab.power if overclocked(t) else 1 + h.ab.power * 0.5 if conductor else 1.0
		if h.ab.haste and S.stasis_t > 0 and S.stasis_at.distance_to(t.pos()) <= h.ab.r:
			spd *= 1 + h.ab.haste
		if t.ascend_t > 0:
			t.ascend_t -= dt
			spd *= 2
		if t.is_super:
			t.sp_t -= dt * spd
			if t.sp_t <= 0:
				t.sp_t = R.super_cooldown if super_power(t) else 0.25
		if t.buff:
			spd *= (1 + t.buff.rate) * (2.0 if t.buff.tempo else 1.0)
		if t.curse_t > 0:
			spd *= 1 - t.curse_rate
		if t.pact and S.enemies.any(func(e): return e.blocked and hyp(e.x - t.x, e.y - t.y) <= t_range(t)):
			spd *= 2
		t.cd -= dt * spd
		if t.cd > 0:
			continue
		if t.type == "anvil":
			# the hammer winds up, and the slam lands on the animation's impact frame
			if in_range(t.x, t.y, t_range(t)).size():
				t.cd = t.rate * S.mod_tower_rate
				t.shot_at = S.time
				later(fire_lead(t), func():
					if not S.towers.has(t) or t.stun_t > 0:
						return
					var a := in_range(t.x, t.y, t_range(t))
					if a.size():
						anvil_slam(t, a, 1.0))
			continue
		var targets := in_range(t.x, t.y, t_range(t))
		targets.sort_custom(by_d_desc)
		targets = targets.slice(0, 1 + int(t.multi))
		if t.lob:
			if targets.size():
				t.cd = t.rate * S.mod_tower_rate
				for e in targets:
					lob_shell(t, e, 1.0)
					if t.salvo:
						later(0.35, func(): if not e.dead: lob_shell(t, e, t.salvo))
			continue
		if targets.size():
			if t.tempo:
				t.tempo_stacks = minf(5, t.tempo_stacks + 1)
			t.cd = t.rate * S.mod_tower_rate * (1 - t.tempo * t.tempo_stacks)
			fire(t, targets)
			shot_effects(t, t.dmg * S.mod_tower_dmg)
		else:
			t.tempo_stacks = 0


# ---------- hero upgrade offers ----------
func roll_rarity() -> Dictionary:
	var G: Dictionary = Save.meta.global
	var luck := (1 + 0.04 * rank(G, "luck")) * (1 + 0.08 * rank(G, "fortune"))
	var ws := []
	var total := 0.0
	for x in DB.rarities:
		var w: float = x.w * (1 - 0.04 * rank(G, "fortune")) if x.id == "common" else x.w * luck
		ws.append(w)
		total += w
	var r := randf() * total
	for i in DB.rarities.size():
		r -= ws[i]
		if r < 0:
			return DB.rarities[i]
	return DB.rarities[0]


func _min_ok(p: UpgradeData, rarity: Dictionary) -> bool:
	return p.min_rarity == "any" or p.min_rarity == "" or rarity.mult >= DB.rar[p.min_rarity].mult


func make_offer(perk: UpgradeData, list: String, rarity: Dictionary, demonic: bool) -> Dictionary:
	var o := { perk = perk, list = list, rarity = rarity, demonic = false, m = perk.m, curse = null, k = 0.0 }
	if list != "perk":
		return o # uniques and ability upgrades have fixed effects and are never Demonic
	o.m = perk.m * rarity.mult * (2 if demonic else 1)
	if demonic:
		o.demonic = true
		o.curse = pick(R.curses.items)
		o.k = rarity.mult * (0.5 if S.specials.get("pact", false) else 1.0)
	return o


## Two slots from your hero's own pool, one shared slot (upgrades for every hero, or for heroes of your category).
## Common to Rare slots offer stat upgrades, stronger at higher rarity. Mythic and Legendary slots never do: they offer
## upgrades that change how you play (ability upgrades and game-changers), and Secret slots the secret ones.
## Upgrades you already own show up more often.
func roll_perks() -> Array:
	var h := S.hero
	var cat := hero_cat()
	var out := []
	var weighted := func(list: Array) -> Array:
		var bag := []
		for p in list:
			bag.append(p)
			if owns(p.id):
				bag.append(p)
				bag.append(p)
		return bag
	var shared := func(p: UpgradeData) -> bool: return p.pool == "any" or p.pool == cat or p.also_pools.has(cat)
	var mine := func(p: UpgradeData) -> bool: return p.pool == h.cls or p.also_pools.has(h.cls) or shared.call(p)
	# Wizard upgrades only come for what this run's elements can do; the Wizard never sees attack speed.
	var allowed := func(p: UpgradeData) -> bool:
		return not (p.attack_speed and h.data.spells) and (p.element == "" or h.els.has(p.element)) and (p.needs == "" or h.can.get(p.needs, false))
	var fits := func(p: UpgradeData) -> bool: return allowed.call(p) and (p.id != "critdmg" or h.crit > 0)
	var ab_ok := func(p: UpgradeData) -> bool: return p.ability == "" or p.ability == h.ab.id
	var slots := ["hero", "hero", "hero" if randf() < 0.3 else "shared"]
	slots.shuffle()
	for slot in slots:
		var rarity := roll_rarity()
		var demonic := randf() < R.demonic_chance
		var taken := {}
		var kinds := {}
		for o in out:
			taken[o.perk.id] = true
			kinds[o.perk.kind] = true
		var fresh := func(p: UpgradeData) -> bool: return not taken.has(p.id) and not kinds.has(p.kind)
		var perk: UpgradeData = null
		var list := "perk"
		var rar := rarity
		if rarity.id == "secret":
			perk = pick(R.uniques.items.filter(func(u): return u.rarity == "secret" and not owns(u.id) and fresh.call(u)))
			list = "unique"
			if perk == null:
				list = "perk"
				rar = DB.rar.legendary
		if perk == null and rar.mult >= DB.rar.mythic.mult:
			# game-changers: this tier first, then the other one, then a Rare stat upgrade
			var tiers := ["legendary", "mythic"] if rar.id == "legendary" else ["mythic", "legendary"]
			for tier in tiers:
				var uniq := R.uniques.items.filter(func(u): return u.rarity == tier and mine.call(u) and ab_ok.call(u) and allowed.call(u) and not owns(u.id) and fresh.call(u))
				var mods := R.ability_mods.items.filter(func(m): return m.pool == h.cls and m.ability == h.ab.id and (m.min_rarity == "legendary") == (tier == "legendary") \
					and not h.ab.has_mod(m.id) and fresh.call(m))
				var both := uniq + mods
				if both.size():
					perk = pick(both)
					list = "mod" if mods.has(perk) else "unique"
					rar = DB.rar[tier]
					break
			if perk == null:
				rar = DB.rar.rare
		if perk == null:
			var pool := func(p: UpgradeData) -> bool: return (p.pool == h.cls if slot == "hero" else shared.call(p)) and ab_ok.call(p) and fits.call(p) and _min_ok(p, rar)
			# If every kind in this pool is already on offer, fall back to anything not already shown.
			perk = pick(weighted.call(R.perks.items.filter(func(p): return pool.call(p) and fresh.call(p))))
			if perk == null:
				perk = pick(weighted.call(R.perks.items.filter(func(p): return (shared.call(p) if slot == "hero" else p.pool == h.cls) and ab_ok.call(p) and allowed.call(p) and fresh.call(p))))
			if perk == null:
				perk = pick(R.perks.items.filter(func(p): return (pool.call(p) or shared.call(p)) and allowed.call(p) and not taken.has(p.id)))
		if perk:
			out.append(make_offer(perk, list, rar, demonic and list == "perk"))
	return out


func perk_key(o: Dictionary) -> String:
	return { mod = "mod:", unique = "unique:", perk = "perk:" }[o.list] + o.perk.id


func perk_desc(o: Dictionary) -> String:
	return DB.tx(perk_key(o), Fx.text(o.perk.desc, { h = S.hero, run = S, m = o.m }))


func curse_desc(o: Dictionary) -> String:
	return DB.tx("curse:" + o.curse.id, Fx.text(o.curse.desc, { k = o.k, run = S, h = S.hero }))


func pool_name(o: Dictionary) -> String:
	var p: UpgradeData = o.perk
	if o.list == "mod":
		return S.hero.ab.name + " upgrade"
	if p.pool == "any":
		return "Shared"
	if DB.heroes.has(p.pool):
		return DB.heroes[p.pool].name
	return p.pool.capitalize()


func owned_count(id: String) -> int:
	return S.picks.filter(func(x): return x.perk.id == id).size()


func apply_offer(o: Dictionary) -> void:
	Fx.run(o.perk.effect, { h = S.hero, run = S, m = o.m })


var offers: Array = []


func show_level_up(reroll := false) -> void:
	S.paused = true
	if not reroll:
		sfx("level")
	offers = roll_perks()
	modal.emit("level_up", { offers = offers, lvl = S.hero.lvl, rerolls = S.rerolls })


func reroll_offers() -> void:
	if S.rerolls > 0:
		S.rerolls -= 1
		show_level_up(true)


func pick_offer(i: int) -> void:
	var o: Dictionary = offers[i]
	var h := S.hero
	apply_offer(o)
	if o.demonic:
		Fx.run(o.curse.effect, { run = S, h = h, k = o.k })
	S.picks.append(o)
	if o.list == "mod":
		ring(h.x, h.y, 60, 0xff6fd8, 0.8, true)
		say(h.ab.name + " upgraded: " + o.perk.name + "!")
	elif o.rarity.id != "common" or o.demonic:
		say(("Demonic " if o.demonic else "") + o.rarity.name + " upgrade: " + o.perk.name + "!")
	S.pending_levels -= 1
	S.paused = false
	refresh("build_bar")
	refresh("hero")


func show_boon() -> void:
	S.paused = true
	var rec: RecipeData = DB.recipes[S.pending_boon]
	modal.emit("boon", { recipe = rec, desc = DB.tx("boon:" + rec.key, rec.boon_desc) })


func take_boon() -> void:
	var rec: RecipeData = DB.recipes[S.pending_boon]
	Fx.run(rec.boon_effect, { h = S.hero, run = S })
	S.boons[rec.key] = true
	S.pending_boon = ""
	S.paused = false
	refresh("hero")
	say("Awakened: " + rec.boon_name + ".")


var heroic_fresh: Array = []
var heroic_owned: Array = []


func heroic_desc(x: UpgradeData, r: int) -> String:
	return Fx.text(x.desc, { r = r })


## After a boss: 3 new heroic powers, plus options to rank up ones you own (up to rank 3).
func show_heroic() -> void:
	S.paused = true
	var fresh := R.heroics.items.filter(func(x): return not S.heroics.get(x.id, 0) and (x.heroes.is_empty() or x.heroes.has(S.hero.cls)))
	fresh.shuffle()
	heroic_fresh = fresh.slice(0, 3)
	var owned := R.heroics.items.filter(func(x): return S.heroics.get(x.id, 0) and S.heroics[x.id] < 3)
	owned.shuffle()
	heroic_owned = owned.slice(0, 4 - heroic_fresh.size())
	if heroic_fresh.is_empty() and heroic_owned.is_empty():
		S.pending_heroic -= 1
		S.gold += 250
		S.paused = false
		say("Every heroic power is maxed, so the boss dropped 250 gold instead.")
		return
	modal.emit("heroic", { fresh = heroic_fresh, owned = heroic_owned })


func pick_heroic(x: UpgradeData) -> void:
	S.heroics[x.id] = S.heroics.get(x.id, 0) + 1
	S.pending_heroic -= 1
	S.paused = false
	refresh("hero")
	say("Heroic power: %s rank %d." % [x.name, S.heroics[x.id]])


# ---------- the boss shop ----------
var shop_items: Array = []
var shop_free := false
var shop_demonic := false


func show_shop() -> void:
	S.need_shop = false
	S.paused = true
	S.shops += 1
	shop_demonic = randf() < (0.1 if S.specials.get("pact", false) else 0.01)
	var scale := 1 + S.wave / 20.0
	shop_free = bool(S.specials.get("bazaar", false))
	var list := R.shop.items.duplicate()
	list.shuffle()
	shop_items = []
	var i := 0
	for it in list.slice(0, 9 if shop_free else 6):
		var dem := shop_demonic and i % 2 == 0
		shop_items.append({ it = it, dem = dem, m = it.m * (2 if dem else 1), cost = int(round(it.price * scale * map_price() / 10)) * 10,
			curse = pick(R.curses.items) if dem else null, k = 1.5 if S.specials.get("pact", false) else 3.0, sold = false })
		i += 1
	modal.emit("shop", { items = shop_items, demonic = shop_demonic })


func shop_price(x: Dictionary) -> int:
	return 0 if shop_free else x.cost


func shop_desc(x: Dictionary) -> String:
	return DB.tx("shop:" + x.it.id, Fx.text(x.it.desc, { m = x.m, run = S, h = S.hero }))


func buy(i: int) -> void:
	var x: Dictionary = shop_items[i]
	var price := shop_price(x)
	if x.sold or S.gold < price:
		return
	S.gold -= price
	x.sold = true
	shop_free = false
	Fx.run(x.it.effect, { m = x.m, run = S, h = S.hero })
	if x.curse:
		Fx.run(x.curse.effect, { k = x.k, run = S, h = S.hero })
	say("Bought " + x.it.name + ".")
	sfx("level")
	refresh("hero")
	modal.emit("shop", { items = shop_items, demonic = shop_demonic })


func leave_shop() -> void:
	S.paused = false
	refresh("build_bar")
	refresh("hero")


# ---------- building ----------
func tower_at(c: int, r: int) -> Tower:
	for t in S.towers:
		if t.c == c and t.r == r:
			return t
	return null


## Towers stand up out of their tile, so pointing at the top of one (the tile above it) picks it too.
func pick_tower(c: int, r: int) -> Tower:
	var t := tower_at(c, r)
	if t:
		return t
	if not S.map.path_cells.has(Vector2i(c, r)):
		return tower_at(c, r + 1)
	return null


func in_build_range(c: int, r: int) -> bool:
	var h := S.hero
	return hyp(c * C + C / 2 - h.x, r * C + C / 2 - h.y) <= h.build_range


func build_problem(c: int, r: int, type: String) -> String:
	var k := Vector2i(c, r)
	if c < 0 or r < 0 or c >= COLS or r >= ROWS:
		return "Out of bounds."
	if S.map.path_cells.has(k):
		return "You can’t build on the path."
	if S.map.blocked.has(k):
		return "You can’t build on water." if S.map.water_cells.has(k) else "Something is in the way."
	if tower_at(c, r):
		return "That tile is taken."
	if S.hero.ko > 0:
		return "Your hero is knocked out."
	if S.gold < tower_cost(type):
		return "Not enough gold."
	if DB.towers[type].hero_buff and S.towers.any(func(t): return t.hero_buff):
		return "You can only have one Hero Shrine."
	return ""


func new_tower(type: String, c: int, r: int) -> Tower:
	var d: TowerData = DB.towers[type]
	var G: Dictionary = Save.meta.tower_global
	var main := 1 + 0.04 * rank(G, "main")
	var t := Tower.new()
	t.type = type
	t.c = c
	t.r = r
	t.x = c * C + C / 2
	t.y = r * C + C / 2
	# the all-tower upgrades: main effect, range and attack speed (cheaper level-ups are in level_cost)
	t.dmg = d.dmg * (1.0 if type == "frost" else main)
	t.rate = d.rate / (1 + 0.02 * rank(G, "speed"))
	t.range = d.range * (1 + 0.02 * rank(G, "range"))
	t.support = d.support
	t.b_dmg = 0.15 * main if d.support and not d.hero_buff else 0.0
	t.hero_buff = d.hero_buff
	if d.hero_buff:
		t.hb_dmg = 0.1 * main
		t.hb_armor = 0.05
	t.splash = d.splash
	t.slow = minf(0.85, d.slow * (main if type == "frost" else 1.0))
	t.chain = d.chain
	t.ramp = 0.08 if d.beam else 0.0
	t.beam = d.beam
	t.ramp_max = 20.0 if d.beam else 5.0
	t.lob = d.lob
	t.color = d.color
	t.base_cost = d.cost
	return t


func place_tower(c: int, r: int, type: String) -> void:
	var cost := tower_cost(type)
	var t := new_tower(type, c, r)
	var h := S.hero
	S.gold -= cost
	t.spent = cost
	S.towers.append(t)
	S.built[type] = true
	S.bought[type] = S.bought.get(type, 0) + 1
	t.free_ups = (2 if S.specials.get("foundry", false) else 0) + (int(h.rapid) if h.rapid and hyp(h.x - t.x, h.y - t.y) <= h.aura_range else 0) + h.free_build
	if t.free_ups:
		ring(t.x, t.y, 30, 0xb07cff, 0.5, true)
	if S.build != "" and S.gold < tower_cost(S.build):
		S.build = ""
	sfx("click")
	refresh("build_bar")
	refresh("inspector")


func sell_value(t: Tower) -> int:
	return int(floor(t.spent * R.sell_rate))


func sell(t: Tower) -> void:
	if t == null or not S.towers.has(t):
		return
	var v := sell_value(t)
	S.gold += v
	S.towers.erase(t)
	if S.sel == t:
		S.sel = null
	if S.drained == t:
		S.drained = null
	say("Sold %s for %d gold." % [tower_name(t), v])
	sfx("click")
	refresh("inspector")
	refresh("build_bar")


# ---------- levels and paths ----------
## A path option: { id, name, desc, tag, path (TowerPath) or fusion (FusionData), m }.
func tower_options(t: Tower) -> Array:
	var out := []
	if t.hybrid:
		var m := 1.5 if t.is_super else 1.0
		for f in t.fusions:
			out.append({ id = f.id, name = ("Ascended " if m > 1 else "") + f.name, fusion = f, path = null, m = m,
				desc = Fx.text(f.desc, { r = 1, m = m }) + " Grows with each point, plus +8% damage per point." })
	else:
		for p in tower_paths(t.type):
			out.append({ id = p.id, name = p.name, path = p, fusion = null, m = 1.0, desc = DB.tx("path:" + t.type + ":" + p.id, p.desc) })
	return out


func path_desc(o: Dictionary) -> String:
	if o.fusion and DB.is_simple() and DB.simple_texts.has("fusion:" + o.id):
		return DB.simple_texts["fusion:" + o.id] + " Also hits harder."
	return o.desc


func path_state(t: Tower, o: Dictionary) -> String:
	var n := t.ups_of(o.id)
	if n >= path_max():
		return "maxed"
	if not n and t.order.size() >= path_limit():
		return "locked"
	return "open"


func _rank_up(t: Tower, o: Dictionary, r: int) -> void:
	if o.fusion:
		Fx.run(o.fusion.effect, { t = t, m = o.m })
		t.dmg *= 1.08
	else:
		Fx.run(o.path.effect, { t = t, rank = r })


## The stat changes of one level-up (shared by the real level-up and the "current -> new" preview).
func apply_level(t: Tower, o: Dictionary) -> Dictionary:
	t.lvl += 1
	var lk := level_key(t)
	Fx.run(R.get("level_" + lk), { t = t })
	if not t.ups.has(o.id):
		t.order.append(o.id)
	var pts := t.ups_of(o.id) + 1
	t.ups[o.id] = pts
	var mx := path_max()
	# Oracle points are bigger: they apply ranks in steps of 2/1/1, so 3 points reach the same rank 4.
	var target: int = ORACLE_RANKS[pts] if mx == 3 else pts
	for r in range(int(t.rk.get(o.id, 0)) + 1, target + 1):
		_rank_up(t, o, r)
	t.rk[o.id] = target
	var mastered: bool = pts == mx and o.path != null and o.path.mastery_effect != ""
	if mastered:
		Fx.run(o.path.mastery_effect, { t = t })
	if t.lvl == R.max_level:
		Fx.run(R.get("ascend_" + lk), { t = t })
	return { pts = pts, max = mx, mastered = mastered }


## A tower's 5 paths. The Hero Shrine's depend on the hero: it uses the set made for this run's hero.
func tower_paths(type: String) -> Array:
	var d: TowerData = DB.towers[type]
	if d.hero_paths.size() and S and S.hero:
		var fallback = null
		for ps in d.hero_paths:
			if ps.hero == S.hero.cls:
				return ps.paths
			if ps.hero == "":
				fallback = ps
		if fallback:
			return fallback.paths
	return d.paths


func form_key(t: Tower) -> String:
	var paths: Array = tower_paths(t.type)
	var idx := []
	for id in t.order:
		for i in paths.size():
			if paths[i].id == id:
				idx.append(i)
	idx.sort()
	return "".join(idx.map(func(i): return str(i)))


## Form name once a tower has 3 paths. Falls back to adjective + noun + "of <title>" for a combination without a name.
func form_name(t: Tower) -> String:
	var d: TowerData = DB.towers[t.type]
	var named = d.form_names.get(form_key(t))
	if named:
		return named
	var paths := []
	for id in t.order:
		for p in tower_paths(t.type):
			if p.id == id:
				paths.append(p)
	paths.sort_custom(func(a, b):
		var ua := t.ups_of(a.id)
		var ub := t.ups_of(b.id)
		return ua > ub if ua != ub else t.order.find(a.id) < t.order.find(b.id))
	var s: String = paths[0].adjective + " " + (paths[1].noun if paths.size() > 1 else d.name)
	if paths.size() > 2:
		s += " of " + paths[2].title
	if paths.size() > 3:
		s += " and " + paths[3].title
	return s


func discover_form(t: Tower) -> void:
	if t.hero_buff:
		return # its paths change with the hero, so its forms stay out of the codex
	var id := t.type + ":" + form_key(t)
	if not Save.meta.forms.get(id, false):
		Save.meta.forms[id] = true
		Save.save_meta()
		ring(t.x, t.y, 70, 0xfff0a0, 0.9, true)


func level_tower(t: Tower, o: Dictionary) -> void:
	if S.user_pause:
		say("Paused: press Space or P to resume first.")
		return
	var lc := level_cost(t, o)
	if S.gold < lc or t.lvl >= R.max_level or path_state(t, o) != "open":
		return
	if t.free_ups > 0:
		t.free_ups -= 1
	elif S.free_levels > 0:
		S.free_levels -= 1
	S.gold -= lc
	t.spent += lc
	var res := apply_level(t, o)
	var old := tower_name(t)
	# Once a tower has 3 paths it takes the name of that combination (and renames if a 4th or 5th is added).
	if not t.hybrid and t.order.size() >= 3:
		t.name = form_name(t)
		discover_form(t)
	var msg := "%s reached level %d: %s %d/%d" % [tower_name(t), t.lvl, o.name, res.pts, res.max]
	if tower_name(t) != old:
		msg = old + " became the " + tower_name(t) + "!"
		ring(t.x, t.y, 50, t.color, 0.7, true)
		sfx("level")
	if res.mastered:
		msg += ", mastered: " + o.path.mastery_name
	if t.lvl == R.max_level:
		if not t.hybrid:
			t.name = form_name(t)
			discover_form(t)
		else:
			t.perfected = true
		msg = tower_name(t) + (" is perfected" if t.hybrid else " ascended") + " at level %d!" % R.max_level
		sfx("level")
	else:
		sfx("click")
	say(_dot(msg))
	refresh("inspector")
	refresh("build_bar")


## A copy of the tower with one more level in this path, for "current -> new" previews.
func preview_level(t: Tower, o: Dictionary) -> Dictionary:
	var c := t.duplicate_for_preview()
	var keep := S.free_levels
	var res := apply_level(c, o)
	S.free_levels = keep
	return { tower = c, mastered = res.mastered }


# ---------- merging ----------
## Why two towers can't merge, or "" if they can.
func merge_problem(a: Tower, b: Tower) -> String:
	if a.hero_buff or b.hero_buff:
		return "The Hero Shrine can’t be merged."
	if a.is_super or b.is_super:
		return "Super towers are already fully merged."
	if a.lvl < R.max_level or b.lvl < R.max_level:
		return "Both towers need to be level %d." % R.max_level
	if a.hybrid != b.hybrid:
		return "Merge two basic towers into a hybrid, or two hybrids into a super tower."
	if not a.hybrid and a.type == b.type:
		return "Merge two different tower types."
	return ""


func fusion_by_id(id: String) -> FusionData:
	for f in DB.fusions:
		if f.id == id:
			return f
	return null


## The tags a tower brings into a merge: its element plus the paths it actually chose.
func tower_tags(t: Tower) -> Array:
	var out := []
	if t.hybrid:
		out += Array(t.tags)
		for id in t.order:
			var f := fusion_by_id(id)
			if f:
				out += Array(f.tags)
		return out
	var d: TowerData = DB.towers[t.type]
	out.append(d.element_tag)
	for id in t.order:
		for p in tower_paths(t.type):
			if p.id == id:
				for i in t.ups_of(id):
					out.append(p.tag)
	return out


static func hash_str(s: String) -> int:
	var h := 2166136261
	for ch in s.to_utf8_buffer():
		h = ((h ^ ch) * 16777619) & 0xffffffff
	return h


func pick_fusions(tags: Array, seed: String, exclude: Array) -> Array:
	var scored := []
	for f in DB.fusions:
		if exclude.has(f.id):
			continue
		var s := 0
		for k in f.tags:
			s += tags.count(k)
		scored.append({ f = f, score = s * 1000 + hash_str(seed + f.id) % 1000 })
	scored.sort_custom(func(a, b): return a.score > b.score)
	return scored.slice(0, 5).map(func(x): return x.f)


func super_text(parents: Array) -> String:
	var parts := []
	for k in parents:
		var d: TowerData = DB.towers[k]
		parts.append("%s: %s." % [d.super_power_name, d.super_power_desc])
	return " ".join(parts)


func try_merge(a: Tower, b: Tower) -> void:
	S.merge_from = null
	var why := merge_problem(a, b)
	var cost := merge_cost(a)
	if why != "":
		say(why)
		refresh("inspector")
		return
	if S.gold < cost:
		say("Merging costs %d gold." % cost)
		refresh("inspector")
		return
	S.gold -= cost
	var tags := tower_tags(a) + tower_tags(b)
	# A merged tower always shoots: it drops the beam, the lobbed shells and the Beacon's no-attack role, and keeps
	# what those gave it as traits (heat, splash, the buff). A Siege Mortar's reach is only partly kept.
	var m := Tower.new()
	m.c = b.c
	m.r = b.r
	m.x = b.x
	m.y = b.y
	m.spent = a.spent + b.spent + cost
	m.base_cost = a.base_cost + b.base_cost
	m.range = minf(maxf(a.range, b.range) * 1.1, minf(a.range, b.range) * 1.6)
	m.tags = PackedStringArray(tags)
	m.ramp_max = maxf(10.0 if a.beam or b.beam else 5.0, maxf(a.ramp_max if not a.beam else 0.0, b.ramp_max if not b.beam else 0.0))
	m.hybrid = true
	m.dmg_total = a.dmg_total + b.dmg_total
	m.kills = a.kills + b.kills
	var key := ""
	var label: String
	if a.hybrid:
		var ps := {}
		for k in Array(a.parents) + Array(b.parents):
			ps[k] = true
		var parents := ps.keys()
		parents.sort()
		var info: RecipeData = DB.recipes.get("+".join(parents))
		var recipe: RecipeData = DB.recipes[a.type]
		label = info.name if info else "Prime " + recipe.name
		m.type = a.type
		m.is_super = true
		m.parents = PackedStringArray(parents)
		m.name = label
		m.color = info.color if info else recipe.color
		m.desc = (info.desc if info else "Two " + recipe.name + "s fused into one. " + recipe.desc) + " Its paths are ascended versions of fusion effects its hybrids never used. Every %ds it unleashes its next signature power. " % int(R.super_cooldown) + super_text(parents)
		m.fusions = pick_fusions(tags, "+".join(parents) + ",".join(a.order) + ",".join(b.order), a.order + b.order)
		m.dmg = maxf(a.dmg, b.dmg) * 2.5
		m.rate = minf(a.rate, b.rate) * 0.75
		m.sp_t = 1.5
	else:
		var pk := [a.type, b.type]
		pk.sort()
		key = "+".join(pk)
		var rec: RecipeData = DB.recipes[key]
		var fa := a.name.split(" ")[0] if a.name != "" else ""
		label = (fa + " " if fa != "" else "") + rec.name
		m.type = key
		m.parents = PackedStringArray([a.type, b.type])
		m.color = rec.color
		m.name = label
		m.desc = rec.desc + " Fused from %s and %s, so its paths come from what they used." % [tower_name(a), tower_name(b)]
		m.fusions = pick_fusions(tags, key + ",".join(a.order) + ",".join(b.order), [])
		m.dmg = maxf(a.dmg, b.dmg) * 1.5
		m.rate = minf(a.rate, b.rate)
	m.up_start = hybrid_up_start(m.parents, m.is_super)
	for k in Tower.TRAITS:
		m.set(k, maxf(float(a.get(k)), float(b.get(k))))
	m.chain_keep = a.chain_keep or b.chain_keep
	m.retain = a.retain or b.retain
	m.melt = a.melt or b.melt
	m.shackle = a.shackle or b.shackle
	m.after = a.after or b.after
	m.tide = a.tide or b.tide
	m.pact = a.pact or b.pact
	m.firestorm = a.firestorm or b.firestorm
	m.quake_stun = a.quake_stun or b.quake_stun
	m.press = maxf(a.press, b.press)
	m.press_cap = maxf(a.press_cap, b.press_cap)
	m.pin = maxf(a.pin, b.pin)
	m.guard = maxf(a.guard, b.guard)
	m.crush_exec = maxf(a.crush_exec, b.crush_exec)
	m.salvo = maxf(a.salvo, b.salvo)
	m.hex_nova = maxf(a.hex_nova, b.hex_nova)
	if m.parents.has("anvil"):
		m.crush = maxf(m.crush, 0.5)
	# Fast + heavy parents would otherwise get the big hit at the fast rate: keep damage per second within 2.6x
	# the stronger parent's (6x for supers).
	var dps_cap := (6.0 if m.is_super else 2.6) * maxf(a.dmg / a.rate, b.dmg / b.rate)
	if m.dmg / m.rate > dps_cap:
		m.dmg = dps_cap * m.rate
	if not m.dmg:
		m.dmg = maxf(maxf(a.dmg, b.dmg), 10)
	if m.chain:
		m.chain += 1
	if m.is_super:
		m.multi += 2
		do_shake(0.03, 600)
		for i in 4:
			ring(b.x, b.y, 50 + 40 * i, Color.WHITE if i % 2 else m.color, 0.6 + 0.2 * i, true)
		fx_add({ k = "pillar", x = b.x, y = b.y, w = 20.0, color = m.color, t = 1.2 })
	var bi := S.towers.find(b)
	S.towers[bi] = m
	S.towers.erase(a)
	if S.drained == a or S.drained == b:
		S.drained = null
	ring(b.x, b.y, 60 if m.is_super else 40, m.color, 0.6, true)
	if key != "":
		var is_new: bool = not Save.codex.get(key, false)
		Save.codex[key] = true
		Save.save_codex()
		say(("New recipe: " if is_new else "Merged into ") + label + "!")
		if rec_has_boon(key) and not S.boons.get(key, false) and randf() < 0.35:
			S.pending_boon = key
	else:
		say("Super merge: " + label + "!")
	sfx("level")
	S.sel = m
	refresh("inspector")
	refresh("codex")
	refresh("build_bar")


func rec_has_boon(key: String) -> bool:
	return DB.recipes.has(key) and DB.recipes[key].boon_effect != ""


# ---------- the end of a run ----------
func hero_run_stat() -> int:
	var c := hero_cat()
	return int(round(S.blocked if c == "defensive" else S.assists if c == "support" else S.kills.hero))


func end_run(won: bool, quit := false) -> void:
	S.over = true
	refresh("mode")
	close_wave_log(won)
	var M := Save.meta
	var sc: MapScene = S.map.scene
	var cleared: int = max_wave if won else (S.wave - 1 if S.wave_active else S.wave)
	var shards := int(round((cleared * R.shards_per_wave + S.boss_kills * R.shards_per_boss + (R.shards_for_win if won else 0)) * sc.shard_mult))
	M.shards += shards
	M.cores = int(M.get("cores", 0)) + S.cores
	var cls := S.hero.cls
	M.played[cls] = int(M.played.get(cls, 0)) + 1
	M.wiz_pushes = int(M.get("wiz_pushes", 0)) + S.wiz_pushes
	S.wiz_pushes = 0
	# kills and wins feed mastery: report what moved
	var el_was := []
	for el in S.el_mana:
		el_was.append([el, Progress.el_mastery(el).lvl])
	for el in S.el_mana:
		M.el_stat[el] = float(M.el_stat.get(el, 0)) + S.el_mana[el] / 10.0
	var was := []
	if not S.hero.data.spells:
		was.append(["heroes", cls, Progress.mastery_of("heroes", cls).lvl])
	for k in DB.tower_order:
		if S.kills.towers.get(k, 0) or S.built.get(k, false):
			was.append(["towers", k, Progress.mastery_of("towers", k).lvl])
	M.hero_stat[cls] = Progress.hero_stat(cls) + hero_run_stat()
	M.kills.heroes[cls] = int(M.kills.heroes.get(cls, 0)) + S.kills.hero
	for k in S.kills.towers:
		M.kills.towers[k] = int(M.kills.towers.get(k, 0)) + S.kills.towers[k]
	M.takedowns.heroes[cls] = int(M.takedowns.heroes.get(cls, 0)) + S.takedowns.hero
	for k in S.takedowns.towers:
		M.takedowns.towers[k] = int(M.takedowns.towers.get(k, 0)) + S.takedowns.towers[k]
	if won:
		if not (M.wins.heroes.get(cls) is Dictionary):
			M.wins.heroes[cls] = {}
		M.wins.heroes[cls][S.map_id] = true
		for k in S.built:
			if not (M.wins.towers.get(k) is Dictionary):
				M.wins.towers[k] = {}
			M.wins.towers[k][S.map_id] = true
	var mastery := []
	for w in was:
		var now: int = Progress.mastery_of(w[0], w[1]).lvl
		if now > w[2]:
			mastery.append({ name = DB.heroes[w[1]].name if w[0] == "heroes" else DB.towers[w[1]].name, a = w[2], b = now, color = null })
	for w in el_was:
		var now: int = Progress.el_mastery(w[0]).lvl
		if now > w[1]:
			mastery.append({ name = DB.elements[w[0]].name, a = w[1], b = now, color = DB.elements[w[0]].color,
				triple = w[1] < R.triple_at and now >= R.triple_at })
	var best = M.best.get(S.map_id)
	var locked_songs := Sound.songs.filter(func(x): return not Sound.song_open(x))
	if best == null or cleared > best.wave or (won and not best.won):
		M.best[S.map_id] = { wave = cleared, won = won or (best != null and best.won) }
	var new_songs := locked_songs.filter(func(x): return Sound.song_open(x))
	if new_songs.size() and Save.settings.get("playlist") is Array:
		for x in new_songs:
			Save.settings.playlist.append(x.id)
		Save.save_settings()
	var top: Tower = null
	for t in S.towers:
		if top == null or t.dmg_total > top.dmg_total:
			top = t
	M.runs.append({ date = Time.get_datetime_string_from_system(true), map = S.map_id, hero = cls, wave = S.wave, won = won, shards = shards, cores = S.cores,
		lives_lost = S.start_lives - S.lives, hero_lvl = S.hero.lvl, top = tower_name(top) + " L" + str(top.lvl) if top else "",
		upgrades = S.picks.map(func(o): return ("Demonic " if o.demonic else "") + o.rarity.name + " " + o.perk.name), heroics = S.heroics.duplicate(),
		relics = S.relics.map(func(r): return r.name), boons = S.boons.keys().map(func(k): return DB.recipes[k].boon_name), waves = S.log,
		ability = "Spellcraft" if S.hero.data.spells else S.hero.ab.name, kills_hero = S.kills.hero, kills_towers = _sum(S.kills.towers.values()),
		takedowns = S.takedowns.hero, blocked = int(round(S.blocked)), run_seconds = int(round(S.time)),
		towers = S.towers.map(func(t): return { name = tower_name(t) + " L" + str(t.lvl), dmg = int(round(t.dmg_total)), kills = t.kills }) })
	M.runs = M.runs.slice(-25)
	Save.save_meta()
	modal.emit("end", { won = won, quit = quit, shards = shards, cores = S.cores, mastery = mastery, new_songs = new_songs, cleared = cleared })


func _sum(xs: Array) -> float:
	var n := 0.0
	for x in xs:
		n += float(x)
	return n


# ---------- player actions (mouse and keys) ----------
func cell_at(x: float, y: float) -> Vector2i:
	return Vector2i(floori(x / C), floori(y / C))


func cancel_placing() -> bool:
	if S.strike_ready:
		S.strike_ready = false
		say("Orbital Strike put away.")
		refresh("build_bar")
		return true
	if S.build == "" and S.merge_from == null and S.pending_build == null:
		return false
	S.build = ""
	S.merge_from = null
	S.pending_build = null
	say("Cancelled.")
	refresh("build_bar")
	refresh("inspector")
	return true


## Hold position (H): tanks and the Sniper can lock themselves in place so a stray click never moves them.
## Tanks also snap to the middle of the nearest path tile, so they block cleanly.
func can_hold() -> bool:
	return S.hero.data.category == "defensive" or S.hero.cls == "sniper"


## The centre of the path tile nearest (x, y), or null when no path tile is within reach.
func path_tile_near(x: float, y: float, reach: float):
	var best = null
	var bd := reach
	for cell in S.map.path_cells:
		var p := Vector2(cell.x * C + C / 2, cell.y * C + C / 2)
		var dd := hyp(p.x - x, p.y - y)
		if dd < bd:
			bd = dd
			best = p
	return best


func toggle_hold() -> void:
	var h := S.hero
	if S.over or not can_hold():
		return
	h.hold = not h.hold
	h.tx = null
	S.pending_build = null
	held.clear()
	if h.hold and h.data.category == "defensive" and h.ko <= 0:
		var spot = path_tile_near(h.x, h.y, 90)
		if spot != null:
			h.x = spot.x
			h.y = spot.y
			ring(h.x, h.y, 22, 0x5fe39a, 0.35)
	say("Holding position: your hero won’t move until you press H again." if h.hold else "Your hero can move again.")
	refresh("build_bar")
	refresh("hero")


## Aim point (F): Piercing Shot always fires toward it. Press F near it again to clear it.
func toggle_aim() -> void:
	var h := S.hero
	if S.over or h.cls != "sniper":
		return
	if pierce_cursor():
		say("Piercing Shot follows your cursor. Switch to aim points in Settings.")
		return
	var p = S.pointer
	if S.aim != null and (p == null or (p as Vector2).distance_to(S.aim) < 30):
		S.aim = null
		say("Aim point cleared: Piercing Shot aims at the lead enemy.")
	elif p != null:
		S.aim = p
		say("Aim point set: Piercing Shot fires toward it. Press F on it to clear.")
	else:
		say("Point at the board, then press F to set an aim point.")
		return
	refresh("build_bar")


func move_hero(x: float, y: float) -> void:
	if S.hero.ko > 0:
		return
	if S.hero.hold:
		say("Holding position. Press H to move again.")
		return
	S.pending_build = null
	S.hero.tx = clampf(x, 10, W - 10)
	S.hero.ty = clampf(y, 10, H - 10)


func handle_right(x: float, y: float) -> void:
	if S.paused or S.over:
		return
	if cancel_placing():
		return
	move_hero(x, y)


func handle_click(x: float, y: float, touch := false) -> void:
	var cell := cell_at(x, y)
	if S.user_pause and not S.over:
		S.sel = pick_tower(cell.x, cell.y)
		refresh("inspector")
		return
	if S.paused or S.over:
		return
	var t: Tower = tower_at(cell.x, cell.y) if S.build != "" else pick_tower(cell.x, cell.y)
	if S.merge_from != null:
		if t and t != S.merge_from:
			try_merge(S.merge_from, t)
		else:
			S.merge_from = null
			say("Merge cancelled.")
			refresh("inspector")
		return
	if S.strike_ready and S.build == "":
		S.pointer = Vector2(x, y)
		use_ability()
		return
	# the Wizard casts its readied runes at the cursor
	if S.hero.cls == "wizard" and S.runes.size() and S.build == "":
		cast_runes(x, y)
		return
	if t:
		S.sel = t
		S.build = ""
		S.pending_build = null
		refresh("build_bar")
		refresh("inspector")
		return
	if S.build != "":
		var why := build_problem(cell.x, cell.y, S.build)
		if why != "":
			say(why)
			return
		if in_build_range(cell.x, cell.y):
			place_tower(cell.x, cell.y, S.build)
			return
		var h := S.hero
		var cx := cell.x * C + C / 2
		var cy := cell.y * C + C / 2
		var d := maxf(0.01, hyp(h.x - cx, h.y - cy))
		var stop := h.build_range * 0.8
		if h.hold:
			say("Out of build range, and your hero is holding position (H).")
			return
		h.tx = cx + (h.x - cx) / d * stop
		h.ty = cy + (h.y - cy) / d * stop
		S.pending_build = { c = cell.x, r = cell.y, type = S.build }
		return
	if S.sel != null:
		S.sel = null
		refresh("inspector")
	if touch or S.hero.cls == "wizard":
		move_hero(x, y)


func select_build(k: String) -> void:
	if S.over or S.paused:
		return
	if S.build == k:
		S.build = ""
	elif S.gold >= tower_cost(k):
		S.build = k
		S.sel = null
		S.merge_from = null
	refresh("build_bar")
	refresh("inspector")


func toggle_pause() -> void:
	if S == null or S.hero == null or S.over:
		return
	S.user_pause = not S.user_pause
	S.paused = S.user_pause
	if S.user_pause:
		S.build = ""
		S.pending_build = null
		S.merge_from = null
		refresh("inspector")
	refresh("build_bar")


func sell_selected() -> void:
	if S.sel == null:
		return
	if S.user_pause:
		say("Paused. Press P to resume.")
		return
	sell(S.sel)


## Escape inside a run: unpause, drop readied runes, then clear the build or selection. Returns false when there was nothing to back out of.
func esc_step() -> bool:
	if S.user_pause:
		toggle_pause()
	elif S.runes.size():
		S.runes = []
		refresh("runes")
	elif S.build != "" or S.merge_from != null or S.sel != null or S.pending_build != null:
		S.build = ""
		S.merge_from = null
		S.sel = null
		S.pending_build = null
		refresh("build_bar")
		refresh("inspector")
	else:
		return false
	return true
