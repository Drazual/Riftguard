## Screenshots of the Razor Disc rendered from 3D throwing its saw, and of the Sniper aiming Piercing Shot (its exact
## path and who it would hit); checks the Sniper never targets enemies outside the visible map. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/saw_sniper.tscn -- <out dir>
extends Node

var out := "user://saw_sniper"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(90).timeout.connect(func(): print("SAW TIMEOUT"); get_tree().quit(1))
	seed(3)
	Save.meta.secret_heroes = {}
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("sniper", ["disc", "plasma", "laser", "frost", "tesla", "mortar"])
	for i in 10:
		await get_tree().process_frame
	var g := main.game
	var S := g.S
	S.gold = 5000
	var cells := g.build_cells()
	var dist := {}
	for c in cells:
		dist[c] = S.map.path_dist(g.cell_pos(c.x, c.y))
	cells.sort_custom(func(a, b): return dist[a] < dist[b])
	var placed := 0
	for c in cells:
		if placed < 3 and g.build_problem(c.x, c.y, "disc") == "":
			g.place_tower(c.x, c.y, "disc")
			placed += 1
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	S.lives = 999
	g.start_wave()
	for k in 10:
		g.spawn("brute", S.map.path_len * (0.25 + k * 0.06))
	# an enemy at the very start of the path, off the edge of the map
	g.spawn("brute", 1.0)
	var off: Enemy = S.enemies[S.enemies.size() - 1]
	print("off-map enemy at ", off.pos(), " in view ", g.in_view(off))
	assert(not g.in_view(off))
	var off_hp := off.hp
	for i in 90:
		await get_tree().process_frame
	print("off-map enemy hp ", off_hp, " -> ", off.hp, " (", "FAIL: hit" if off.hp < off_hp else "untouched", ")")
	for k in 4:
		await _shot("0%d_discs" % k, 3)
	print("discs in flight ", S.discs.size(), " disc shots ", S.towers.map(func(t): return t.shots))
	# Piercing Shot: aim at the middle of the enemies, show the band, then fire
	S.hero.ab.t = 0
	var live := S.enemies.filter(func(e): return not e.dead and g.in_view(e))
	var goal: Vector2 = live[live.size() / 2].pos()
	S.pointer = goal
	print("aim start ", g.pierce_aim_start(), " aiming ", S.pierce_aiming, " would hit ", g.pierce_line(S.hero, S.hero.ab, goal).size())
	S.paused = true
	await _shot("10_aim", 4)
	var hp := S.hero.pos()
	var u := (goal - hp).normalized()
	print("band half-width ", S.hero.ab.w, " rail ", S.hero.ab.rail)
	for e in g.pierce_line(S.hero, S.hero.ab, goal):
		print("  hit ", e.pos(), " off ", absf((e.x - hp.x) * u.y - (e.y - hp.y) * u.x), " r ", e.r)
	S.paused = false
	g.pierce_aim_fire()
	print("fired: aiming ", S.pierce_aiming, " cooldown ", S.hero.ab.t)
	await _shot("11_fired", 3)
	get_tree().quit()


func _shot(name: String, wait := 4) -> void:
	for i in wait:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
