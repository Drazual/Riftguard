## Screenshots of the Siege Mortar rendered from 3D turning toward enemies and lobbing shells from its barrel, next to
## a Plasma Cannon for size. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/mortar.tscn -- <out dir>
extends Node

var out := "user://mortar"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(120).timeout.connect(func(): print("MORTAR TIMEOUT"); get_tree().quit(1))
	seed(7)
	Save.meta.secret_heroes = {}
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	var main: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("vanguard", ["arcane", "plasma", "laser", "frost", "tesla", "mortar"])
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
		var k := "plasma" if placed == 1 else "mortar"
		if placed < 4 and g.build_problem(c.x, c.y, k) == "":
			g.place_tower(c.x, c.y, k)
			placed += 1
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	await _shot("00_placed", main, S)
	g.start_wave()
	for n in 6:
		# keep enemies walking past every tower, so each turret turns and fires
		S.hero.x = -500
		S.lives = 999
		if not S.wave_active:
			g.start_wave()
		for k in 8:
			g.spawn("brute", S.map.path_len * k / 8.0)
		for i in 60:
			await get_tree().process_frame
		print("mortar shots: ", S.towers.map(func(t): return t.shots), " enemies ", S.enemies.size(), " shells ", S.shells.size())
		# wait for shells in flight, then a few quick frames of them
		for i in 120:
			if S.shells.any(func(p): return p.wait <= 0 and not p.done):
				break
			await get_tree().process_frame
		for k in 6:
			await _shot("%02d_wave_%d" % [n + 1, k], main, S, 1)
	get_tree().quit()


func _shot(name: String, _main: Main, _S, wait := 4) -> void:
	for i in wait:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
