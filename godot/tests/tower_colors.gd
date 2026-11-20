## Path colours on the base towers: every base tower placed, then 3 paths bought one by one, with a crop after each
## buy. Each buy should recolour one more accent zone; an unbought tower looks as before.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/tower_colors.tscn -- <out dir>
extends Node

var out := "user://tower_colors"
var fails := 0
var main: Main


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _crop(name: String, at: Vector2, half: Vector2, z: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var b := main.board
	var bi := b.viewport.get_texture().get_image()
	var c: Vector2 = b.viewport.canvas_transform * (b.world.transform * at)
	var r := Rect2i(Vector2i(c - half), Vector2i(half * 2)).intersection(Rect2i(Vector2i.ZERO, bi.get_size()))
	var img := bi.get_region(r)
	img.resize(img.get_width() * z, img.get_height() * z, Image.INTERPOLATE_LANCZOS)
	img.save_png(out.path_join(name + ".png"))


func _max(g: Game, t: Tower) -> void:
	var guard := 0
	while t.lvl < g.R.max_level and guard < 20:
		var picked = null
		for o in g.tower_options(t):
			if g.path_state(t, o) == "open":
				picked = o
				break
		if picked == null:
			break
		g.level_tower(t, picked)
		guard += 1


func _unblock(g: Game) -> void:
	for i in 30:
		main.ui.close_modal()
		if g.S.pending_boon != "":
			g.take_boon()
		if g.S.paused and g.wave_opts.size() > 0:
			g.choose_mode(0)
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(300).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.start_test_room()
	await _frames(10)
	var g := main.game
	var S := g.S
	var cells: Array = g.build_cells()
	var n := 0
	for type in DB.tower_order:
		var best := Vector2i(-1, -1)
		for k in range(n * 37 % cells.size(), cells.size()):
			var c: Vector2i = cells[k]
			if g.build_problem(c.x, c.y, type) == "":
				best = c
				break
		n += 1
		if best.x < 0:
			continue
		g.place_tower(best.x, best.y, type)
		var t: Tower = S.towers[S.towers.size() - 1]
		await _frames(4)
		var at := Vector2(t.x, Board.SY(t.y) - 10)
		await _crop("%s_0" % type, at, Vector2(36, 40), 4)
		var bought := []
		for step in 3:
			var picked = null
			for o in g.tower_options(t):
				if g.path_state(t, o) == "open" and not bought.has(o.id):
					picked = o
					break
			if picked == null:
				break
			g.level_tower(t, picked)
			bought.append(picked.id)
			await _frames(3)
			await _crop("%s_%d" % [type, step + 1], at, Vector2(36, 40), 4)
		print("%s: %d buys, colours %s" % [type, bought.size(), PathTint.colors(t)])
	_done()


func _done() -> void:
	print("TOWER COLORS DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
