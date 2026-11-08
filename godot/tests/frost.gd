## Screenshots of the Frost Pylon turret charging its ice orb and firing in a run. Needs a display:
## xvfb-run godot --path godot --rendering-driver opengl3 res://tests/frost.tscn -- <out dir>
extends Node

var out := "user://frost"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(120).timeout.connect(func(): print("LASER TIMEOUT"); get_tree().quit(1))
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
	# frost pylons, with an Arcane Bolt and a Plasma Cannon beside them to compare sizes
	var kinds := ["frost", "arcane", "frost", "plasma", "frost"]
	var placed := 0
	for c in cells:
		if placed < kinds.size() and g.build_problem(c.x, c.y, kinds[placed]) == "":
			g.place_tower(c.x, c.y, kinds[placed])
			placed += 1
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	await _shot("00_placed", main, S)
	g.start_wave()
	for n in 3:
		# keep enemies walking past every tower, so each turret turns and fires
		S.hero.x = -500
		S.lives = 999
		if not S.wave_active:
			g.start_wave()
		for k in 8:
			g.spawn("brute", S.map.path_len * k / 8.0)
		for i in 60:
			await get_tree().process_frame
		print("frost shots: ", S.towers.map(func(t): return t.shots), " enemies ", S.enemies.size(), " orbs ", S.proj.size())
		# a frame every 0.1s through a whole charge-and-fire cycle
		for k in 10:
			await _shot("%02d_wave_%d" % [n + 1, k], main, S, 5)
			print("  %02d_wave_%d turrets: " % [n + 1, k], S.towers.filter(func(t): return t.type == "frost").map(func(t):
				var v: Node2D = t.get_meta("view")
				# a baked turret sprite (the old look), or the live model (the unified style)
				var clip: String = v.animation if v is AnimatedSprite2D else v.ap.current_animation
				var f: int = v.frame if v is AnimatedSprite2D else int(v.ap.current_animation_position * 10)
				return "%s:%d @%d,%d" % [clip, f, v.global_position.x, v.global_position.y]))
	get_tree().quit()


func _shot(name: String, _main: Main, _S, wait := 4) -> void:
	for i in wait:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
