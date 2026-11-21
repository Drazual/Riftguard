## Playtest bot: plays whole runs with one hero, loadout and strategy, and prints per-wave rows and a summary.
## Run: godot --headless --path godot res://tests/playtest_bot.tscn -- <map> <hero> <strategy> <towers,comma> [seeds]
## VET=0.5 in the environment: play as a returning player with half of every menu upgrade bought.
## Strategies:
##   balanced  mixed loadout, builds while a tower is not much dearer than an upgrade, Normal waves
##   towers    tower-heavy: builds up to the cap first, picks tower perks (aura, range, cheaper levels)
##   hero      hero-carry: at most 3 towers, picks hero damage perks, buys hero items in the boss shop
##   spam      one tower type only (pass a single tower), builds as many as it can
##   greedy    economy: takes Hard waves for the gold (Normal on boss waves), buys Bounty Contract, saves a reserve
## Placement: the spot that covers the most road. Between waves the hero may walk anywhere to build.
## Upgrades: focus one path at a time to its mastery, then the next (a sensible human build).
extends Node

var game: Game
var strat := "balanced"
var leaks := {}
var won := false
var rng := RandomNumberGenerator.new()
var ended := false
var wavepick := OS.get_environment("WAVEPICK") # "challenge": take Challenge, Legendary or Secret waves whenever offered (not on boss waves)
var toasts := {}
var cur_mode := ""
var modes := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var map_id: String = a[0]
	var hero: String = a[1]
	strat = a[2]
	var towers := Array(a[3].split(","))
	var seeds: int = int(a[4]) if a.size() > 4 else 3
	game = Game.new()
	add_child(game)
	game.modal.connect(_on_modal)
	game.toast.connect(func(m: String):
		for k in ["challenge failed", "Quest accepted", "Quest failed", "quest complete", "flag bearer", "break through"]:
			if k in m:
				toasts[k] = toasts.get(k, 0) + 1)
	for s in range(int(OS.get_environment("SEED0")) if OS.get_environment("SEED0") != "" else 0, seeds):
		seed(2000 + s)
		rng.seed = 2000 + s
		_run(map_id, hero, towers, s)
	print("BOT DONE")
	get_tree().quit()


func _run(map_id: String, hero: String, towers: Array, s: int) -> void:
	leaks = {}
	toasts = {}
	modes = {}
	won = false
	ended = false
	# every run starts from a fresh save: no menu upgrades, mastery perks or map wins carried over from earlier runs
	Save.meta = Save.default_meta()
	Save._fill()
	# VET=0.5: a returning player who has bought half of every menu upgrade (all-hero, all-tower and this hero's)
	var vet := float(OS.get_environment("VET")) if OS.get_environment("VET") != "" else 0.0
	if vet > 0:
		for u: UpgradeData in game.R.global_meta.items:
			Save.meta.global[u.id] = roundi(u.max_rank * vet)
		for u: UpgradeData in game.R.tower_global.items:
			Save.meta.tower_global[u.id] = roundi(u.max_rank * vet)
		for u: UpgradeData in DB.heroes[hero].meta:
			Save.hero_meta(hero)[u.id] = roundi(u.max_rank * vet)
	game.new_run(map_id)
	game.start_run(hero, towers)
	var S := game.S
	var post := S.map.pos_at(S.map.path_len * 0.5)
	S.hero.x = post.x
	S.hero.y = post.y
	var steps := 0
	var wave_steps := 0
	var logged := 0
	var hero_total := 0.0
	var tower_total := 0.0
	var gold_total := float(S.gold)
	var first_leak := 0
	var lost_by := {}
	var dmg_by := {} # tower type -> damage, kept across merges/sells
	while not S.over and steps < 3000000:
		steps += 1
		wave_steps += 1
		if wave_steps > 30 * 900:
			print("STALL ", map_id, " wave ", S.wave, " seed ", s, " enemies ", S.enemies.size(), " queue ", S.spawn_q.size(), " paused ", S.paused, " pend ", S.pending_levels, " heroic ", S.pending_heroic, " boon ", S.pending_boon, " shop ", S.need_shop, " choice ", S.need_choice, " speed ", S.speed, " active ", S.wave_active)
			var e0: Enemy = S.enemies[0] if S.enemies.size() else null
			var t0 := S.time
			var d0 := e0.d if e0 else 0.0
			var back_sum := 0.0
			var back_n := 0
			for _i in 9000:
				var ds := {}
				for e in S.enemies:
					ds[e] = e.d
				game.update(1.0 / 30)
				for e in S.enemies:
					if ds.has(e) and e.d < ds[e] - 0.01:
						back_sum += ds[e] - e.d
						back_n += 1
				if _i % 900 == 0:
					var mind := 99999.0
					var maxd := 0.0
					for e in S.enemies:
						mind = minf(mind, e.d)
						maxd = maxf(maxd, e.d)
					print("  T+%ds enemies %d d %.0f..%.0f back %.0f in %d frames, hero ab_t %.1f cd %.1f, active %s lives %d" % [_i / 30, S.enemies.size(), mind, maxd, back_sum, back_n, S.hero.ab.t, S.hero.ab.cd, S.wave_active, S.lives])
					back_sum = 0.0
					back_n = 0
			print("  after 30 frames: time %.2f -> %.2f, first d %.1f -> %.1f, over %s" % [t0, S.time, d0, e0.d if e0 else 0.0, S.over])
			for e in S.enemies:
				print("  STUCK %s d %.0f/%.0f lane %d hp %.0f/%.0f dead %s blocked %s stun %.1f slow %.2f speed %.0f pos %.0f,%.0f hero %.0f,%.0f ko %.1f taunt %.1f push %.1f pull %.1f walls %d still %.1f" % [e.type, e.d, S.map.path_len, e.lane, e.hp, e.max, e.dead, e.blocked, e.stun_t, e.slow, e.speed, e.x, e.y, S.hero.x, S.hero.y, S.hero.ko, e.taunt_t, e.push_t, e.pull_t, S.walls.size(), e.still_t])
			break
		if not S.wave_active and not S.paused:
			_spend(true, post)
			game.start_wave()
			wave_steps = 0
			var md: Dictionary = S.mode
			cur_mode = "%s[%s]" % [md.get("kind", "normal"), "+".join(md.get("tough", []) + md.get("debuffs", []) + ([md.req] if md.get("req", "") != "" else []))]
			modes[md.get("kind", "normal")] = modes.get(md.get("kind", "normal"), 0) + 1
		if steps % 30 == 0 and S.hero.ko <= 0 and S.quest_drop != null:
			S.hero.tx = S.quest_drop.x # walk over a dropped quest to pick it up
			S.hero.ty = S.quest_drop.y
		elif steps % 30 == 0 and S.hero.ko <= 0 and Vector2(S.hero.x, S.hero.y).distance_to(post) > 20:
			S.hero.tx = post.x
			S.hero.ty = post.y
		if S.wave_active and steps % 20 == 0:
			_spend(false, post)
		if S.hero.data.spells and steps % 15 == 0:
			_cast()
		elif steps % 30 == 0 and S.hero.ab.t <= 0 and S.wave_active and S.enemies.size() > 0:
			game.use_ability()
		if OS.get_environment("TRACEW") != "" and S.wave == int(OS.get_environment("TRACEW")) and S.wave_active and wave_steps % 900 == 0:
			var mind := 99999.0
			var maxd := 0.0
			var nb := 0
			for e in S.enemies:
				mind = minf(mind, e.d)
				maxd = maxf(maxd, e.d)
				if e.blocked or e.taunt_t > 0 or e.stun_t > 0:
					nb += 1
			print("  TR t=%ds enemies %d queue %d d %.0f..%.0f held %d hero %.0f,%.0f hp %.0f ko %.1f" % [wave_steps / 30, S.enemies.size(), S.spawn_q.size(), mind, maxd, nb, S.hero.x, S.hero.y, S.hero.hp, S.hero.ko])
		var alive := S.enemies.filter(func(e): return not e.dead)
		var before := {}
		for t in S.towers:
			before[t] = t.dmg_total
		game.update(1.0 / 30)
		for t in S.towers:
			var k: String = t.type
			dmg_by[k] = dmg_by.get(k, 0.0) + t.dmg_total - before.get(t, 0.0)
		for e in alive:
			if e.dead and e.d >= S.map.path_len:
				var key := "%d:%s" % [S.wave, e.type]
				leaks[key] = leaks.get(key, 0) + e.data.lives
		while S.log.size() > logged:
			var w: Dictionary = S.log[logged]
			logged += 1
			hero_total += w.hero_dmg
			tower_total += w.get("tower_dmg", 0)
			gold_total += w.gold + 25 + 5 * w.wave
			if w.lives_lost > 0:
				if first_leak == 0:
					first_leak = w.wave
				lost_by[w.wave] = w.lives_lost
			print("MODE|%s|%s|%s|%d|%d|%s|%d|%d" % [map_id, hero, strat + ("+" + wavepick if wavepick else ""), s, w.wave, cur_mode, w.lives_lost, 1 if S.over and not won else 0])
			print("WAVE,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d" % [map_id, hero, strat, s, w.wave, w.lives_lost, S.lives, int(w.get("tower_dmg", 0)), int(w.hero_dmg), int(S.gold), S.hero.lvl, S.towers.size(), int(w.get("seconds", 0))])
	var lvls := " ".join(S.towers.map(func(t): return game.tower_name(t).replace(" ", "_") + str(t.lvl)))
	var dmg := ";".join(dmg_by.keys().map(func(k): return "%s=%d" % [k, int(dmg_by[k])]))
	var lk := ";".join(leaks.keys().map(func(k): return "%s=%d" % [k, leaks[k]]))
	var lost := ";".join(lost_by.keys().map(func(k): return "w%d=%d" % [k, lost_by[k]]))
	var tst := ";".join(toasts.keys().map(func(k): return "%s=%d" % [k, toasts[k]]))
	var mds := ";".join(modes.keys().map(func(k): return "%s=%d" % [k, modes[k]]))
	print("RUN|%s|%s|%s|%s|%d|%d|%d|%s|%d|%d|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s" % [map_id, hero, strat, ",".join(towers), s, S.wave, game.max_wave,
		"WIN" if won else "LOSS", S.lives, int(tower_total), int(hero_total), int(gold_total), S.hero.lvl, first_leak, lost, dmg, lk, lvls, mds, tst])


func _cast() -> void:
	var lead := game.lead_enemy()
	if lead == null:
		return
	var keys := game.S.rune_keys.keys()
	game.ready_rune(keys[randi() % keys.size()])
	if randf() < 0.5:
		game.ready_rune(keys[randi() % keys.size()])
	var h: Hero = game.S.hero
	var reach := game.hero_range(h)
	var at := lead.pos()
	if at.distance_to(h.pos()) > reach:
		var near := game.S.enemies.filter(func(e): return not e.dead and e.pos().distance_to(h.pos()) <= reach)
		if near.is_empty():
			return
		near.sort_custom(func(x, y): return x.d > y.d)
		at = near[0].pos()
	game.cast_runes(at.x, at.y)


func cap() -> int:
	match strat:
		"hero":
			return 3
		"towers", "spam":
			return 14
	return 12


## The level-up a human would take: keep pushing the path with the most points until it is maxed.
func best_up(t: Tower):
	var opts := game.tower_options(t).filter(func(o): return game.path_state(t, o) == "open")
	if opts.is_empty():
		return null
	opts.sort_custom(func(x, y): return t.ups_of(x.id) > t.ups_of(y.id))
	if t.ups_of(opts[0].id) == 0:
		return opts[rng.randi() % opts.size()]
	return opts[0]


func _spend(between: bool, post: Vector2) -> void:
	var S := game.S
	# merge two maxed towers when possible
	var done := S.towers.filter(func(t): return t.lvl >= game.R.max_level and not t.is_super)
	for x in done:
		for y in done:
			if x != y and game.merge_problem(x, y) == "" and S.gold >= game.merge_cost(x) and S.towers.has(x) and S.towers.has(y):
				game.try_merge(x, y)
				return
	var reserve := 0.0
	if strat == "greedy":
		reserve = 0.0 if S.wave < 3 else 40.0 + 6.0 * S.wave
	for i in 30:
		var up_t: Tower = null
		var up_o = null
		var up_c := INF
		for t in S.towers:
			if t.lvl >= game.R.max_level:
				continue
			var o = best_up(t)
			if o == null:
				continue
			var c := float(game.level_cost(t, o))
			if c < up_c:
				up_c = c
				up_t = t
				up_o = o
		var type := _next_type()
		var tc := float(game.tower_cost(type)) if type != "" else INF
		var k: float = { "balanced": 1.3, "towers": 4.0, "spam": 4.0, "hero": 99.0, "greedy": 1.0 }.get(strat, 1.3)
		var want_tower: bool = S.towers.size() < cap() and (S.towers.size() < 2 or tc <= up_c * k)
		if want_tower and S.gold - reserve >= tc:
			if not _build(type, between, post):
				want_tower = false
				if up_t == null:
					return
			else:
				continue
		if want_tower and S.gold - reserve < tc:
			return # saving up for the tower
		if up_t != null and S.gold - reserve >= up_c:
			game.level_tower(up_t, up_o)
		else:
			return


func _next_type() -> String:
	var S := game.S
	var best := ""
	var n := 999
	for k in S.loadout:
		var c := game.count_type(k)
		if c < n:
			n = c
			best = k
	return best


func _build(type: String, between: bool, post: Vector2) -> bool:
	var S := game.S
	var cells := []
	if game.has_pads() or game.free_build():
		for c in game.build_cells():
			if game.build_problem(c.x, c.y, type) == "":
				cells.append(c)
	else:
		var seen := {}
		for cell in S.map.path_cells:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var c: Vector2i = cell + d
				if not seen.has(c) and game.build_problem(c.x, c.y, type) == "":
					seen[c] = true
					cells.append(c)
	if not between:
		cells = cells.filter(func(c): return game.in_build_range(c.x, c.y))
	if cells.is_empty():
		return false
	var rngv: float = DB.towers[type].range
	if DB.towers[type].support:
		rngv = 120.0
	var best: Vector2i = cells[0]
	var best_n := -1.0
	for c in cells:
		var cp := game.cell_pos(c.x, c.y)
		var cnt := 0.0
		var d := 0.0
		while d < S.map.path_len:
			if cp.distance_to(game.pos_at(d)) <= rngv:
				cnt += 1
			d += 20.0
		# support towers: count nearby towers instead
		if DB.towers[type].support or type == "shrine":
			cnt = 0.0
			for t in S.towers:
				if cp.distance_to(game.cell_pos(t.c, t.r)) <= 120:
					cnt += 3
			if type == "shrine":
				cnt = -cp.distance_to(post)
		if cnt > best_n:
			best_n = cnt
			best = c
	var n0 := S.towers.size()
	if between:
		var hx := S.hero.x
		var hy := S.hero.y
		var cp := game.cell_pos(best.x, best.y)
		S.hero.x = cp.x
		S.hero.y = cp.y + 30
		game.place_tower(best.x, best.y, type)
		S.hero.x = hx
		S.hero.y = hy
	else:
		game.place_tower(best.x, best.y, type)
	return S.towers.size() > n0


func _score_offer(o: Dictionary) -> float:
	var sc: float = 10.0 * float(game.R.rarity_names.find(o.rarity.name) if o.has("rarity") else 0)
	var eff: String = o.perk.effect if o.has("perk") and o.perk else ""
	if o.get("demonic", false):
		sc -= 15
	match strat:
		"hero":
			for kw in ["h.dmg", "h.rate", "h.crit", "h.ab.dmg", "h.ab.mult", "h.spell", "h.bounce", "h.pierce", "h.armor_pen", "h.headhunter"]:
				if kw in eff:
					sc += 20
		"towers", "spam":
			for kw in ["h.aura", "h.tower_range", "h.lvl_mul", "h.rapid", "aura_slow"]:
				if kw in eff:
					sc += 20
		"greedy":
			for kw in ["h.lvl_mul", "h.bounty", "h.interest", "h.siphon"]:
				if kw in eff:
					sc += 20
	return sc + rng.randf()


func _on_modal(kind: String, data: Dictionary) -> void:
	match kind:
		"level_up":
			var best := 0
			var bs := -INF
			for i in data.offers.size():
				var v := _score_offer(data.offers[i])
				if v > bs:
					bs = v
					best = i
			game.pick_offer(best)
		"wave_choice":
			var pick := 0
			var hardline: bool = game.S.quest != null and game.S.quest.id == "hardline"
			if wavepick == "challenge" and not data.boss:
				for i in data.opts.size():
					if data.opts[i].kind in ["challenge", "legendary", "secret"]:
						pick = i
			elif (strat == "greedy" or hardline) and not data.boss:
				for i in data.opts.size():
					if data.opts[i].kind == "hard":
						pick = i
			game.choose_mode(pick)
		"shop":
			var want: Array = { "hero": ["riftblade", "soul", "chrono", "titan", "breaker"], "greedy": ["contract", "primer", "conduit", "breaker"] }.get(strat, ["conduit", "primer", "breaker", "hyper", "soul"])
			for id in want:
				for i in game.shop_items.size():
					var x: Dictionary = game.shop_items[i]
					if x.it.id == id and not x.sold and not x.dem and game.S.gold >= game.shop_price(x) * 1.5:
						game.buy(i)
			game.leave_shop()
		"heroic":
			game.pick_heroic(data.fresh[0] if data.fresh.size() else data.owned[0])
		"boon":
			game.take_boon()
		"secret":
			game.S.paused = false
		"quest":
			# take the quests a bot can keep; turn down the ones that forbid what it always does (build, level, spend, cast)
			game.answer_quest(data.id in ["flawless", "standing", "hoarder", "hardline"])
		"lone_pick", "enemy_intro":
			pass
		"end":
			won = data.won
			ended = true
