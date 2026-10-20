## Balance bot: plays Normal waves only and prints one CSV row per wave, to chart the difficulty curve.
## Run: godot --headless --path godot res://tests/balance_sim.tscn -- [map] [seeds] [lives]
## Env: SMART=1 (place towers on the most road, cheapest upgrade first), GOLD=3 (stand-in for a better player),
##      OVR="hp_growth_a=0.4;warden.hp=4500" (try numbers without editing data), DBG=1 (hero trace, waves 5-6)
## Env: HEROES=a,b  TOWERS=a,b,c  (same as sim.gd)
extends Node

var game: Game
var leaks := {}
var SMART := OS.get_environment("SMART") != ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "canal"
	var seeds: int = int(args[1]) if args.size() > 1 else 3
	var lives: int = int(args[2]) if args.size() > 2 else 0
	game = Game.new()
	add_child(game)
	game.modal.connect(_on_modal)
	# OVR="hp_growth_a=0.4;knight.hp=1800": try other numbers without editing the data files
	for kv in OS.get_environment("OVR").split(";", false):
		var p := kv.split("=")
		var path := p[0].split(".")
		if path.size() == 2:
			DB.enemies[path[0]].set(path[1], float(p[1]))
		else:
			game.R.set(path[0], float(p[1]) if "." in p[1] else int(p[1]))
	print("CSV,hero,seed,wave,enemies,wave_hp,leaked,lives,kills,gold_earned,bonus,bank,spent_total,tower_dmg,hero_dmg,secs,hero_lvl,towers,tower_lvls,kos")
	for hero in (OS.get_environment("HEROES").split(",") if OS.get_environment("HEROES") != "" else DB.hero_order):
		for s in seeds:
			seed(1000 + s)
			_run(hero, map_id, s, lives)
	for k in leaks:
		print("LEAK,", k, ",", leaks[k])
	print("SIM DONE")
	get_tree().quit()


func wave_hp(n: int) -> float:
	var total := 0.0
	var R := game.R
	for k in game.make_wave(n, { kind = "normal" }):
		var d: EnemyData = DB.enemies[k]
		var w := n - 1
		var sc: float = (1 + R.boss_hp_growth * maxi(0, n - 5)) if d.boss else (1 + R.hp_growth_a * w + R.hp_growth_b * w * w)
		total += d.hp * sc * game.S.mod_enemy_hp * R.enemy_hp_mult * (1 + d.split * 0.5)
	return total


func _run(hero: String, map_id: String, s: int, lives: int) -> void:
	game.new_run(map_id)
	var towers := Array(OS.get_environment("TOWERS").split(",")) if OS.get_environment("TOWERS") != "" else Array(DB.tower_order).slice(0, 5)
	game.start_run(hero, towers)
	var S := game.S
	if lives > 0:
		S.lives = lives
	# GOLD=k: a stand-in for a better player, every gold source is multiplied by k
	var gk := float(OS.get_environment("GOLD")) if OS.get_environment("GOLD") != "" else 1.0
	S.mod_gold *= gk
	S.gold *= gk
	var mid := S.map.pos_at(S.map.path_len * 0.45)
	S.hero.x = mid.x
	S.hero.y = mid.y
	var steps := 0
	var wave_steps := 0
	var spent := 0.0
	var last_gold := S.gold
	var cur_hp := 0.0
	var logged := 0
	while not S.over and steps < 2000000:
		steps += 1
		wave_steps += 1
		if wave_steps > 30 * 600:
			print("STALL wave ", S.wave)
			break
		if not S.wave_active and not S.paused:
			var g0 := S.gold
			_spend()
			spent += maxf(0, g0 - S.gold)
			cur_hp = wave_hp(S.wave + 1)
			game.start_wave()
			wave_steps = 0
		# walk back to the post after a knockout respawn
		if steps % 30 == 0 and S.hero.ko <= 0 and Vector2(S.hero.x, S.hero.y).distance_to(mid) > 20:
			S.hero.tx = mid.x
			S.hero.ty = mid.y
		if S.wave_active and steps % 20 == 0:
			var g1 := S.gold
			_spend()
			spent += maxf(0, g1 - S.gold)
		if S.hero.data.spells and steps % 15 == 0:
			_cast()
		elif steps % 60 == 0 and S.hero.ab.t <= 0:
			game.use_ability()
		if OS.get_environment("DBG") != "" and steps % 150 == 0 and S.wave_active and S.wave >= 5 and S.wave <= 6:
			var inr := game.in_range(S.hero.x, S.hero.y, S.hero.range)
			print("DBG w%d t %.0f hero %.0f,%.0f hp %.0f/%.0f ko %.1f near %d enemies %d blocked %d" % [S.wave, S.time, S.hero.x, S.hero.y, S.hero.hp, S.hero.max_hp, S.hero.ko, inr.size(), S.enemies.size(), S.enemies.filter(func(e): return e.blocked).size()])
		var alive := S.enemies.filter(func(e): return not e.dead)
		game.update(1.0 / 30)
		for e in alive:
			if e.dead and e.d >= S.map.path_len:
				var key := "%d,%s" % [S.wave, e.type]
				leaks[key] = leaks.get(key, 0) + e.data.lives
		while S.log.size() > logged:
			var w: Dictionary = S.log[logged]
			logged += 1
			S.gold += (gk - 1) * (game.R.wave_gold_base + game.R.wave_gold_per_wave * w.wave)
			var lvls := ";".join(S.towers.map(func(t): return t.type + str(t.lvl)))
			print("CSV,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s" % [hero, s, w.wave, w.enemies, int(cur_hp), w.lives_lost, S.lives, w.kills, w.gold,
				25 + 5 * w.wave, int(S.gold), int(spent), w.get("tower_dmg", 0), w.hero_dmg, w.get("seconds", 0), S.hero.lvl, S.towers.size(), lvls + "," + str(w.hero_kos)])
	print("END,%s,%d,wave %d,%s,lives %d" % [hero, s, S.wave, "over" if S.over else "cap", S.lives])


func _cast() -> void:
	var lead := game.lead_enemy()
	if lead == null:
		return
	var keys := game.S.rune_keys.keys()
	game.ready_rune(keys[randi() % keys.size()])
	if randf() < 0.5:
		game.ready_rune(keys[randi() % keys.size()])
	var at := lead.pos()
	game.cast_runes(at.x, at.y)


## Same spending as sim.gd, but greedy (always buys when it can) so runs are less noisy.
func _spend() -> void:
	var S := game.S
	for t in S.towers:
		if t.lvl >= game.R.max_level:
			continue
		var opts := game.tower_options(t).filter(func(o): return game.path_state(t, o) == "open")
		if opts.is_empty():
			continue
		var o: Dictionary = opts[randi() % opts.size()]
		if SMART:
			opts.sort_custom(func(a, b): return game.level_cost(t, a) < game.level_cost(t, b))
			o = opts[0]
		if S.gold >= game.level_cost(t, o):
			game.level_tower(t, o)
	var done := S.towers.filter(func(t): return t.lvl >= game.R.max_level and not t.is_super)
	for a in done:
		for b in done:
			if a != b and game.merge_problem(a, b) == "" and S.gold >= game.merge_cost(a) and S.towers.has(a) and S.towers.has(b):
				game.try_merge(a, b)
				return
	if S.towers.size() < 14:
		var type: String = S.loadout[randi() % S.loadout.size()]
		if S.gold >= game.tower_cost(type):
			var cells := []
			for cell in S.map.path_cells:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
					var c: Vector2i = cell + d
					if game.build_problem(c.x, c.y, type) == "":
						cells.append(c)
			var near := cells.filter(func(c): return game.in_build_range(c.x, c.y))
			if near.size():
				# SMART: pick the spot that covers the most road
				var best: Vector2i = near[0]
				var best_n := -1
				var rng: float = DB.towers[type].range
				for c in near:
					var cnt := 0
					var cp := Vector2(c.x * 40.0 + 20, c.y * 40.0 + 20)
					for pc in S.map.path_cells:
						if cp.distance_to(Vector2(pc.x * 40.0 + 20, pc.y * 40.0 + 20)) <= rng:
							cnt += 1
					if cnt > best_n:
						best_n = cnt
						best = c
				var c: Vector2i = best if SMART else near[randi() % near.size()]
				game.place_tower(c.x, c.y, type)


func _on_modal(kind: String, data: Dictionary) -> void:
	match kind:
		"level_up":
			game.pick_offer(randi() % data.offers.size())
		"wave_choice":
			game.choose_mode(0)
		"shop":
			game.leave_shop()
		"heroic":
			game.pick_heroic(data.fresh[0] if data.fresh.size() else data.owned[0])
		"boon":
			game.take_boon()
