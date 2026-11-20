## The Thunder Battery (art_src/towers/merges/mortar_tesla) in a real run: maxed Mortar + Tesla merged, a few charges
## cropped as the turret turns to different enemies (the arcs should leave each coil tip and run into the ball).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/thunder_battery.tscn -- <out dir>
extends Node

var out := "user://thunder_battery"
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
	get_tree().create_timer(400).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["mortar", "tesla", "frost", "arcane"])
	await _frames(10)
	var g := main.game
	var S := g.S
	S.gold = 999999
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	var spot := g.pos_at(300.0)
	var placed := {}
	for type in ["mortar", "tesla"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot = g.pos_at(380.0)
	_max(g, placed.mortar)
	_max(g, placed.tesla)
	await _frames(4)
	g.try_merge(placed.tesla, placed.mortar)
	await _frames(3)
	var tb: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.thunder:
			tb = t
	_check(tb != null, "Mortar + Tesla merge into the Thunder Battery")
	if tb == null:
		_done()
		return
	await _unblock(g)
	var at := Vector2(tb.x, Board.SY(tb.y))
	await get_tree().create_timer(1.6).timeout
	S.hero.x = tb.x - 160
	get_tree().process_frame.connect(func():
		for e in S.enemies:
			if not e.has_meta("tough"):
				e.set_meta("tough", true)
				e.max *= 30.0
				e.hp = e.max)
	await _unblock(g)
	g.start_wave()
	var charges := 0
	var balls := 0
	var blasts := 0
	var shots := 0
	for i in 1500:
		await get_tree().process_frame
		for f in S.fx:
			if f.get("tw") != tb or f.get("_seen", false):
				continue
			f._seen = true
			if f.k == "thunder_charge":
				charges += 1
				# mid-charge, from whichever way the turret faces now
				if shots < 4:
					shots += 1
					await get_tree().create_timer(f.secs * 0.7).timeout
					await _crop("charge_%d" % shots, at, Vector2(70, 80), 4)
			elif f.k == "thunder_ball":
				balls += 1
			elif f.k == "thunder_blast":
				blasts += 1
		if shots >= 4 and blasts >= 3:
			break
	print("charges %d, balls %d, blasts %d" % [charges, balls, blasts])
	_check(charges > 0 and balls > 0 and blasts > 0, "it charges, fires its lightning ball and blasts")
	_done()


func _done() -> void:
	print("THUNDER DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
