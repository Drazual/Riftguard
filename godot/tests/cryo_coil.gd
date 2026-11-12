## The Cryo Coil merge model (art_src/towers/merges/frost_tesla) in a real run with the default look: Frost Pylon and
## Tesla Coil are maxed and merged, and the hybrid draws the Cryo Coil GLB in its own smooth render (Merge3D): spawn
## then idle, no aiming (the crown stays still), fire on its shots, shots leaving from the orb (Muzzle), frost's path
## colours on mask A (the crown) and tesla's on mask B (the coil).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1600x900 res://tests/cryo_coil.tscn -- <out dir>
extends Node

var out := "user://cryo_coil"
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
	main.ui.menus.start_run("gale", ["frost", "tesla", "mortar", "arcane"])
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
	probe.type = "frost+tesla"
	var spec := MergeArt.resolve(probe)
	_check(str(spec.get("glb", "")).ends_with("merges/frost_tesla/cryo_coil.glb"), "the merge loader finds cryo_coil.glb (%s)" % spec.get("glb", ""))
	var cfg: Dictionary = spec.get("cfg", {})
	_check(cfg.get("yaw") == "-" and cfg.get("pitch") == "-" and cfg.get("muzzle") == "Muzzle", "tower.json: no yaw or pitch, muzzle by node name")
	var spot := g.pos_at(300.0) # beside the road, so it gets shots in during the wave
	var placed := {}
	for type in ["frost", "tesla"]:
		var best := Vector2i(-1, -1)
		for c in g.build_cells():
			if g.build_problem(c.x, c.y, type) == "" and (best.x < 0 or g.cell_pos(c.x, c.y).distance_to(spot) < g.cell_pos(best.x, best.y).distance_to(spot)):
				best = c
		g.place_tower(best.x, best.y, type)
		placed[type] = S.towers[S.towers.size() - 1]
		spot = g.pos_at(380.0)
	var arc: Tower = placed.frost
	var tes: Tower = placed.tesla
	_max(g, arc)
	_max(g, tes)
	await _frames(4)
	var ca := PathColors.for_tower(arc)
	var ct := PathColors.for_tower(tes)
	print("frost paths ", arc.order, " ", ca, "  tesla paths ", tes.order, " ", ct)
	_check(arc.lvl == g.R.max_level and tes.lvl == g.R.max_level, "both parents maxed")
	await RenderingServer.frame_post_draw
	_crop("0_parents", Vector2(arc.x, Board.SY(arc.y)), Vector2(170, 110), 2)
	print("merge problem: '", g.merge_problem(tes, arc), "'")
	g.try_merge(tes, arc) # started from the tesla: mask A is still frost (sorted key)
	await _frames(3)
	var rail: Tower = null
	for t: Tower in S.towers:
		if t.hybrid and t.type == "frost+tesla":
			rail = t
	_check(rail != null, "Frost Pylon + Tesla Coil merge into the Cryo Coil")
	if rail == null:
		_done()
		return
	var v = rail.get_meta("view") if rail.has_meta("view") else null
	_check(v is Merge3D and (v as Merge3D).ap.current_animation == "spawn", "spawn plays when it is built")
	await _unblock(g)
	_check(v is Merge3D, "the Cryo Coil draws its GLB in its own smooth render, not the plinth")
	if not v is Merge3D:
		_done()
		return
	var m: Merge3D = v
	_check(b._merge_model(rail), "the board treats it as a model (no plinth or placeholder core)")
	_check(m.yaw_node == null and m.pitch_node == null, "nothing turns: no yaw or pitch node")
	_check(m.muzzle != null and m.muzzle.name == "Muzzle" and m.muzzle.get_parent().name == "Crown", "muzzle is the orb (Base/Crown/Muzzle)")
	_check(m.mats.size() == 1, "one recolour material for the body (cryo_coil_mat)")
	_check(m.mask_a != null and m.mask_b != null, "both accent masks load")
	var mat := m.mats[0]
	_check((mat.get_shader_parameter("a_trim") as Color).is_equal_approx(ca[0]), "mask A (crown) trim = frost's first path colour")
	_check((mat.get_shader_parameter("a_glow") as Color).is_equal_approx(ca[1]), "mask A (crown crystals) glow = frost's second path colour")
	_check((mat.get_shader_parameter("b_trim") as Color).is_equal_approx(ct[0]), "mask B (coil) trim = tesla's first path colour")
	_check((mat.get_shader_parameter("b_detail") as Color).is_equal_approx(ct[2]), "mask B detail = tesla's third path colour")
	_check((mat.get_shader_parameter("recipe") as Color).is_equal_approx(Color("#9AF0FF")), "body tint is the recipe colour #9AF0FF")
	var at := Vector2(rail.x, Board.SY(rail.y))
	await _frames(20)
	await _crop("1_spawning", at, Vector2(90, 90), 3)
	await get_tree().create_timer(1.6).timeout
	_check(m.ap.current_animation == "idle", "idle loops after spawn")
	await _crop("2_idle", at, Vector2(90, 90), 3)
	# no aiming: the crown stays still when the game points it somewhere
	var crown: Node3D = m.model.find_child("Crown", true, false)
	var rot0 := crown.global_transform.basis
	m.aim(Vector2(-60, 25))
	await get_tree().create_timer(0.5).timeout
	_check(crown.global_transform.basis.is_equal_approx(rot0), "the crown doesn't turn toward targets")
	var mm = b.merge_muzzle(rail)
	_check(mm != null and (mm as Vector2).y < Board.SY(rail.y) - 25, "the muzzle shows up at the orb, high over the tower (%s)" % [mm])
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
	_check(fired, "fire plays when the Cryo Coil shoots in a wave")
	# the shot leaves at the fire clip's shot moment (tower.json shot_time 0.2 s), from the Muzzle
	var seen_line := false
	for i in 40:
		await get_tree().process_frame
		if S.fx.any(func(f): return f.k == "line" and f.get("tw") == rail):
			seen_line = true
			break
	_check(seen_line, "its shot line is tagged with the tower, so the board starts it at the Muzzle")
	await _crop("5_firing", at, Vector2(110, 90), 3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("6_board.png"))
	_done()


func _done() -> void:
	print("CRYO COIL DONE fails=%d" % fails)
	get_tree().quit(1 if fails else 0)
