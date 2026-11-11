## The Railgun merge model (art_src/towers/merges/arcane_tesla) in a real run with the default look (style test
## off): Arcane Bolt and Tesla Coil are maxed on different paths and merged, and the hybrid draws the Railgun GLB in
## its own smooth render (Merge3D) instead of the plinth, plays spawn then idle, turns its Turret toward enemies,
## plays fire on its shots, and paints arcane's path colours on mask A and tesla's on mask B.
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/merge3d.tscn -- <out dir>
extends Node

var out := "user://merge3d"
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


## Clears whatever a merge or a level-up left waiting (boon card, wave choice), so the game runs (paused, every
## model holds still, spawn included).
func _unblock(g: Game) -> void:
	for i in 30:
		main.ui.close_modal()
		if g.S.pending_boon != "":
			g.take_boon()
		if g.S.paused and g.wave_opts.size() > 0:
			g.choose_mode(0)
		await get_tree().process_frame
	print("paused=", g.S.paused)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().create_timer(240).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	for id in Menus.FIRST_TIPS:
		Save.meta.tips[id] = true
	Save.settings.style3d_test = false
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	main.ui.menus.new_run("canal")
	main.ui.menus.start_run("gale", ["arcane", "tesla", "mortar", "frost"])
	await _frames(10)
	var g := main.game
	var S := g.S
	var b := main.board
	S.gold = 999999
	g.modal.connect(func(kind, _d):
		if kind == "level_up":
			(func():
				main.ui.close_modal()
				g.pick_offer(0)).call_deferred())
	_check(b.live == null, "the default look: no shared low-res layer")
	MergeArt.clear_cache()
	var probe := Tower.new()
	probe.hybrid = true
	probe.type = "arcane+tesla"
	var spec := MergeArt.resolve(probe)
	_check(str(spec.get("glb", "")).ends_with("merges/arcane_tesla/railgun.glb"), "the merge loader finds railgun.glb (%s)" % spec.get("glb", ""))
	var cfg: Dictionary = spec.get("cfg", {})
	_check(cfg.get("yaw") == "Turret" and cfg.get("pitch") == "Turret/Gun" and cfg.get("muzzle") == "Muzzle", "tower.json names the yaw, pitch and muzzle nodes the loader can find")
	var spot := Vector2(560, 300)
	var placed := {}
	for type in ["arcane", "tesla"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot += Vector2(70, 0)
	var arc: Tower = placed.arcane
	var tes: Tower = placed.tesla
	_max(g, arc)
	_max(g, tes)
	await _frames(4)
	var ca := PathColors.for_tower(arc)
	var ct := PathColors.for_tower(tes)
	print("arcane paths ", arc.order, " ", ca, "  tesla paths ", tes.order, " ", ct)
	_check(arc.lvl == g.R.max_level and tes.lvl == g.R.max_level, "both parents maxed")
	await RenderingServer.frame_post_draw
	_crop("0_parents", Vector2(595, Board.SY(300)), Vector2(170, 110), 2)
	print("merge problem: '", g.merge_problem(tes, arc), "'")
	g.try_merge(tes, arc) # started from the tesla: mask A is still arcane (sorted key)
	await _frames(3)
	var rail: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == "arcane+tesla":
			rail = t
	_check(rail != null, "Arcane Bolt + Tesla Coil merge into the Railgun")
	if rail == null:
		_done()
		return
	var v = rail.get_meta("view") if rail.has_meta("view") else null
	_check(v is Merge3D and (v as Merge3D).ap.current_animation == "spawn", "spawn plays when it is built")
	await _unblock(g)
	_check(v is Merge3D, "the Railgun draws its GLB in its own smooth render, not the plinth")
	if not v is Merge3D:
		_done()
		return
	var m: Merge3D = v
	_check(b._merge_model(rail), "the board treats it as a model (no plinth or placeholder core)")
	_check(m.yaw_node != null and m.yaw_node.name == "Turret", "yaw node is Turret")
	_check(m.pitch_node != null and m.pitch_node.name == "Gun", "pitch node is Gun")
	_check(m.muzzle != null and m.muzzle.name == "Muzzle", "muzzle found")
	_check(m.mask_a != null and m.mask_b != null, "both accent masks load")
	_check(m.mats.size() == 1, "one recolour material for the body (railgun_mat)")
	var mat := m.mats[0]
	_check((mat.get_shader_parameter("a_trim") as Color).is_equal_approx(ca[0]), "mask A trim = arcane's first path colour")
	_check((mat.get_shader_parameter("a_glow") as Color).is_equal_approx(ca[1]), "mask A glow = arcane's second path colour")
	_check((mat.get_shader_parameter("b_trim") as Color).is_equal_approx(ct[0]), "mask B trim = tesla's first path colour")
	_check((mat.get_shader_parameter("b_detail") as Color).is_equal_approx(ct[2]), "mask B detail = tesla's third path colour")
	_check((mat.get_shader_parameter("recipe") as Color).is_equal_approx(Color("#8AFFFF")), "body tint is the recipe colour #8AFFFF")
	var at := Vector2(rail.x, Board.SY(rail.y))
	await _frames(20)
	await _crop("1_spawning", at, Vector2(90, 90), 3)
	await get_tree().create_timer(1.6).timeout
	_check(m.ap.current_animation == "idle", "idle loops after spawn")
	await _crop("2_idle", at, Vector2(90, 90), 3)
	m.vp.get_texture().get_image().save_png(out.path_join("2_idle_render.png"))
	# aiming: a direction on the board turns the Turret, and the Gun's pitch is left level
	m.aim(Vector2(-60, 25))
	await get_tree().create_timer(0.8).timeout
	_check(absf(m.yaw_node.rotation.y) > 0.5, "the Turret yaws toward a target (%.2f rad)" % m.yaw_node.rotation.y)
	_check(is_zero_approx(m.pitch_node.rotation.x), "the Gun stays level (tower.json aim 0)")
	await _crop("3_aim_left", at, Vector2(90, 90), 3)
	m.aim(Vector2(60, -30))
	await get_tree().create_timer(0.8).timeout
	await _crop("4_aim_up_right", at, Vector2(90, 90), 3)
	# a real wave: it fires at enemies
	S.hero.x = rail.x - 120
	await _unblock(g)
	g.start_wave()
	_check(S.wave_active, "the wave starts")
	var fired := false
	var st0 = rail.shot_at
	for i in 600:
		await get_tree().process_frame
		if rail.shot_at != st0 and m.ap.current_animation == "fire":
			fired = true
			break
	_check(fired, "fire plays when the Railgun shoots in a wave")
	await get_tree().create_timer(0.2).timeout
	await _crop("5_firing", at, Vector2(110, 90), 3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("6_board.png"))
	_check(m.yaw_node.rotation.y != 0.0 and is_zero_approx(m.pitch_node.rotation.x), "yaw and pitch survive the fire clip")
	_done()


func _done() -> void:
	print("MERGE3D DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
