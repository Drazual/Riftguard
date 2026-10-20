## Headless bot: plays whole runs with every hero to catch script errors and check the balance stays sane.
## Run: godot --headless --path godot res://tests/sim.tscn -- [map] [runs]
extends Node

var game: Game
var result := {}
var log_lines := []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id: String = args[0] if args.size() > 0 else "verdant"
	var max_waves: int = int(args[1]) if args.size() > 1 else 99
	seed(12345)
	get_tree().create_timer(80).timeout.connect(func(): print("SIM TIMEOUT"); get_tree().quit(1))
	game = Game.new()
	add_child(game)
	game.modal.connect(_on_modal)
	var t0 := Time.get_ticks_msec()
	for hero in (OS.get_environment("HEROES").split(",") if OS.get_environment("HEROES") != "" else DB.hero_order):
		_run(hero, map_id, max_waves)
	print("SIM DONE in %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()


func _run(hero: String, map_id: String, max_waves: int) -> void:
	result = {}
	game.new_run(map_id)
	var towers := Array(DB.tower_order).slice(0, 5)
	game.start_run(hero, towers)
	var S := game.S
	# stand near the middle of the path so the towers cover most of it
	var mid := S.map.pos_at(S.map.path_len * 0.45)
	S.hero.x = mid.x
	S.hero.y = mid.y
	var steps := 0
	var wave_steps := 0
	while not S.over and steps < 400000 and S.wave <= max_waves:
		steps += 1
		wave_steps += 1
		# a wave the bot can stall forever (say, pushing everything back to the entrance) ends the run
		if wave_steps > 30 * 600:
			print("STALL: wave %d still running after 600s with %d enemies" % [S.wave, S.enemies.size()])
			break
		if not S.wave_active and not S.paused:
			_spend()
			game.start_wave()
			wave_steps = 0
		if S.wave_active and steps % 20 == 0:
			_spend()
		if S.hero.data.spells and steps % 15 == 0:
			_cast()
		elif steps % 60 == 0 and S.hero.ab.t <= 0:
			game.use_ability()
		game.update(1.0 / 30)
		if OS.get_environment("DBG") != "" and steps % 150 == 0 and S.wave_active:
			var inr := game.in_range(S.hero.x, S.hero.y, S.hero.range)
			print("t %.1f hero %.0f,%.0f hp %.0f ko %.1f cd %.2f range %.0f near %d enemies %d paused %s" % [S.time, S.hero.x, S.hero.y, S.hero.hp, S.hero.ko, S.hero.cd, S.hero.range, inr.size(), S.enemies.size(), S.paused])
			if S.enemies.size() == 1:
				var e: Enemy = S.enemies[0]
				print("  last: %s d %.0f/%.0f x %.0f y %.0f hp %.0f stun %.1f slow %.2f push %.1f blocked %s dead %s speed %.0f" % [e.type, e.d, S.map.path_len, e.x, e.y, e.hp, e.stun_t, e.slow, e.push_t, e.blocked, e.dead, e.speed])
	var tw := S.towers.map(func(t): return game.tower_name(t) + " L" + str(t.lvl))
	print("kills hero %d towers %s leaks? log %s" % [S.kills.hero, str(S.kills.towers), str(S.log.map(func(w): return w.lives_lost))])
	print("%s on %s: wave %d %s lives %d gold %d lvl %d towers %d steps %d | %s" % [hero, map_id, S.wave, "WON" if result.get("won", false) else "lost", S.lives,
		S.gold, S.hero.lvl, S.towers.size(), steps, ", ".join(tw.slice(0, 6))])


func _cast() -> void:
	var S := game.S
	var lead := game.lead_enemy()
	if lead == null:
		return
	var keys := S.rune_keys.keys()
	game.ready_rune(keys[randi() % keys.size()])
	if randf() < 0.5:
		game.ready_rune(keys[randi() % keys.size()])
	var at := lead.pos()
	game.cast_runes(at.x, at.y)


func _spend() -> void:
	var S := game.S
	var h := S.hero
	# level up towers first
	for t in S.towers:
		if t.lvl >= game.R.max_level:
			continue
		var opts := game.tower_options(t).filter(func(o): return game.path_state(t, o) == "open")
		if opts.is_empty():
			continue
		var o: Dictionary = opts[randi() % opts.size()]
		if S.gold >= game.level_cost(t, o) and randf() < 0.7:
			game.level_tower(t, o)
	# merge maxed towers
	var done := S.towers.filter(func(t): return t.lvl >= game.R.max_level and not t.is_super)
	for a in done:
		for b in done:
			if a != b and game.merge_problem(a, b) == "" and S.gold >= game.merge_cost(a) and S.towers.has(a) and S.towers.has(b):
				game.try_merge(a, b)
				return
	# build near the path within reach
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
				var c: Vector2i = near[randi() % near.size()]
				game.place_tower(c.x, c.y, type)
			elif cells.size() and not h.hold and false:
				var c: Vector2i = cells[randi() % cells.size()]
				h.tx = c.x * 40.0 + 20
				h.ty = c.y * 40.0 + 20


func _on_modal(kind: String, data: Dictionary) -> void:
	match kind:
		"level_up":
			game.pick_offer(randi() % data.offers.size())
		"wave_choice":
			game.choose_mode(randi() % data.opts.size())
		"shop":
			for i in game.shop_items.size():
				var x: Dictionary = game.shop_items[i]
				if not x.sold and game.S.gold >= game.shop_price(x) and randf() < 0.5:
					game.buy(i)
					return
			game.leave_shop()
		"heroic":
			game.pick_heroic(data.fresh[0] if data.fresh.size() else data.owned[0])
		"boon":
			game.take_boon()
		"end":
			result = data
